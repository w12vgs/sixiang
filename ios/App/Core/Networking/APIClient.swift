import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case http(Int, String) // statusCode, 服务端错误码
    case decoding(String)
    case network(String)
    case unauthorized

    var isOffline: Bool {
        if case .network = self { return true }
        return false
    }

    var isAuthFailure: Bool {
        if case .http(401, _) = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的服务器地址"
        case .http(_, let code):
            switch code {
            case "validation_error": return "输入内容不符合要求"
            case "invalid_credentials": return "邮箱或密码错误"
            case "invalid_refresh_token": return "登录已过期，请重新登录"
            case "already_exists": return "该邮箱已注册"
            case "unauthorized": return "登录已过期，请重新登录"
            case "not_found": return "数据不存在，可能已被删除"
            case "internal_error": return "服务器开小差了，请稍后再试"
            default: return "服务器错误（\(code)）"
            }
        case .decoding(let detail):
            return "数据解析失败：\(detail)"
        case .network:
            return "网络不可用，已切换到离线模式"
        case .unauthorized:
            return "登录已过期，请重新登录"
        }
    }
}

private struct ServerErrorBody: Decodable {
    let error: String?
}

/// API 客户端：Bearer 认证、401 自动刷新重试、离线错误归类
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    /// 服务器地址（「我的 → 设置」可改）
    var baseURL: URL {
        if let s = UserDefaults.standard.string(forKey: "serverBaseURL"),
           let url = URL(string: s), url.scheme != nil {
            return url
        }
        return URL(string: "http://localhost:3000")!
    }

    var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: "deviceID") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "deviceID")
        return id
    }

    struct RequestOptions {
        var method: String
        var body: Data?
        var auth: Bool
        var query: [URLQueryItem] = []

        static func json(method: String, body: (any Encodable)?, auth: Bool, query: [URLQueryItem] = []) throws -> RequestOptions {
            let data: Data?
            if let body {
                data = try JSONEncoder.sixiang.encode(body)
            } else {
                data = nil
            }
            return RequestOptions(method: method, body: data, auth: auth, query: query)
        }
    }

    func send<T: Decodable>(_ path: String, options: RequestOptions) async throws -> T {
        let data = try await sendData(path, options: options)
        do {
            return try JSONDecoder.sixiang.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func sendVoid(_ path: String, options: RequestOptions) async throws {
        _ = try await sendData(path, options: options)
    }

    private func sendData(_ path: String, options: RequestOptions) async throws -> Data {
        let token = await MainActor.run { AuthManager.shared.currentAccessToken }
        do {
            return try await perform(path, options: options, token: token)
        } catch let err as APIError where err.isAuthFailure && options.auth && token != nil {
            // access 失效 → 用 refresh 换新后重试一次
            guard await AuthManager.shared.refreshAccessToken() else {
                await MainActor.run { AuthManager.shared.forceLogout() }
                throw APIError.unauthorized
            }
            let newToken = await MainActor.run { AuthManager.shared.currentAccessToken }
            return try await perform(path, options: options, token: newToken)
        }
    }

    private func perform(_ path: String, options: RequestOptions, token: String?) async throws -> Data {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !options.query.isEmpty {
            comps?.queryItems = options.query
        }
        guard let url = comps?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = options.method
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if options.auth, let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = options.body

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw APIError.network("无效响应")
            }
            guard (200..<300).contains(http.statusCode) else {
                let serverError = (try? JSONDecoder().decode(ServerErrorBody.self, from: data))?.error
                throw APIError.http(http.statusCode, serverError ?? "unknown")
            }
            return data
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }
}
