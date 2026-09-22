import Foundation

/// 文件夹访问：security-scoped bookmark 持久化（重启后仍可访问所选文件夹）
enum FolderBookmark {
    static func save(_ url: URL, forKey key: String) {
        let data = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        if let data {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func resolve(_ key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
    }

    static func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// 同步：在安全作用域内执行操作（进程内引用计数，可嵌套）
    @discardableResult
    static func withAccess<T>(to url: URL, _ body: () throws -> T) rethrows -> T {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        return try body()
    }

    /// 异步：作用域在异步闭包整个执行期间保持有效（扫描/哈希必须用这个）
    static func withAccess<T>(to url: URL, _ body: () async throws -> T) async rethrows -> T {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        return try await body()
    }
}
