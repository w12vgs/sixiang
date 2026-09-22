import SwiftUI
import SwiftData

/// 笔记编辑器：Markdown 编辑/预览、标签、置顶
struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    @Query(filter: #Predicate<TagItem> { $0.deletedAt == nil }, sort: \TagItem.name)
    private var tags: [TagItem]

    let existing: NoteItem?

    @State private var title: String
    @State private var content: String
    @State private var pinned: Bool
    @State private var tagIds: [String]
    @State private var showPreview = false

    init(note: NoteItem? = nil) {
        self.existing = note
        _title = State(initialValue: note?.title ?? "")
        _content = State(initialValue: note?.content ?? "")
        _pinned = State(initialValue: note?.pinned ?? false)
        _tagIds = State(initialValue: note?.tagIds ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("标题", text: $title, axis: .vertical)
                        .font(.headline)
                }

                Section("标签") {
                    if tags.isEmpty {
                        Text("暂无标签（可在「我的 → 标签管理」创建）")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(tags) { tag in chip(tag) }
                        }
                    }
                }

                Section("内容（Markdown）") {
                    Picker("模式", selection: $showPreview) {
                        Text("编辑").tag(false)
                        Text("预览").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if showPreview {
                        Text(renderedContent)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        TextEditor(text: $content)
                            .frame(minHeight: 260)
                    }
                }

                Section {
                    Toggle("置顶", isOn: $pinned)
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) { delete() } label: {
                            Label("删除笔记", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "新建笔记" : "编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var renderedContent: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let md = try? AttributedString(markdown: content, options: options) {
            return md
        }
        return AttributedString(content)
    }

    private func chip(_ tag: TagItem) -> some View {
        let selected = tagIds.contains(tag.serverId)
        return Button {
            if selected {
                tagIds.removeAll { $0 == tag.serverId }
            } else {
                tagIds.append(tag.serverId)
            }
        } label: {
            Text(tag.name)
                .font(.footnote)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(selected ? Theme.color(fromHex: tag.color).opacity(0.25) : Color(.tertiarySystemFill))
                )
                .overlay(
                    Capsule().stroke(Theme.color(fromHex: tag.color), lineWidth: selected ? 1.5 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        var finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalTitle.isEmpty {
            finalTitle = content.split(separator: "\n")
                .first
                .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        }
        if finalTitle.isEmpty { finalTitle = "无标题" }

        let item = existing ?? NoteItem(title: finalTitle)
        item.title = finalTitle
        item.content = content
        item.pinned = pinned
        item.tagIds = tagIds
        item.updatedAt = Date()
        item.needsSync = true
        if existing == nil {
            context.insert(item)
        }
        sync.requestSync()
        dismiss()
    }

    private func delete() {
        guard let existing else { return }
        existing.deletedAt = Date()
        existing.updatedAt = Date()
        existing.needsSync = true
        sync.requestSync()
        dismiss()
    }
}
