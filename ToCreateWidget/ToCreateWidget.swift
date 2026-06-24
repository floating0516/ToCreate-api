import WidgetKit
import SwiftUI

struct ToCreateWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct ToCreateWidgetProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    private static func sampleSnapshot(date: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(
            apiStatus: .reachable,
            balance: 399_478.22,
            todayRequests: 46,
            todayTokens: 616_102,
            todayCost: 0.78,
            apiKeyCount: 6,
            updatedAt: date,
            privacyModeEnabled: false
        )
    }

    func placeholder(in context: Context) -> ToCreateWidgetEntry {
        ToCreateWidgetEntry(
            date: Date(),
            snapshot: Self.sampleSnapshot()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ToCreateWidgetEntry) -> Void) {
        let now = Date()
        let snapshot = (try? store.load()) ?? Self.sampleSnapshot(date: now)
        completion(ToCreateWidgetEntry(date: now, snapshot: snapshot))
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
