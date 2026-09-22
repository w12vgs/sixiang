import SwiftUI
import SwiftData

/// 笔记列表：置顶优先、搜索、左滑删除、点按编辑
struct NotesListView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    // 注意：@Query 的 filter+多 SortDescriptor 组合会让类型检查器超时，排序放到计算属性中
    @Query(filter: #Predicate<NoteItem> { $0.deletedAt == nil && $0.archived == false })
    private var notes: [NoteItem]

    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingNote: NoteItem?

    /// 置顶优先，其次按更新时间倒序
    private var sortedNotes: [NoteItem] {
        notes.sorted {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private var filtered: [NoteItem] {
        guard !searchText.isEmpty else { return sortedNotes }
        return sortedNotes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { note in
                    Button {
                        editingNote = note
                    } label: {
                        NoteRow(note: note)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView("没有笔记", systemImage: "note.text", description: Text("点右上角 + 新建"))
                }
            }
            .searchable(text: $searchText, prompt: "搜索笔记")
            .navigationTitle("笔记")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("新建笔记")
                }
            }
            .profileToolbar()
            .sheet(isPresented: $showEditor) { NoteEditorView() }
            .sheet(item: $editingNote) { NoteEditorView(note: $0) }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let note = filtered[index]
            note.deletedAt = Date()
            note.updatedAt = Date()
            note.needsSync = true
        }
        sync.requestSync()
    }
}

struct NoteRow: View {
    let note: NoteItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                Text(note.title.isEmpty ? "无标题" : note.title)
                    .font(.headline)
                    .lineLimit(1)
            }
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
