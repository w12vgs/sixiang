import Foundation
import SwiftData

enum StoreConfig {
    /// App Group（App 与 Widget 共享本地数据）
    static let appGroupID = "group.app.sixiang.workbench"

    static var schema: Schema {
        Schema([TaskItem.self, EventItem.self, NoteItem.self, TagItem.self])
    }

    /// 优先使用 App Group 容器（Widget 可见）；无权限（模拟器/未签名 CI）时回退默认容器。
    /// 注意：Widget 扩展若回退到自身沙盒容器，将读不到 App 的数据（小组件显示空状态）——
    /// 真机上请确保 App Group 已在开发者后台登记且签名正确（见 ios/README.md）。
    static func makeContainer() throws -> ModelContainer {
        let groupConfig = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [groupConfig])
        } catch {
            let fallback = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [fallback])
        }
    }

    /// 内存容器（预览与极端兜底）
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
