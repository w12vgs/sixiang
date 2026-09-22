import SwiftUI

/// M5 将实现：Markdown 编辑器、标签、置顶、搜索
struct NotesListView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "笔记",
                systemImage: "note.text",
                description: Text("M5 开发中：Markdown 笔记与标签管理")
            )
            .navigationTitle("笔记")
            .profileToolbar()
        }
    }
}
