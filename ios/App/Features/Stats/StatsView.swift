import SwiftUI
import SwiftData
import Charts

/// 数据看板：本地聚合统计（离线可用）+ Swift Charts 图表
/// 后端 /api/stats/overview 已就绪，可在联网时作为兜底数据源（v1 本地聚合为主）
struct StatsView: View {
    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil })
    private var tasks: [TaskItem]

    enum RangeOption: String, CaseIterable {
        case week = "周"
        case month = "月"
        case year = "年"
    }

    @State private var range: RangeOption = .week

    private var days: Int {
        switch range {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }

    // MARK: - 聚合

    private struct DayStat: Identifiable {
        let date: Date
        let created: Int
        let completed: Int
        var id: Date { date }
    }

    private var daily: [DayStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [DayStat] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -i, to: today)!
            let completed = tasks.filter { $0.completedAt != nil && cal.isDate($0.completedAt!, inSameDayAs: day) }.count
            let created = tasks.filter { cal.isDate($0.createdAt, inSameDayAs: day) }.count
            result.append(DayStat(date: day, created: created, completed: completed))
        }
        return result
    }

    private var quadrantCounts: [Int] {
        var q = [0, 0, 0, 0]
        for t in tasks {
            q[max(0, min(3, t.quadrant - 1))] += 1
        }
        return q
    }

    private var openCount: Int { tasks.filter { $0.completedAt == nil }.count }
    private var completedCount: Int { tasks.filter { $0.completedAt != nil }.count }
    private var totalCount: Int { tasks.count }

    private var completionRate: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    /// 连续打卡：截至今天，每天至少完成 1 个任务
    private var streak: Int {
        let cal = Calendar.current
        var cursor = cal.startOfDay(for: Date())
        var s = 0
        while true {
            let has = tasks.contains { $0.completedAt != nil && cal.isDate($0.completedAt!, inSameDayAs: cursor) }
            if has {
                s += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
            } else {
                break
            }
        }
        return s
    }

    private var completedInRange: Int {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date()))!
        return tasks.filter { $0.completedAt != nil && $0.completedAt! >= start }.count
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("周期", selection: $range) {
                        ForEach(RangeOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    overviewCards
                    completedChart
                    quadrantChart
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("看板")
            .profileToolbar()
        }
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "连续打卡", value: "\(streak) 天", icon: "flame.fill", color: .orange)
            statCard(title: "完成率", value: totalCount == 0 ? "—" : "\(Int(completionRate * 100))%", icon: "chart.pie.fill", color: Theme.accent)
            statCard(title: "未完成", value: "\(openCount)", icon: "circle.dashed", color: .blue)
            statCard(title: "\(range.rawValue)内完成", value: "\(completedInRange)", icon: "checkmark.circle.fill", color: .green)
        }
        .padding(.horizontal)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var completedChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每日完成趋势")
                .font(.subheadline.bold())
                .padding(.horizontal)
            if daily.allSatisfy({ $0.completed == 0 && $0.created == 0 }) {
                Text("该周期暂无数据")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart(daily) { item in
                    BarMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("完成", item.completed)
                    )
                    .foregroundStyle(Theme.accent.gradient)
                    LineMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("创建", item.created)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: range == .week ? 7 : 6)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: false)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    private var quadrantChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("四象限分布")
                .font(.subheadline.bold())
                .padding(.horizontal)
            if totalCount == 0 {
                Text("暂无任务")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart {
                    ForEach(1...4, id: \.self) { q in
                        SectorMark(
                            angle: .value("数量", quadrantCounts[q - 1]),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(Theme.quadrantColor(q))
                    }
                }
                .frame(height: 180)

                HStack {
                    ForEach(1...4, id: \.self) { q in
                        VStack(spacing: 2) {
                            HStack(spacing: 3) {
                                Circle().fill(Theme.quadrantColor(q)).frame(width: 6, height: 6)
                                Text(Theme.quadrantShortTitle(q))
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            Text("\(quadrantCounts[q - 1])")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }
}
