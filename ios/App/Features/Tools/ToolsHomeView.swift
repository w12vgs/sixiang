import SwiftUI

/// 文件工具首页：文件夹对比 / 重复文件查找 / 大文件扫描
struct ToolsHomeView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    FolderCompareView()
                } label: {
                    toolRow(icon: "folder.badge.gearshape", title: "文件夹对比", subtitle: "找出两个文件夹的差异", color: Theme.accent)
                }
                NavigationLink {
                    DuplicateFinderView()
                } label: {
                    toolRow(icon: "doc.on.doc", title: "重复文件查找", subtitle: "按内容哈希识别重复文件", color: .orange)
                }
                NavigationLink {
                    LargeFilesView()
                } label: {
                    toolRow(icon: "externaldrive", title: "大文件扫描", subtitle: "找出占用空间最大的文件", color: .green)
                }
            } header: {
                Text("工具")
            } footer: {
                Text("所有对比均在设备本地完成，文件内容不会上传。选择过的文件夹会通过系统安全书签保存授权，可在本页管理。")
            }
        }
        .navigationTitle("文件工具")
    }

    private func toolRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 文件大小格式化
func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
