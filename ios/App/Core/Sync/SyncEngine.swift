import Foundation
import SwiftData
import Observation

/// 离线优先同步引擎：
/// - 所有修改先写本地 SwiftData，后台防抖推送
/// - 增量拉取合并，冲突按 updatedAt 裁决（last-write-wins）
/// - 软删除墓碑、超期墓碑本地清理
@MainActor
@Observable
final class SyncEngine {
    enum SyncState: Equatable {
        case idle
        case syncing
        case offline
        case failed(String)

        var label: String {
            switch self {
            case .idle: return "已同步"
            case .syncing: return "同步中…"
            case .offline: return "离线（待网络恢复）"
            case .failed(let msg): return msg
            }
        }
    }

    private(set) var state: SyncState = .idle
    private(set) var lastSyncedAt: Date?

    private let context: ModelContext
    private var inFlight = false
    private var debounceTask: Task<Void, Never>?

    init(context: ModelContext) {
        self.context = context
        self.lastSyncedAt = UserDefaults.standard.object(forKey: "lastSyncAt") as? Date
    }

    // MARK: - 触发

    /// 本地数据变化后调用（防抖合并；离线时也能安全调用）
    func requestSync(delay: TimeInterval = 1.5) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    func sync() async {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }
        state = .syncing
        do {
            try await pull()
            try await push()
            try context.save()
            lastSyncedAt = Date()
            UserDefaults.standard.set(lastSyncedAt, forKey: "lastSyncAt")
            state = .idle
            NotificationScheduler.rescheduleAll(context: context)
        } catch let err as APIError {
            state = err.isOffline ? .offline : .failed(err.errorDescription ?? "同步失败")
        } catch {
            state = .failed("同步失败")
        }
    }

    // MARK: - 拉取（增量）

    private func pull() async throws {
        var query = [URLQueryItem(name: "deviceId", value: APIClient.shared.deviceID)]
        if let since = lastSyncedAt {
            query.append(URLQueryItem(name: "since", value: SixiangDate.string(since.addingTimeInterval(-120))))
        }
        let options = APIClient.RequestOptions(method: "GET", body: nil, auth: true, query: query)
        let resp: SyncResponse = try await APIClient.shared.send("/api/sync", options: options)
        apply(resp)
    }

    private func apply(_ resp: SyncResponse) {
        for dto in resp.tasks { upsert(dto) }
        for dto in resp.events { upsert(dto) }
        for dto in resp.notes { upsert(dto) }
        for dto in resp.tags { upsert(dto) }
        purgeOldTombstones()
    }

    // MARK: - 推送（本地脏数据）

    private func push() async throws {
        try await pushTasks()
        try await pushEvents()
        try await pushNotes()
        try await pushTags()
    }

    private func pushTasks() async throws {
        let dirty = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.needsSync }))) ?? []
        for task in dirty {
            let payload = TaskPayload(from: task)
            if task.isOnServer {
                if task.deletedAt != nil {
                    try await APIClient.shared.sendVoid("/api/tasks/\(task.id)", options: .init(method: "DELETE", auth: true))
                    task.needsSync = false
                } else {
                    let dto: TaskDTO = try await APIClient.shared.send(
                        "/api/tasks/\(task.id)",
                        options: try .json(method: "PUT", body: payload, auth: true)
                    )
                    applyServer(dto, to: task)
                }
            } else if task.deletedAt != nil {
                // 创建后未同步即删除：无需上云，直接标记干净
                task.needsSync = false
            } else {
                let dto: TaskDTO = try await APIClient.shared.send(
                    "/api/tasks",
                    options: try .json(method: "POST", body: payload, auth: true)
                )
                applyServer(dto, to: task)
            }
        }
    }

    private func pushEvents() async throws {
        let dirty = (try? context.fetch(FetchDescriptor<EventItem>(predicate: #Predicate { $0.needsSync }))) ?? []
        for event in dirty {
            let payload = EventPayload(from: event)
            if event.isOnServer {
                if event.deletedAt != nil {
                    try await APIClient.shared.sendVoid("/api/events/\(event.id)", options: .init(method: "DELETE", auth: true))
                    event.needsSync = false
                } else {
                    let dto: EventDTO = try await APIClient.shared.send(
                        "/api/events/\(event.id)",
                        options: try .json(method: "PUT", body: payload, auth: true)
                    )
                    applyServer(dto, to: event)
                }
            } else if event.deletedAt != nil {
                event.needsSync = false
            } else {
                let dto: EventDTO = try await APIClient.shared.send(
                    "/api/events",
                    options: try .json(method: "POST", body: payload, auth: true)
                )
                applyServer(dto, to: event)
            }
        }
    }

    private func pushNotes() async throws {
        let dirty = (try? context.fetch(FetchDescriptor<NoteItem>(predicate: #Predicate { $0.needsSync }))) ?? []
        for note in dirty {
            let payload = NotePayload(from: note)
            if note.isOnServer {
                if note.deletedAt != nil {
                    try await APIClient.shared.sendVoid("/api/notes/\(note.id)", options: .init(method: "DELETE", auth: true))
                    note.needsSync = false
                } else {
                    let dto: NoteDTO = try await APIClient.shared.send(
                        "/api/notes/\(note.id)",
                        options: try .json(method: "PUT", body: payload, auth: true)
                    )
                    applyServer(dto, to: note)
                }
            } else if note.deletedAt != nil {
                note.needsSync = false
            } else {
                let dto: NoteDTO = try await APIClient.shared.send(
                    "/api/notes",
                    options: try .json(method: "POST", body: payload, auth: true)
                )
                applyServer(dto, to: note)
            }
        }
    }

    private func pushTags() async throws {
        let dirty = (try? context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.needsSync }))) ?? []
        for tag in dirty {
            let payload = TagPayload(id: tag.id, name: tag.name, color: tag.color)
            if tag.isOnServer {
                if tag.deletedAt != nil {
                    try await APIClient.shared.sendVoid("/api/tags/\(tag.id)", options: .init(method: "DELETE", auth: true))
                    tag.needsSync = false
                } else {
                    let dto: TagDTO = try await APIClient.shared.send(
                        "/api/tags/\(tag.id)",
                        options: try .json(method: "PUT", body: payload, auth: true)
                    )
                    applyServer(dto, to: tag)
                }
            } else if tag.deletedAt != nil {
                tag.needsSync = false
            } else {
                let dto: TagDTO = try await APIClient.shared.send(
                    "/api/tags",
                    options: try .json(method: "POST", body: payload, auth: true)
                )
                applyServer(dto, to: tag)
            }
        }
    }

    // MARK: - 合并

    private func task(id: String) -> TaskItem? {
        var d = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    private func event(id: String) -> EventItem? {
        var d = FetchDescriptor<EventItem>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    private func note(id: String) -> NoteItem? {
        var d = FetchDescriptor<NoteItem>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    private func tag(id: String) -> TagItem? {
        var d = FetchDescriptor<TagItem>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    private func upsert(_ dto: TaskDTO) {
        if let local = task(id: dto.id) {
            if !local.needsSync || dto.updatedAt > local.updatedAt {
                overwrite(local, with: dto)
            }
        } else {
            let item = TaskItem(id: dto.id, title: dto.title, isOnServer: true)
            overwrite(item, with: dto)
            context.insert(item)
        }
    }

    private func upsert(_ dto: EventDTO) {
        if let local = event(id: dto.id) {
            if !local.needsSync || dto.updatedAt > local.updatedAt {
                overwrite(local, with: dto)
            }
        } else {
            let item = EventItem(id: dto.id, title: dto.title, startAt: dto.startAt, endAt: dto.endAt, isOnServer: true)
            overwrite(item, with: dto)
            context.insert(item)
        }
    }

    private func upsert(_ dto: NoteDTO) {
        if let local = note(id: dto.id) {
            if !local.needsSync || dto.updatedAt > local.updatedAt {
                overwrite(local, with: dto)
            }
        } else {
            let item = NoteItem(id: dto.id, title: dto.title, isOnServer: true)
            overwrite(item, with: dto)
            context.insert(item)
        }
    }

    private func upsert(_ dto: TagDTO) {
        if let local = tag(id: dto.id) {
            if !local.needsSync || dto.updatedAt > local.updatedAt {
                overwrite(local, with: dto)
            }
        } else {
            let item = TagItem(id: dto.id, name: dto.name, isOnServer: true)
            overwrite(item, with: dto)
            context.insert(item)
        }
    }

    private func overwrite(_ item: TaskItem, with dto: TaskDTO) {
        item.title = dto.title
        item.note = dto.note ?? ""
        item.quadrant = dto.quadrant
        item.priority = dto.priority
        item.dueAt = dto.dueAt
        item.reminderAt = dto.reminderAt
        item.repeatRule = dto.repeatRule
        item.sortOrder = dto.sortOrder
        item.completedAt = dto.completedAt
        item.deletedAt = dto.deletedAt
        item.createdAt = dto.createdAt
        item.updatedAt = dto.updatedAt
        item.tagIds = dto.tags.map(\.id)
        item.subtasks = dto.subtasks.map { SubtaskValue(id: $0.id, title: $0.title, done: $0.done, sortOrder: $0.sortOrder) }
        item.isOnServer = true
        item.needsSync = false
    }

    private func overwrite(_ item: EventItem, with dto: EventDTO) {
        item.title = dto.title
        item.note = dto.note ?? ""
        item.location = dto.location ?? ""
        item.startAt = dto.startAt
        item.endAt = dto.endAt
        item.allDay = dto.allDay
        item.remindOffsetMinutes = dto.remindOffsetMinutes
        item.repeatRule = dto.repeatRule
        item.calendarId = dto.calendarId
        item.deletedAt = dto.deletedAt
        item.createdAt = dto.createdAt
        item.updatedAt = dto.updatedAt
        item.isOnServer = true
        item.needsSync = false
    }

    private func overwrite(_ item: NoteItem, with dto: NoteDTO) {
        item.title = dto.title
        item.content = dto.content
        item.pinned = dto.pinned
        item.archived = dto.archived
        item.deletedAt = dto.deletedAt
        item.createdAt = dto.createdAt
        item.updatedAt = dto.updatedAt
        item.tagIds = dto.tags.map(\.id)
        item.isOnServer = true
        item.needsSync = false
    }

    private func overwrite(_ item: TagItem, with dto: TagDTO) {
        item.name = dto.name
        item.color = dto.color
        item.deletedAt = dto.deletedAt
        item.createdAt = dto.createdAt
        item.updatedAt = dto.updatedAt
        item.isOnServer = true
        item.needsSync = false
    }

    private func applyServer(_ dto: TaskDTO, to task: TaskItem) {
        task.updatedAt = dto.updatedAt
        task.createdAt = dto.createdAt
        task.isOnServer = true
        task.needsSync = false
    }

    private func applyServer(_ dto: EventDTO, to event: EventItem) {
        event.updatedAt = dto.updatedAt
        event.createdAt = dto.createdAt
        event.isOnServer = true
        event.needsSync = false
    }

    private func applyServer(_ dto: NoteDTO, to note: NoteItem) {
        note.updatedAt = dto.updatedAt
        note.createdAt = dto.createdAt
        note.isOnServer = true
        note.needsSync = false
    }

    private func applyServer(_ dto: TagDTO, to tag: TagItem) {
        tag.updatedAt = dto.updatedAt
        tag.createdAt = dto.createdAt
        tag.isOnServer = true
        tag.needsSync = false
    }

    // MARK: - 墓碑清理

    /// 删除超过 30 天且已同步的本地记录彻底移除
    private func purgeOldTombstones() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)

        if let tasks = try? context.fetch(FetchDescriptor<TaskItem>()) {
            for t in tasks where (t.deletedAt ?? .distantFuture) < cutoff && !t.needsSync {
                context.delete(t)
            }
        }
        if let events = try? context.fetch(FetchDescriptor<EventItem>()) {
            for e in events where (e.deletedAt ?? .distantFuture) < cutoff && !e.needsSync {
                context.delete(e)
            }
        }
        if let notes = try? context.fetch(FetchDescriptor<NoteItem>()) {
            for n in notes where (n.deletedAt ?? .distantFuture) < cutoff && !n.needsSync {
                context.delete(n)
            }
        }
        if let tags = try? context.fetch(FetchDescriptor<TagItem>()) {
            for t in tags where (t.deletedAt ?? .distantFuture) < cutoff && !t.needsSync {
                context.delete(t)
            }
        }
    }
}
