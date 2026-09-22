import AppIntents
import WidgetKit
import SwiftData

/// 勾选/取消完成任务（Widget 按钮互动，离线可用）
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "完成任务"
    static var description = IntentDescription("勾选或取消完成该任务")

    @Parameter(title: "任务 ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard let container = try? StoreConfig.makeContainer() else { return .result() }
        let context = ModelContext(container)
        var desc = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.serverId == taskID })
        desc.fetchLimit = 1
        if let task = try? context.fetch(desc).first {
            task.completedAt = task.completedAt == nil ? Date() : nil
            task.updatedAt = Date()
            task.needsSync = true // 下次 App 同步时推送
            try? context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 快速添加：打开 App 并直达新建任务
struct OpenAddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "快速添加任务"
    static var description = IntentDescription("打开四象并新建任务")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        guard let url = URL(string: "sixiang://add") else { return .result() }
        return .result(opensIntent: OpenURLIntent(url))
    }
}
