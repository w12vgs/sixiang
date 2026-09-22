import SwiftUI
import SwiftData

/// 四象限主视图：2×2 矩阵（拖拽换象限）/ 列表模式切换
struct QuadrantView: View {
    enum Mode {
        case matrix
        case list
    }

    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil && $0.completedAt == nil }, sort: \TaskItem.sortOrder)
    private var tasks: [TaskItem]

    @State private var mode: Mode = .matrix
    @State private var editingTask: TaskItem?
    @State private var showNewTask = false
    @State private var newTaskQuadrant = 1

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .matrix: matrix
                case .list: TaskListView()
                }
            }
            .navigationTitle("四象限")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("模式", selection: $mode) {
                        Image(systemName: "square.grid.2x2").tag(Mode.matrix)
                        Image(systemName: "list.bullet").tag(Mode.list)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("视图模式")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newTaskQuadrant = 1
                        showNewTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建任务")
                }
            }
            .profileToolbar()
            .sheet(item: $editingTask) { TaskEditorView(task: $0) }
            .sheet(isPresented: $showNewTask) { TaskEditorView(initialQuadrant: newTaskQuadrant) }
        }
    }

    private var matrix: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(1...4, id: \.self) { q in
                    QuadrantCard(
                        quadrant: q,
                        tasks: tasks.filter { $0.quadrant == q },
                        onTap: { editingTask = $0 },
                        onAdd: {
                            newTaskQuadrant = q
                            showNewTask = true
                        }
                    )
                    .dropDestination(for: String.self) { ids, _ in
                        for id in ids { move(id, to: q) }
                        return true
                    }
                }
            }
            .padding()
        }
    }

    private func move(_ serverId: String, to quadrant: Int) {
        guard let task = tasks.first(where: { $0.serverId == serverId }) else { return }
        task.quadrant = quadrant
        task.updatedAt = Date()
        task.needsSync = true
        sync.requestSync()
    }
}

struct QuadrantCard: View {
    let quadrant: Int
    let tasks: [TaskItem]
    let onTap: (TaskItem) -> Void
    let onAdd: () -> Void

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
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.quadrantColor(quadrant))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("在\(Theme.quadrantTitle(quadrant))新建任务")
            }
            if tasks.isEmpty {
                Text("拖拽任务到此，或点 + 新建")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(tasks.prefix(6)) { task in
                    Text(task.title)
                        .font(.footnote)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { onTap(task) }
                        .draggable(task.serverId)
                }
                if tasks.count > 6 {
                    Text("…等 \(tasks.count) 项")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
