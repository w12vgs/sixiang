import Foundation
import Observation

/// 登录状态与令牌管理（Keychain 持久化，重启后自动恢复）
/// iOS 17 SDK 中 SwiftUI 的 App 协议为 @MainActor，入口处创建单例是安全的
@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private(set) var isLoggedIn = false
    private(set) var currentUser: UserDTO?
    private(set) var currentAccessToken: String?
    private(set) var currentRefreshToken: String?

    private enum Keys {
        static let access = "auth.accessToken"
        static let refresh = "auth.refreshToken"
        static let user = "auth.user"
    }

    init() {
        restore()
    }

    func restore() {
        currentAccessToken = KeychainStore.read(Keys.access)
        currentRefreshToken = KeychainStore.read(Keys.refresh)
        if let data = UserDefaults.standard.data(forKey: Keys.user),
           let user = try? JSONDecoder.sixiang.decode(UserDTO.self, from: data) {
            currentUser = user
        }
        isLoggedIn = currentAccessToken != nil
    }

    func register(email: String, password: String, displayName: String?) async throws {
        let body = RegisterPayload(email: email, password: password, displayName: displayName)
        let options = try APIClient.RequestOptions.json(method: "POST", body: body, auth: false)
        let resp: AuthResponse = try await APIClient.shared.send("/api/auth/register", options: options)
        apply(resp)
    }

    func login(email: String, password: String) async throws {
        let body = LoginPayload(email: email, password: password)
        let options = try APIClient.RequestOptions.json(method: "POST", body: body, auth: false)
        let resp: AuthResponse = try await APIClient.shared.send("/api/auth/login", options: options)
        apply(resp)
    }

    /// access 失效时用 refresh 换新；成功返回 true
    func refreshAccessToken() async -> Bool {
        guard let refresh = currentRefreshToken else { return false }
        do {
            let body = RefreshPayload(refreshToken: refresh)
            let options = try APIClient.RequestOptions.json(method: "POST", body: body, auth: false)
            let resp: TokenPair = try await APIClient.shared.send("/api/auth/refresh", options: options)
            currentAccessToken = resp.accessToken
            currentRefreshToken = resp.refreshToken
            KeychainStore.save(resp.accessToken, key: Keys.access)
            KeychainStore.save(resp.refreshToken, key: Keys.refresh)
            return true
        } catch {
            return false
        }
    }

    func forceLogout() {
        logout()
    }

    func logout() {
        currentAccessToken = nil
        currentRefreshToken = nil
        currentUser = nil
        isLoggedIn = false
        KeychainStore.delete(Keys.access)
        KeychainStore.delete(Keys.refresh)
        UserDefaults.standard.removeObject(forKey: Keys.user)
    }

    private func apply(_ resp: AuthResponse) {
        currentAccessToken = resp.accessToken
        currentRefreshToken = resp.refreshToken
        currentUser = resp.user
        isLoggedIn = true
        KeychainStore.save(resp.accessToken, key: Keys.access)
        KeychainStore.save(resp.refreshToken, key: Keys.refresh)
        if let data = try? JSONEncoder.sixiang.encode(resp.user) {
            UserDefaults.standard.set(data, forKey: Keys.user)
        }
    }
}
