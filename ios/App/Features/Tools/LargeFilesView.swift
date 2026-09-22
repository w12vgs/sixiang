import SwiftUI

/// 大文件扫描：按大小降序展示
struct LargeFilesView: View {
    private static let folderKey = "tools.largefiles.folder"

    @State private var folderURL: URL?
    @State private var folderName = "未选择"
    @State private var showPicker = false
    @State private var scanner = FolderScanner()
    @State private var running = false
    @State private var files: [FileInfo] = []
    @State private var topN = 100

    var body: some View {
        List {
            Section("选择文件夹") {
                Button {
                    showPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.green)
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
                        Text("开始扫描").bold().frame(maxWidth: .infinity)
                    }
                }
                .disabled(folderURL == nil || running)
            }

            if !files.isEmpty {
                Section("最大的 \(topN) 个文件") {
                    ShareLink(item: reportCSV) {
                        Label("导出报告（CSV）", systemImage: "square.and.arrow.up")
                    }
                    ForEach(Array(files.prefix(topN).enumerated()), id: \.element.relativePath) { index, file in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.relativePath)
                                    .font(.footnote)
                                    .lineLimit(2)
                                Text(file.mtime.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(formatBytes(file.size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("大文件扫描")
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
        defer { running = false }

        // 安全作用域必须覆盖整个扫描过程
        let all = await FolderBookmark.withAccess(to: folderURL) {
            await scanner.scan(url: folderURL)
        }
        files = all.sorted { $0.size > $1.size }
    }

    private var reportCSV: String {
        var lines = ["大小(字节),修改时间,路径"]
        for f in files.prefix(topN) {
            lines.append("\(f.size),\(f.mtime.formatted(.iso8601)),\(f.relativePath)")
        }
        return lines.joined(separator: "\n")
    }
}
