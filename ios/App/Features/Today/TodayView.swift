import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil }, sort: \TaskItem.dueAt)
    private var allTasks: [TaskItem]

    @Query(filter: #Predicate<EventItem> { $0.deletedAt == nil }, sort: \EventItem.startAt)
    private var allEvents: [EventItem]

    @State private var quickTitle = ""
    @FocusState private var quickFocused: Bool

    private var overdueTasks: [TaskItem] {
        allTasks.filter { $0.completedAt == nil && $0.dueAt != nil && $0.dueAt! < Calendar.current.startOfDay(for: Date()) }
    }

    private var todayTasks: [TaskItem] {
        allTasks.filter { $0.completedAt == nil && $0.dueAt != nil && Calendar.current.isDateInToday($0.dueAt!) }
    }

    private var unscheduledTasks: [TaskItem] {
        allTasks.filter { $0.completedAt == nil && $0.dueAt == nil }
    }

    private var completedToday: [TaskItem] {
        allTasks.filter { $0.completedAt != nil && Calendar.current.isDateInToday($0.completedAt!) }
    }

    private var todayEvents: [EventItem] {
        allEvents.filter { Calendar.current.isDateInToday($0.startAt) || Calendar.current.isDateInToday($0.endAt) }
    }

    private var isEmpty: Bool {
        overdueTasks.isEmpty && todayTasks.isEmpty && todayEvents.isEmpty && unscheduledTasks.isEmpty && completedToday.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if !overdueTasks.isEmpty {
                    Section("已逾期") { ForEach(overdueTasks) { TaskRow(task: $0) } }
                }
                if !todayTasks.isEmpty {
                    Section("今日待办") { ForEach(todayTasks) { TaskRow(task: $0) } }
                }
                if !todayEvents.isEmpty {
                    Section("今日日程") { ForEach(todayEvents) { EventRow(event: $0) } }
                }
                if !unscheduledTasks.isEmpty {
                    Section("未安排日期") { ForEach(unscheduledTasks) { TaskRow(task: $0) } }
                }
                if !completedToday.isEmpty {
                    Section("今日已完成") { ForEach(completedToday) { TaskRow(task: $0) } }
                }
                if isEmpty {
                    ContentUnavailableView(
                        "今天很清爽",
                        systemImage: "sun.max",
                        description: Text("在下方输入框快速添加任务")
                    )
                }
            }
            .navigationTitle("今日")
            .safeAreaInset(edge: .bottom) { quickAddBar }
            .profileToolbar()
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 10) {
            TextField("快速添加任务…", text: $quickTitle)
                .textFieldStyle(.roundedBorder)
                .focused($quickFocused)
                .submitLabel(.done)
                .onSubmit(addTask)
            Button(action: addTask) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .disabled(quickTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func addTask() {
        let title = quickTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let task = TaskItem(title: title)
        context.insert(task)
        quickTitle = ""
        sync.requestSync()
    }
}

/// 任务行：勾选完成 + 左滑删除（M3 将接入详情编辑）
struct TaskRow: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync
    @Bindable var task: TaskItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: toggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.green : Theme.quadrantColor(task.quadrant))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                HStack(spacing: 8) {
                    if let due = task.dueAt {
                        Label(due.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            .foregroundStyle(due < Date() && !task.isCompleted ? .red : .secondary)
                    }
                    if !task.subtasks.isEmpty {
                        let done = task.subtasks.filter(\.done).count
                        Label("\(done)/\(task.subtasks.count)", systemImage: "list.bullet")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func toggle() {
        task.completedAt = task.isCompleted ? nil : Date()
        task.updatedAt = Date()
        task.needsSync = true
        sync.requestSync()
    }

    private func delete() {
        task.deletedAt = Date()
        task.updatedAt = Date()
        task.needsSync = true
        sync.requestSync()
    }
}

struct EventRow: View {
    let event: EventItem

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.accent)
                .frame(width: 4)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                Text("\(event.startAt.formatted(date: .omitted, time: .shortened)) – \(event.endAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !event.location.isEmpty {
                    Text("📍 \(event.location)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
