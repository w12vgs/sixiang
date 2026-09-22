import SwiftUI

struct MainTabView: View {
    @Environment(SyncEngine.self) private var sync

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "sun.max") }
            QuadrantView()
                .tabItem { Label("四象限", systemImage: "square.grid.2x2") }
            CalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }
            NotesListView()
                .tabItem { Label("笔记", systemImage: "note.text") }
            StatsView()
                .tabItem { Label("看板", systemImage: "chart.bar.xaxis") }
        }
        .task {
            _ = await NotificationScheduler.ensureAuthorization()
            await sync.sync()
        }
    }
}
