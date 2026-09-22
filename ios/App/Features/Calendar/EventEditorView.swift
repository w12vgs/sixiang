import SwiftUI
import SwiftData

/// 日程编辑器（新建/编辑）：时间、全天、地点、提醒
struct EventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var sync

    let existing: EventItem?

    @State private var title: String
    @State private var note: String
    @State private var location: String
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var allDay: Bool
    @State private var hasReminder: Bool
    @State private var remindOffset: Int

    init(event: EventItem? = nil, initialDate: Date? = nil) {
        self.existing = event
        let base = initialDate ?? Date()
        let start = event?.startAt
            ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base)
            ?? base
        let end = event?.endAt ?? start.addingTimeInterval(3600)
        _title = State(initialValue: event?.title ?? "")
        _note = State(initialValue: event?.note ?? "")
        _location = State(initialValue: event?.location ?? "")
        _startAt = State(initialValue: start)
        _endAt = State(initialValue: end)
        _allDay = State(initialValue: event?.allDay ?? false)
        _remindOffset = State(initialValue: event?.remindOffsetMinutes ?? 15)
        _hasReminder = State(initialValue: event?.remindOffsetMinutes != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("日程") {
                    TextField("标题", text: $title, axis: .vertical)
                    TextField("地点（可选）", text: $location)
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("时间") {
                    Toggle("全天", isOn: $allDay.animation())
                    if allDay {
                        DatePicker("日期", selection: $startAt, displayedComponents: [.date])
                    } else {
                        DatePicker("开始", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("结束", selection: $endAt, in: startAt..., displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("提醒") {
                    Toggle("提醒", isOn: $hasReminder.animation())
                    if hasReminder {
                        Picker("提前", selection: $remindOffset) {
                            Text("准时").tag(0)
                            Text("5 分钟").tag(5)
                            Text("15 分钟").tag(15)
                            Text("30 分钟").tag(30)
                            Text("1 小时").tag(60)
                            Text("1 天").tag(1440)
                        }
                        .pickerStyle(.menu)
                    }
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) { delete() } label: {
                            Label("删除日程", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "新建日程" : "编辑日程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        var start = startAt
        var end = allDay ? start : endAt
        if end < start {
            end = start.addingTimeInterval(3600)
        }

        let item = existing ?? EventItem(title: "", startAt: start, endAt: end)
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.note = note
        item.location = location
        item.startAt = start
        item.endAt = end
        item.allDay = allDay
        item.remindOffsetMinutes = hasReminder ? remindOffset : nil
        item.updatedAt = Date()
        item.needsSync = true
        if existing == nil {
            context.insert(item)
        }
        sync.requestSync()
        dismiss()
    }

    private func delete() {
        guard let existing else { return }
        existing.deletedAt = Date()
        existing.updatedAt = Date()
        existing.needsSync = true
        sync.requestSync()
        dismiss()
    }
}
