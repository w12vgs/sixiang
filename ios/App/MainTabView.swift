import SwiftUI

struct MainTabView: View {
    @Environment(SyncEngine.self) private var sync
    @State private var showQuickAdd = false

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
        .onOpenURL { url in
            // Widget「快速添加」直达：sixiang://add
            if url.scheme == "sixiang", url.host == "add" {
                showQuickAdd = true
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            TaskEditorView()
        }
    }
}
