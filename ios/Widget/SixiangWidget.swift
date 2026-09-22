import WidgetKit
import SwiftUI
import SwiftData

// MARK: - 数据快照

struct WidgetTask: Identifiable {
    let id: String
    let title: String
    let quadrant: Int
}

struct SixiangEntry: TimelineEntry {
    let date: Date
    let pendingTasks: [WidgetTask] // 逾期 + 今日待办
    let completedToday: Int
    let streak: Int
    let quadrantCounts: [Int]
}

// MARK: - TimelineProvider（通过 App Group 共享的 SwiftData 读取）

struct SixiangProvider: TimelineProvider {
    func placeholder(in context: Context) -> SixiangEntry {
        SixiangEntry(date: Date(), pendingTasks: [], completedToday: 0, streak: 0, quadrantCounts: [0, 0, 0, 0])
    }

    func getSnapshot(in context: Context, completion: @escaping (SixiangEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SixiangEntry>) -> Void) {
        let entry = load()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> SixiangEntry {
        guard let container = try? StoreConfig.makeContainer() else {
            return SixiangEntry(date: Date(), pendingTasks: [], completedToday: 0, streak: 0, quadrantCounts: [0, 0, 0, 0])
        }
        let context = ModelContext(container)
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)!

        let allTasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []

        let pending = allTasks
            .filter { $0.deletedAt == nil && $0.completedAt == nil && $0.dueAt != nil && $0.dueAt! < todayEnd }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            .map { WidgetTask(id: $0.serverId, title: $0.title, quadrant: $0.quadrant) }

        let completedAll = allTasks.filter { $0.deletedAt == nil && $0.completedAt != nil }
        let completedToday = completedAll.filter { cal.isDate($0.completedAt!, inSameDayAs: todayStart) }.count

        var streak = 0
        var cursor = todayStart
        while completedAll.contains(where: { cal.isDate($0.completedAt!, inSameDayAs: cursor) }) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }

        var q = [0, 0, 0, 0]
        for t in allTasks where t.deletedAt == nil && t.completedAt == nil {
            q[max(0, min(3, t.quadrant - 1))] += 1
        }

        return SixiangEntry(
            date: Date(),
            pendingTasks: pending,
            completedToday: completedToday,
            streak: streak,
            quadrantCounts: q
        )
    }
}

// MARK: - 各尺寸视图

struct SixiangWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SixiangEntry

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .systemLarge: large
        case .accessoryCircular: accessoryCircular
        case .accessoryRectangular: accessoryRectangular
        default: small
        }
    }

    // 小：今日待办数 + 连续打卡
    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                Text("四象")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.pendingTasks.count)")
                .font(.system(size: 36, weight: .bold))
            Text("今日待办")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Label("连续 \(entry.streak) 天", systemImage: "flame.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // 中：今日待办前 4 条（可勾选完成）+ 快速添加
    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("今日待办", systemImage: "sun.max")
                    .font(.headline)
                Spacer()
                Text("已完成 \(entry.completedToday)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if entry.pendingTasks.isEmpty {
                Text("今天没有待办 🎉")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.pendingTasks.prefix(4)) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.quadrantColor(task.quadrant))
                            .frame(width: 6, height: 6)
                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Button(intent: ToggleTaskIntent(taskID: task.id)) {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if entry.pendingTasks.count > 4 {
                    Text("…还有 \(entry.pendingTasks.count - 4) 项")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Button(intent: OpenAddTaskIntent()) {
                Label("快速添加", systemImage: "plus.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // 大：四象限概览
    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("四象限概览", systemImage: "square.grid.2x2")
                    .font(.headline)
                Spacer()
                Label("连续 \(entry.streak) 天", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ForEach(1...4, id: \.self) { q in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Theme.quadrantColor(q)).frame(width: 7, height: 7)
                            Text(Theme.quadrantShortTitle(q))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Text("\(entry.quadrantCounts[q - 1])")
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemGroupedBackground)))
                }
            }
            Spacer(minLength: 0)
            Button(intent: OpenAddTaskIntent()) {
                Label("快速添加任务", systemImage: "plus.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // 锁屏：完成率圆环
    private var accessoryCircular: some View {
        Gauge(value: Double(entry.completedToday), in: 0...max(1, Double(entry.completedToday + entry.pendingTasks.count))) {
            Image(systemName: "checkmark.circle.fill")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Theme.accent)
    }

    // 锁屏：文字概览
    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("今日待办 \(entry.pendingTasks.count)", systemImage: "sun.max")
                .font(.headline)
            Text("已完成 \(entry.completedToday) · 连续 \(entry.streak) 天")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget 定义

@main
struct SixiangWidgetBundle: WidgetBundle {
    var body: some Widget {
        SixiangWidget()
    }
}

struct SixiangWidget: Widget {
    let kind = "SixiangWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SixiangProvider()) { entry in
            SixiangWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("四象")
        .description("今日待办、连续打卡与四象限概览")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}
