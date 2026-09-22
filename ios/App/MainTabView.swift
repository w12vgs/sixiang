import SwiftUI

struct MainTabView: View {
    @Environment(SyncEngine.self) private var sync
    @Environment(\.scenePhase) private var scenePhase
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
            checkQuickAddRequest()
            await sync.sync()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkQuickAddRequest()
            }
        }
        .onOpenURL { url in
            // 备用直达通道：sixiang://add
            if url.scheme == "sixiang", url.host == "add" {
                showQuickAdd = true
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            TaskEditorView()
        }
    }

    /// Widget「快速添加」信号（App Group UserDefaults，iOS 17 兼容）
    private func checkQuickAddRequest() {
        let defaults = UserDefaults(suiteName: StoreConfig.appGroupID)
        if defaults?.bool(forKey: "pendingQuickAdd") == true {
            defaults?.set(false, forKey: "pendingQuickAdd")
            showQuickAdd = true
        }
    }
}
