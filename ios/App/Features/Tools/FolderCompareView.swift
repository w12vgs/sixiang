import SwiftUI

/// 文件夹对比：快速（名称+大小+修改时间）/ 深度（SHA-256 内容哈希）
struct FolderCompareView: View {
    enum Mode: String, CaseIterable {
        case fast = "快速对比"
        case deep = "深度对比（SHA-256）"
    }

    enum Category: String, CaseIterable {
        case onlyLeft = "仅左侧"
        case onlyRight = "仅右侧"
        case changed = "两侧不同"
        case same = "相同"
    }

    struct DiffEntry: Identifiable {
        let id = UUID()
        let path: String
        let size: Int64
    }

    private static let leftKey = "tools.compare.leftFolder"
    private static let rightKey = "tools.compare.rightFolder"

    @State private var leftURL: URL?
    @State private var rightURL: URL?
    @State private var leftName = "未选择"
    @State private var rightName = "未选择"
    @State private var showLeftPicker = false
    @State private var showRightPicker = false
    @State private var mode: Mode = .fast
    @State private var category: Category = .changed

    @State private var scanner = FolderScanner()
    @State private var running = false

    @State private var onlyLeft: [DiffEntry] = []
    @State private var onlyRight: [DiffEntry] = []
    @State private var changed: [DiffEntry] = []
    @State private var sameCount = 0

    var body: some View {
        List {
            Section("选择文件夹") {
                folderRow(title: "左侧（基准）", name: leftName, color: Theme.accent) {
                    showLeftPicker = true
                }
                folderRow(title: "右侧（对照）", name: rightName, color: .orange) {
                    showRightPicker = true
                }
            }

            Section("对比方式") {
                Picker("方式", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
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
                        Text("开始对比")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(leftURL == nil || rightURL == nil || running)
                if scanner.isWorking && mode == .deep {
                    ProgressView(value: scanner.progress)
                }
            }

            if !onlyLeft.isEmpty || !onlyRight.isEmpty || !changed.isEmpty || sameCount > 0 {
                Section("结果摘要") {
                    LabeledContent("仅左侧", value: "\(onlyLeft.count) 个")
                    LabeledContent("仅右侧", value: "\(onlyRight.count) 个")
                    LabeledContent("两侧不同", value: "\(changed.count) 个")
                    LabeledContent("相同", value: "\(sameCount) 个")
                    ShareLink(item: reportCSV) {
                        Label("导出报告（CSV）", systemImage: "square.and.arrow.up")
                    }
                }

                Section("明细") {
                    Picker("分类", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    entries
                }
            }
        }
        .navigationTitle("文件夹对比")
        .sheet(isPresented: $showLeftPicker) {
            FolderPicker { url in
                leftURL = url
                leftName = url.lastPathComponent
                FolderBookmark.save(url, forKey: Self.leftKey)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showRightPicker) {
            FolderPicker { url in
                rightURL = url
                rightName = url.lastPathComponent
                FolderBookmark.save(url, forKey: Self.rightKey)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if leftURL == nil, let url = FolderBookmark.resolve(Self.leftKey) {
                leftURL = url
                leftName = url.lastPathComponent
            }
            if rightURL == nil, let url = FolderBookmark.resolve(Self.rightKey) {
                rightURL = url
                rightName = url.lastPathComponent
            }
        }
    }

    @ViewBuilder
    private var entries: some View {
        let list: [DiffEntry] = switch category {
        case .onlyLeft: onlyLeft
        case .onlyRight: onlyRight
        case .changed: changed
        case .same: []
        }
        if category == .same {
            Text("相同文件：\(sameCount) 个（不逐条列出）")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if list.isEmpty {
            Text("无差异")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ForEach(list.prefix(500)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.path)
                        .font(.footnote)
                        .lineLimit(2)
                    Text(formatBytes(entry.size))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if list.count > 500 {
                Text("…仅显示前 500 条（完整结果见导出报告）")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func folderRow(title: String, name: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(name)
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

    // MARK: - 对比逻辑

    private func run() async {
        guard let leftURL, let rightURL else { return }
        running = true
        onlyLeft = []
        onlyRight = []
        changed = []
        sameCount = 0
        defer { running = false }

        FolderBookmark.withAccess(to: leftURL) {
            FolderBookmark.withAccess(to: rightURL) {
                _ = ()
            }
        }

        let leftFiles = await scanner.scan(url: leftURL)
        let rightFiles = await scanner.scan(url: rightURL)

        var leftMap = [String: FileInfo]()
        for f in leftFiles { leftMap[f.relativePath] = f }
        var rightMap = [String: FileInfo]()
        for f in rightFiles { rightMap[f.relativePath] = f }

        // 深度模式需哈希的文件（两侧同路径；快速模式下大小/时间已可判定差异）
        var toHash: [FileInfo] = []

        for (path, info) in leftMap {
            guard let r = rightMap[path] else {
                onlyLeft.append(DiffEntry(path: path, size: info.size))
                continue
            }
            let sizeDiff = info.size != r.size
            let mtimeDiff = abs(info.mtime.timeIntervalSince(r.mtime)) > 2
            if sizeDiff || mtimeDiff {
                if mode == .fast {
                    changed.append(DiffEntry(path: path, size: r.size))
                } else {
                    toHash.append(info)
                }
            } else if mode == .deep {
                toHash.append(info)
            }
        }
        for (path, info) in rightMap where leftMap[path] == nil {
            onlyRight.append(DiffEntry(path: path, size: info.size))
        }

        if mode == .deep, !toHash.isEmpty {
            let leftHashes = await scanner.hashAll(root: leftURL, files: toHash)
            let rightHashes = await scanner.hashAll(root: rightURL, files: toHash)
            for info in toHash {
                let lh = leftHashes[info.relativePath]
                let rh = rightHashes[info.relativePath]
                if lh == nil || rh == nil || lh != rh {
                    changed.append(DiffEntry(path: info.relativePath, size: rightMap[info.relativePath]?.size ?? 0))
                }
            }
        }

        // 相同数 = 左侧文件总数 − 仅左侧 − 两侧不同（两种模式口径一致）
        sameCount = max(0, leftFiles.count - onlyLeft.count - changed.count)
    }

    // MARK: - 导出

    private var reportCSV: String {
        var lines = ["分类,路径,大小(字节)"]
        for e in onlyLeft { lines.append("仅左侧,\(e.path),\(e.size)") }
        for e in onlyRight { lines.append("仅右侧,\(e.path),\(e.size)") }
        for e in changed { lines.append("两侧不同,\(e.path),\(e.size)") }
        lines.append("相同文件数,\(sameCount),")
        return lines.joined(separator: "\n")
    }
}
