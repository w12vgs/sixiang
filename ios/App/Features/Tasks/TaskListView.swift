import SwiftUI
import SwiftData

/// 任务列表视图（待办/已完成/全部筛选）
struct TaskListView: View {
    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil }, sort: \TaskItem.sortOrder)
    private var all: [TaskItem]

    enum Filter: String, CaseIterable {
        case pending = "待办"
        case completed = "已完成"
        case all = "全部"
    }

    @State private var filter: Filter = .pending
    @State private var showEditor = false

    private var filtered: [TaskItem] {
        switch filter {
        case .pending: return all.filter { $0.completedAt == nil }
        case .completed: return all.filter { $0.completedAt != nil }
        case .all: return all
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { TaskRow(task: $0) }
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView("没有任务", systemImage: "checklist", description: Text("点右上角 + 新建"))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("筛选", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新建任务")
            }
        }
        .sheet(isPresented: $showEditor) { TaskEditorView() }
    }
}
