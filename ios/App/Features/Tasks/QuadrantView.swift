import SwiftUI
import SwiftData

/// M2 基础版：2×2 矩阵 + 统计（M3 将加入拖拽换象限、详情编辑、快捷新建）
struct QuadrantView: View {
    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil && $0.completedAt == nil }, sort: \TaskItem.sortOrder)
    private var tasks: [TaskItem]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(1...4, id: \.self) { q in
                        QuadrantCard(quadrant: q, tasks: tasks.filter { $0.quadrant == q })
                    }
                }
                .padding()
            }
            .navigationTitle("四象限")
            .profileToolbar()
        }
    }
}

struct QuadrantCard: View {
    let quadrant: Int
    let tasks: [TaskItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.quadrantColor(quadrant))
                    .frame(width: 8, height: 8)
                Text(Theme.quadrantTitle(quadrant))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text("\(tasks.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if tasks.isEmpty {
                Text("暂无任务")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(tasks.prefix(4)) { task in
                    Text(task.title)
                        .font(.footnote)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                if tasks.count > 4 {
                    Text("…等 \(tasks.count) 项")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
