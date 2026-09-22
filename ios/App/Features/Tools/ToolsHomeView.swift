import SwiftUI

/// M8 将实现：文件夹对比 / 重复文件查找 / 大文件扫描（纯本地计算）
struct ToolsHomeView: View {
    var body: some View {
        List {
            Section {
                Label("文件夹对比", systemImage: "folder.badge.gearshape")
                Label("重复文件查找", systemImage: "doc.on.doc")
                Label("大文件扫描", systemImage: "externaldrive")
            } header: {
                Text("开发中（M8）")
            } footer: {
                Text("所有对比均在设备本地完成，文件内容不会上传。")
            }
        }
        .navigationTitle("文件工具")
    }
}
