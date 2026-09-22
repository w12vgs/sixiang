import SwiftUI
import SwiftData

@main
struct SixiangApp: App {
    @State private var authManager = AuthManager.shared
    @State private var syncEngine: SyncEngine
    private let container: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try StoreConfig.makeContainer()
        } catch {
            do {
                container = try StoreConfig.makeInMemoryContainer()
            } catch {
                fatalError("无法创建数据容器: \(error)")
            }
        }
        self.container = container
        _syncEngine = State(initialValue: SyncEngine(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(syncEngine)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
