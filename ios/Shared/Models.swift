import Foundation
import SwiftData

// MARK: - 子任务（值类型，随任务整体同步）

struct SubtaskValue: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var done: Bool
    var sortOrder: Int

    init(id: String = UUID().uuidString, title: String, done: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.done = done
        self.sortOrder = sortOrder
    }
}

// MARK: - 任务（四象限）

@Model
final class TaskItem {
    @Attribute(.unique) var serverId: String
    var title: String
    var note: String
    var quadrant: Int // 1 重要紧急 / 2 重要不紧急 / 3 紧急不重要 / 4 不紧急不重要
    var priority: Int // 1 高 / 2 中 / 3 低
    var dueAt: Date?
    var reminderAt: Date?
    var repeatRule: String?
    var sortOrder: Int
    var completedAt: Date?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var tagIds: [String]
    var subtasks: [SubtaskValue]
    /// 本地有未推送的修改
    var needsSync: Bool
    /// 是否已在服务器创建（决定推送走 POST 还是 PUT）
    var isOnServer: Bool

    init(
        serverId: String = UUID().uuidString,
        title: String,
        note: String = "",
        quadrant: Int = 1,
        priority: Int = 2,
        dueAt: Date? = nil,
        reminderAt: Date? = nil,
        repeatRule: String? = nil,
        sortOrder: Int = 0,
        completedAt: Date? = nil,
        tagIds: [String] = [],
        subtasks: [SubtaskValue] = [],
        isOnServer: Bool = false
    ) {
        self.serverId = serverId
        self.title = title
        self.note = note
        self.quadrant = quadrant
        self.priority = priority
        self.dueAt = dueAt
        self.reminderAt = reminderAt
        self.repeatRule = repeatRule
        self.sortOrder = sortOrder
        self.completedAt = completedAt
        self.deletedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tagIds = tagIds
        self.subtasks = subtasks
        self.needsSync = true
        self.isOnServer = isOnServer
    }

    var isCompleted: Bool { completedAt != nil }
    var isDeleted: Bool { deletedAt != nil }
}

// MARK: - 日程

@Model
final class EventItem {
    @Attribute(.unique) var serverId: String
    var title: String
    var note: String
    var location: String
    var startAt: Date
    var endAt: Date
    var allDay: Bool
    var remindOffsetMinutes: Int?
    var repeatRule: String?
    var calendarId: String?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool
    var isOnServer: Bool

    init(
        serverId: String = UUID().uuidString,
        title: String,
        note: String = "",
        location: String = "",
        startAt: Date,
        endAt: Date,
        allDay: Bool = false,
        remindOffsetMinutes: Int? = nil,
        repeatRule: String? = nil,
        calendarId: String? = nil,
        isOnServer: Bool = false
    ) {
        self.serverId = serverId
        self.title = title
        self.note = note
        self.location = location
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
        self.remindOffsetMinutes = remindOffsetMinutes
        self.repeatRule = repeatRule
        self.calendarId = calendarId
        self.deletedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
        self.isOnServer = isOnServer
    }

    var isDeleted: Bool { deletedAt != nil }
}

// MARK: - 笔记

@Model
final class NoteItem {
    @Attribute(.unique) var serverId: String
    var title: String
    var content: String
    var pinned: Bool
    var archived: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var tagIds: [String]
    var needsSync: Bool
    var isOnServer: Bool

    init(
        serverId: String = UUID().uuidString,
        title: String,
        content: String = "",
        pinned: Bool = false,
        archived: Bool = false,
        tagIds: [String] = [],
        isOnServer: Bool = false
    ) {
        self.serverId = serverId
        self.title = title
        self.content = content
        self.pinned = pinned
        self.archived = archived
        self.deletedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tagIds = tagIds
        self.needsSync = true
        self.isOnServer = isOnServer
    }

    var isDeleted: Bool { deletedAt != nil }
}

// MARK: - 标签

@Model
final class TagItem {
    @Attribute(.unique) var serverId: String
    var name: String
    var color: String
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool
    var isOnServer: Bool

    init(
        serverId: String = UUID().uuidString,
        name: String,
        color: String = "#5E6AD2",
        isOnServer: Bool = false
    ) {
        self.serverId = serverId
        self.name = name
        self.color = color
        self.deletedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
        self.isOnServer = isOnServer
    }

    var isDeleted: Bool { deletedAt != nil }
}
