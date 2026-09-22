import WidgetKit
import SwiftUI

/// M2 占位实现：保证 Widget 扩展可构建。M7 将替换为完整小组件（今日待办/四象限/锁屏 + App Intents）。

struct WidgetEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), text: "四象")
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetEntry(date: Date(), text: "四象"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        completion(Timeline(entries: [WidgetEntry(date: Date(), text: "四象")], policy: .never))
    }
}

struct SixiangWidgetEntryView: View {
    var entry: PlaceholderProvider.Entry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .font(.title2)
            Text(entry.text)
                .font(.headline)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct SixiangWidgetBundle: WidgetBundle {
    var body: some Widget {
        SixiangWidget()
    }
}

struct SixiangWidget: Widget {
    let kind = "SixiangWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            SixiangWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("四象")
        .description("今日待办与日程（开发中）")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
