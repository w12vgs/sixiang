import SwiftUI

/// M4 将实现：月/周/日视图、时间轴、日程编辑器、与任务联动
struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "日历",
                systemImage: "calendar",
                description: Text("M4 开发中：月/周/日视图与日程管理")
            )
            .navigationTitle("日历")
            .profileToolbar()
        }
    }
}
