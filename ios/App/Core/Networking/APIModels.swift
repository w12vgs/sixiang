import Foundation

// MARK: - 认证

struct RegisterPayload: Encodable {
    let email: String
    let password: String
    let displayName: String?
}

struct LoginPayload: Encodable {
    let email: String
    let password: String
}

struct RefreshPayload: Encodable {
    let refreshToken: String
}

struct UserDTO: Codable {
    let id: String
    let email: String
    let displayName: String?
    let createdAt: String
}

struct AuthResponse: Decodable {
    let user: UserDTO
    let accessToken: String
    let refreshToken: String
}

struct TokenPair: Decodable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - 标签

struct TagDTO: Codable, Identifiable {
    let id: String
    let name: String
    let color: String
    let deletedAt: Date?
}

struct TagPayload: Encodable {
    let id: String
    let name: String
    let color: String
}

// MARK: - 子任务

struct SubtaskDTO: Codable, Identifiable {
    let id: String
    let title: String
    let done: Bool
    let sortOrder: Int
}

struct SubtaskPayload: Encodable {
    let id: String
    let title: String
    let done: Bool
    let sortOrder: Int
}

// MARK: - 任务

struct TaskDTO: Decodable, Identifiable {
    let id: String
    let title: String
    let note: String?
    let quadrant: Int
    let priority: Int
    let dueAt: Date?
    let reminderAt: Date?
    let repeatRule: String?
    let sortOrder: Int
    let completedAt: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let subtasks: [SubtaskDTO]
    let tags: [TagDTO]

    enum CodingKeys: String, CodingKey {
        case id, title, note, quadrant, priority, dueAt, reminderAt
        case repeatRule, sortOrder, completedAt, deletedAt, createdAt, updatedAt
        case subtasks, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        quadrant = try c.decodeIfPresent(Int.self, forKey: .quadrant) ?? 1
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 2
        dueAt = try c.decodeIfPresent(Date.self, forKey: .dueAt)
        reminderAt = try c.decodeIfPresent(Date.self, forKey: .reminderAt)
        repeatRule = try c.decodeIfPresent(String.self, forKey: .repeatRule)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        subtasks = try c.decodeIfPresent([SubtaskDTO].self, forKey: .subtasks) ?? []
        tags = try c.decodeIfPresent([TagDTO].self, forKey: .tags) ?? []
    }
}

/// 任务写入载荷：完整对象，null 字段显式编码（服务端据此置空/保留）
struct TaskPayload: Encodable {
    let id: String
    let title: String
    let note: String?
    let quadrant: Int
    let priority: Int
    let dueAt: Date?
    let reminderAt: Date?
    let repeatRule: String?
    let sortOrder: Int
    let completedAt: Date?
    let tagIds: [String]
    let subtasks: [SubtaskPayload]

    init(from task: TaskItem) {
        id = task.serverId
        title = task.title
        note = task.note
        quadrant = task.quadrant
        priority = task.priority
        dueAt = task.dueAt
        reminderAt = task.reminderAt
        repeatRule = task.repeatRule
        sortOrder = task.sortOrder
        completedAt = task.completedAt
        tagIds = task.tagIds
        subtasks = task.subtasks.map { SubtaskPayload(id: $0.id, title: $0.title, done: $0.done, sortOrder: $0.sortOrder) }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, note, quadrant, priority, dueAt, reminderAt
        case repeatRule, sortOrder, completedAt, tagIds, subtasks
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeNullable(note, forKey: .note)
        try c.encode(quadrant, forKey: .quadrant)
        try c.encode(priority, forKey: .priority)
        try c.encodeNullable(dueAt, forKey: .dueAt)
        try c.encodeNullable(reminderAt, forKey: .reminderAt)
        try c.encodeNullable(repeatRule, forKey: .repeatRule)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encodeNullable(completedAt, forKey: .completedAt)
        try c.encode(tagIds, forKey: .tagIds)
        try c.encode(subtasks, forKey: .subtasks)
    }
}

extension KeyedEncodingContainer {
    mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

// MARK: - 日程

struct EventDTO: Decodable, Identifiable {
    let id: String
    let title: String
    let note: String?
    let location: String?
    let startAt: Date
    let endAt: Date
    let allDay: Bool
    let remindOffsetMinutes: Int?
    let repeatRule: String?
    let calendarId: String?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, note, location, startAt, endAt, allDay
        case remindOffsetMinutes, repeatRule, calendarId, deletedAt, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        startAt = try c.decode(Date.self, forKey: .startAt)
        endAt = try c.decode(Date.self, forKey: .endAt)
        allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
        remindOffsetMinutes = try c.decodeIfPresent(Int.self, forKey: .remindOffsetMinutes)
        repeatRule = try c.decodeIfPresent(String.self, forKey: .repeatRule)
        calendarId = try c.decodeIfPresent(String.self, forKey: .calendarId)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

struct EventPayload: Encodable {
    let id: String
    let title: String
    let note: String?
    let location: String?
    let startAt: Date
    let endAt: Date
    let allDay: Bool
    let remindOffsetMinutes: Int?
    let repeatRule: String?
    let calendarId: String?

    init(from event: EventItem) {
        id = event.serverId
        title = event.title
        note = event.note
        location = event.location
        startAt = event.startAt
        endAt = event.endAt
        allDay = event.allDay
        remindOffsetMinutes = event.remindOffsetMinutes
        repeatRule = event.repeatRule
        calendarId = event.calendarId
    }

    enum CodingKeys: String, CodingKey {
        case id, title, note, location, startAt, endAt, allDay
        case remindOffsetMinutes, repeatRule, calendarId
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeNullable(note, forKey: .note)
        try c.encodeNullable(location, forKey: .location)
        try c.encode(startAt, forKey: .startAt)
        try c.encode(endAt, forKey: .endAt)
        try c.encode(allDay, forKey: .allDay)
        try c.encodeNullable(remindOffsetMinutes, forKey: .remindOffsetMinutes)
        try c.encodeNullable(repeatRule, forKey: .repeatRule)
        try c.encodeNullable(calendarId, forKey: .calendarId)
    }
}

// MARK: - 笔记

struct NoteDTO: Decodable, Identifiable {
    let id: String
    let title: String
    let content: String
    let pinned: Bool
    let archived: Bool
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let tags: [TagDTO]

    enum CodingKeys: String, CodingKey {
        case id, title, content, pinned, archived, deletedAt, createdAt, updatedAt, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        tags = try c.decodeIfPresent([TagDTO].self, forKey: .tags) ?? []
    }
}

struct NotePayload: Encodable {
    let id: String
    let title: String
    let content: String
    let pinned: Bool
    let archived: Bool
    let tagIds: [String]

    init(from note: NoteItem) {
        id = note.serverId
        title = note.title
        content = note.content
        pinned = note.pinned
        archived = note.archived
        tagIds = note.tagIds
    }
}

// MARK: - 同步

struct SyncResponse: Decodable {
    let serverTime: String
    let since: String?
    let tasks: [TaskDTO]
    let events: [EventDTO]
    let notes: [NoteDTO]
    let tags: [TagDTO]

    enum CodingKeys: String, CodingKey {
        case serverTime, since, tasks, events, notes, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverTime = try c.decodeIfPresent(String.self, forKey: .serverTime) ?? SixiangDate.string(Date())
        since = try c.decodeIfPresent(String.self, forKey: .since)
        tasks = try c.decodeIfPresent([TaskDTO].self, forKey: .tasks) ?? []
        events = try c.decodeIfPresent([EventDTO].self, forKey: .events) ?? []
        notes = try c.decodeIfPresent([NoteDTO].self, forKey: .notes) ?? []
        tags = try c.decodeIfPresent([TagDTO].self, forKey: .tags) ?? []
    }
}
