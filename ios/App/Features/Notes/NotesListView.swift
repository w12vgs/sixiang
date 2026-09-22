import SwiftUI
import SwiftData

/// 笔记列表：置顶优先、搜索、左滑删除、点按编辑
struct NotesListView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    @Query(
        filter: #Predicate<NoteItem> { $0.deletedAt == nil && $0.archived == false },
        sort: [SortDescriptor(\NoteItem.pinned, order: .reverse), SortDescriptor(\NoteItem.updatedAt, order: .reverse)]
    )
    private var notes: [NoteItem]

    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingNote: NoteItem?

    private var filtered: [NoteItem] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
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
