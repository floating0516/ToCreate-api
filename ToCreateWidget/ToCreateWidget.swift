import WidgetKit
import SwiftUI

struct ToCreateWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct ToCreateWidgetProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> ToCreateWidgetEntry {
        ToCreateWidgetEntry(
            date: Date(),
            snapshot: WidgetSnapshot(
                apiStatus: .unknown,
                balance: 399_478.22,
                todayRequests: 36,
                todayTokens: 338_100,
                todayCost: 0.12,
                apiKeyCount: 6,
                updatedAt: Date(),
                privacyModeEnabled: false
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ToCreateWidgetEntry) -> Void) {
        completion(ToCreateWidgetEntry(date: Date(), snapshot: try? store.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ToCreateWidgetEntry>) -> Void) {
        let now = Date()
        let entry = ToCreateWidgetEntry(date: now, snapshot: try? store.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ToCreateWidget: Widget {
    let kind = "ToCreateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ToCreateWidgetProvider()) { entry in
            ToCreateWidgetView(entry: entry)
                .widgetURL(URL(string: "tocreate://open"))
        }
        .configurationDisplayName("ToCreate")
        .description("查看 ToCreate API 状态、余额和今日用量。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
