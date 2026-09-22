import SwiftUI
import SwiftData

/// 任务编辑器（新建/编辑共用）：四象限、优先级、时间、标签、子任务
struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    @Query(filter: #Predicate<TagItem> { $0.deletedAt == nil }, sort: \TagItem.name)
    private var tags: [TagItem]

    let existing: TaskItem?

    @State private var title: String
    @State private var note: String
    @State private var quadrant: Int
    @State private var priority: Int
    @State private var hasDue: Bool
    @State private var dueAt: Date
    @State private var hasReminder: Bool
    @State private var reminderAt: Date
    @State private var tagIds: [String]
    @State private var subtasks: [SubtaskValue]
    @State private var newSubtask = ""
    @State private var newTagName = ""

    init(task: TaskItem? = nil, initialQuadrant: Int? = nil) {
        self.existing = task
        _title = State(initialValue: task?.title ?? "")
        _note = State(initialValue: task?.note ?? "")
        _quadrant = State(initialValue: task?.quadrant ?? initialQuadrant ?? 1)
        _priority = State(initialValue: task?.priority ?? 2)
        _tagIds = State(initialValue: task?.tagIds ?? [])
        _subtasks = State(initialValue: task?.subtasks ?? [])
        _hasDue = State(initialValue: task?.dueAt != nil)
        _dueAt = State(initialValue: task?.dueAt ?? Date())
        _hasReminder = State(initialValue: task?.reminderAt != nil)
        _reminderAt = State(initialValue: task?.reminderAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("标题", text: $title, axis: .vertical)
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("四象限") { quadrantPicker }

                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        Text("高").tag(1)
                        Text("中").tag(2)
                        Text("低").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                Section("时间") {
                    Toggle("设置截止时间", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("截止", selection: $dueAt, displayedComponents: [.date, .hourAndMinute])
                    }
                    Toggle("提醒", isOn: $hasReminder.animation())
                    if hasReminder {
                        DatePicker("提醒时间", selection: $reminderAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("标签") { tagSection }

                Section("子任务") {
                    ForEach($subtasks) { $sub in
                        HStack {
                            Button {
                                sub.done.toggle()
                            } label: {
                                Image(systemName: sub.done ? "checkmark.square.fill" : "square")
                            }
                            .buttonStyle(.plain)
                            TextField("子任务", text: $sub.title)
                        }
                    }
                    .onDelete { subtasks.remove(atOffsets: $0) }
                    HStack {
                        TextField("添加子任务", text: $newSubtask)
                            .onSubmit(addSubtask)
                        Button(action: addSubtask) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newSubtask.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) { delete() } label: {
                            Label("删除任务", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "新建任务" : "编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var quadrantPicker: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(1...4, id: \.self) { q in
                Button {
                    quadrant = q
                } label: {
                    VStack(spacing: 4) {
                        Text(Theme.quadrantTitle(q))
                            .font(.footnote)
                            .foregroundStyle(.primary)
                        Image(systemName: quadrant == q ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Theme.quadrantColor(q))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(quadrant == q ? Theme.quadrantColor(q).opacity(0.18) : Color(.tertiarySystemFill))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tags.isEmpty {
                Text("暂无标签，在下方创建")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(tags) { tag in chip(tag) }
                }
            }
            HStack {
                TextField("新标签名", text: $newTagName)
                    .onSubmit(createTag)
                Button(action: createTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
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

    private func addSubtask() {
        let t = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        subtasks.append(SubtaskValue(title: t, sortOrder: subtasks.count))
        newSubtask = ""
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let tag = TagItem(name: name)
        context.insert(tag)
        tagIds.append(tag.serverId)
        newTagName = ""
        sync.requestSync()
    }

    private func save() {
        let item = existing ?? TaskItem(title: "")
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.note = note
        item.quadrant = quadrant
        item.priority = priority
        item.dueAt = hasDue ? dueAt : nil
        item.reminderAt = hasReminder ? reminderAt : nil
        item.tagIds = tagIds
        item.subtasks = subtasks
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
