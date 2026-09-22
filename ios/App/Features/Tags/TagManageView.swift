import SwiftUI
import SwiftData

/// 标签管理：查看、新建、删除
struct TagManageView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    @Query(filter: #Predicate<TagItem> { $0.deletedAt == nil }, sort: \TagItem.name)
    private var tags: [TagItem]

    @State private var newName = ""
    @State private var newColor = Color(red: 94 / 255, green: 106 / 255, blue: 210 / 255)

    var body: some View {
        List {
            Section("标签") {
                if tags.isEmpty {
                    Text("暂无标签")
                        .foregroundStyle(.tertiary)
                }
                ForEach(tags) { tag in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Theme.color(fromHex: tag.color))
                            .frame(width: 10, height: 10)
                        Text(tag.name)
                    }
                }
                .onDelete(perform: delete)
            }
            Section("新建标签") {
                HStack {
                    TextField("标签名", text: $newName)
                        .onSubmit(create)
                    ColorPicker("颜色", selection: $newColor, supportsOpacity: false)
                    Button(action: create) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section {
                Text("删除标签不会删除任务；同名标签删除后需换名重建。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("标签管理")
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let tag = TagItem(name: name, color: hexString(from: UIColor(newColor)))
        context.insert(tag)
        newName = ""
        sync.requestSync()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            tags[index].deletedAt = Date()
            tags[index].updatedAt = Date()
            tags[index].needsSync = true
        }
        sync.requestSync()
    }

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
