import SwiftUI

/// 重复文件查找：按大小分组 → 组内 SHA-256 哈希确认
struct DuplicateFinderView: View {
    struct DupGroup: Identifiable {
        let id = UUID()
        let hash: String
        let paths: [String]
        let size: Int64

        var wastedBytes: Int64 { size * Int64(paths.count - 1) }
    }

    private static let folderKey = "tools.duplicates.folder"

    @State private var folderURL: URL?
    @State private var folderName = "未选择"
    @State private var showPicker = false
    @State private var scanner = FolderScanner()
    @State private var running = false
    @State private var groups: [DupGroup] = []

    var body: some View {
        List {
            Section("选择文件夹") {
                Button {
                    showPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("扫描位置")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(folderName)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section {
                Button {
                    Task { await run() }
                } label: {
                    if running {
                        HStack {
                            ProgressView()
                            Text(scanner.statusText).padding(.leading, 8)
                        }
                    } else {
                        Text("开始查找").bold().frame(maxWidth: .infinity)
                    }
                }
                .disabled(folderURL == nil || running)
                if scanner.isWorking {
                    ProgressView(value: scanner.progress)
                }
            }

            if !groups.isEmpty {
                Section("重复组（\(groups.count) 组）") {
                    ShareLink(item: reportCSV) {
                        Label("导出报告（CSV）", systemImage: "square.and.arrow.up")
                    }
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(group.paths.count) 个重复 · 每个 \(formatBytes(group.size)) · 可释放 \(formatBytes(group.wastedBytes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(group.paths, id: \.self) { path in
                                Text(path)
                                    .font(.footnote)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("重复文件查找")
        .sheet(isPresented: $showPicker) {
            FolderPicker { url in
                folderURL = url
                folderName = url.lastPathComponent
                FolderBookmark.save(url, forKey: Self.folderKey)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if folderURL == nil, let url = FolderBookmark.resolve(Self.folderKey) {
                folderURL = url
                folderName = url.lastPathComponent
            }
        }
    }

    private func run() async {
        guard let folderURL else { return }
        running = true
        groups = []
        defer { running = false }

        // 安全作用域必须覆盖整个扫描+哈希过程
        let files = await FolderBookmark.withAccess(to: folderURL) {
            await scanner.scan(url: folderURL)
        }

        // 按大小分组（大小相同才可能是重复）
        var bySize = [Int64: [FileInfo]]()
        for f in files where f.size > 0 {
            bySize[f.size, default: []].append(f)
        }

        var result: [DupGroup] = []
        let candidates = bySize.values.filter { $0.count > 1 }.flatMap { $0 }
        scanner.statusText = "哈希确认 \(candidates.count) 个候选文件…"
        let hashes = await FolderBookmark.withAccess(to: folderURL) {
            await scanner.hashAll(root: folderURL, files: candidates)
        }

        var byHash = [String: [FileInfo]]()
        for f in candidates {
            if let h = hashes[f.relativePath] {
                byHash[h, default: []].append(f)
            }
        }

        for (hash, items) in byHash where items.count > 1 {
            let paths = items.map { $0.relativePath }.sorted()
            result.append(DupGroup(hash: hash, paths: paths, size: items[0].size))
        }
        groups = result.sorted { $0.wastedBytes > $1.wastedBytes }
    }

    private var reportCSV: String {
        var lines = ["组,大小(字节),重复数,路径"]
        for (i, g) in groups.enumerated() {
            for p in g.paths {
                lines.append("\(i + 1),\(g.size),\(g.paths.count),\(p)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
