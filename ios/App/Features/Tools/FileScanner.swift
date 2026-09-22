import Foundation
import CryptoKit
import Observation

struct FileInfo {
    let relativePath: String
    let size: Int64
    let mtime: Date
}

/// 文件夹扫描器：递归枚举 + SHA-256 哈希（后台任务、可取消）
/// 不加 @MainActor：实例由视图以 @State 创建；所有属性变更都发生在主线程调用方，
/// 枚举/哈希在 detached 任务内完成，无需类级隔离。
@Observable
final class FolderScanner {
    var isWorking = false
    var progress = 0.0
    var statusText = ""

    private var cancelledFlag = false

    func cancel() {
        cancelledFlag = true
    }

    /// 递归枚举所有文件（跳过隐藏文件）
    func scan(url: URL) async -> [FileInfo] {
        isWorking = true
        cancelledFlag = false
        progress = 0
        statusText = "正在扫描…"
        defer { isWorking = false }

        let result = await Task.detached(priority: .userInitiated) { () -> [FileInfo] in
            var files: [FileInfo] = []
            let fm = FileManager.default
            let base = url.standardizedFileURL.path

            func walk(_ dir: URL) {
                guard let items = try? fm.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { return }
                for item in items {
                    if Task.isCancelled { return }
                    let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir {
                        walk(item)
                    } else {
                        let values = try? item.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                        let rel = String(item.path.dropFirst(base.count).drop(while: { $0 == "/" }))
                        files.append(FileInfo(
                            relativePath: rel,
                            size: Int64(values?.fileSize ?? 0),
                            mtime: values?.contentModificationDate ?? .distantPast
                        ))
                    }
                }
            }

            walk(url)
            return files
        }.value

        statusText = "扫描完成：\(result.count) 个文件"
        return result
    }

    /// 批量哈希（深比对），返回 [相对路径: SHA-256]，progress 0...1
    func hashAll(root: URL, files: [FileInfo]) async -> [String: String] {
        isWorking = true
        cancelledFlag = false
        progress = 0
        defer { isWorking = false }

        var hashes: [String: String] = [:]
        let total = max(1, files.count)

        for (index, file) in files.enumerated() {
            if cancelledFlag || Task.isCancelled { break }
            if let h = await Self.sha256(fileURL: URL(fileURLWithPath: root.path + "/" + file.relativePath)) {
                hashes[file.relativePath] = h
            }
            progress = Double(index + 1) / Double(total)
            statusText = "哈希计算 \(index + 1)/\(files.count)"
            await Task.yield()
        }
        return hashes
    }

    /// 单文件 SHA-256（流式，大文件友好）
    nonisolated static func sha256(fileURL: URL, chunkSize: Int = 1 << 20) async -> String? {
        await Task.detached(priority: .utility) { () -> String? in
            guard let stream = InputStream(url: fileURL) else { return nil }
            stream.open()
            defer { stream.close() }
            var hasher = SHA256()
            var buffer = [UInt8](repeating: 0, count: chunkSize)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: chunkSize)
                if read < 0 { return nil }
                if read == 0 { break }
                hasher.update(data: Data(buffer[0..<read]))
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }
}
