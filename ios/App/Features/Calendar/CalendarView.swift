import SwiftUI
import SwiftData

/// 日历：月视图 + 日议程（日程与任务联动显示）
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    @Query(filter: #Predicate<EventItem> { $0.deletedAt == nil }, sort: \EventItem.startAt)
    private var events: [EventItem]

    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil }, sort: \TaskItem.dueAt)
    private var tasks: [TaskItem]

    @State private var month = Date()
    @State private var selectedDate = Date()
    @State private var editingEvent: EventItem?
    @State private var editingTask: TaskItem?
    @State private var showNewEvent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthGrid
                Divider()
                dayAgenda
            }
            .navigationTitle("日历")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewEvent = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("新建日程")
                }
            }
            .profileToolbar()
            .sheet(isPresented: $showNewEvent) { EventEditorView(initialDate: selectedDate) }
            .sheet(item: $editingEvent) { EventEditorView(event: $0) }
            .sheet(item: $editingTask) { TaskEditorView(task: $0) }
        }
    }

    // MARK: - 月视图

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: month)) ?? Date()
    }

    private var leadingBlanks: Int {
        // 周一起始：weekday 1=周日 … 7=周六
        (Calendar.current.component(.weekday, from: monthStart) + 5) % 7
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var monthGrid: some View {
        VStack(spacing: 8) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text(month.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)

            HStack {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { wd in
                    Text(wd)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }
                ForEach(0..<daysInMonth, id: \.self) { offset in
                    let day = Calendar.current.date(byAdding: .day, value: offset, to: monthStart)!
                    dayCell(day)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        let counts = dayCounts(day)

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.subheadline)
                    .foregroundStyle(isToday ? Theme.accent : .primary)
                HStack(spacing: 3) {
                    if counts.events > 0 {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5)
                    }
                    if counts.tasks > 0 {
                        Circle().fill(Theme.quadrantColor(3)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? Theme.accent.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isToday ? Theme.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dayCounts(_ day: Date) -> (events: Int, tasks: Int) {
        let e = events.filter { Calendar.current.isDate($0.startAt, inSameDayAs: day) }.count
        let t = tasks.filter { $0.completedAt == nil && $0.dueAt != nil && Calendar.current.isDate($0.dueAt!, inSameDayAs: day) }.count
        return (e, t)
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: monthStart) {
            month = newMonth
        }
    }

    // MARK: - 日议程

    private var dayEvents: [EventItem] {
        events.filter { Calendar.current.isDate($0.startAt, inSameDayAs: selectedDate) }
    }

    private var dayTasks: [TaskItem] {
        tasks.filter { $0.completedAt == nil && $0.dueAt != nil && Calendar.current.isDate($0.dueAt!, inSameDayAs: selectedDate) }
    }

    private var dayAgenda: some View {
        List {
            Section("日程") {
                if dayEvents.isEmpty {
                    Text("无日程")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                ForEach(dayEvents) { event in
                    Button {
                        editingEvent = event
                    } label: {
                        EventRow(event: event)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("任务") {
                if dayTasks.isEmpty {
                    Text("无任务")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                ForEach(dayTasks) { task in
                    Button {
                        editingTask = task
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(Theme.quadrantColor(task.quadrant)).frame(width: 6, height: 6)
                            Text(task.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            if let due = task.dueAt {
                                Text(due.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
