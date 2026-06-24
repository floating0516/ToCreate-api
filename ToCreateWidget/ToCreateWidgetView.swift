import WidgetKit
import SwiftUI

struct ToCreateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ToCreateWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(for: WidgetSnapshotDisplay(snapshot: snapshot, now: entry.date))
            } else {
                emptyState
            }
        }
        .widgetURL(URL(string: "tocreate://open"))
        .widgetBackground()
    }

    private func content(for display: WidgetSnapshotDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ToCreate")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(display.statusText)
                .font(.subheadline)
                .foregroundStyle(statusColor(display.snapshot.apiStatus))

            if display.isStale {
                Text("数据可能过期")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch family {
            case .systemSmall:
                metric("余额", display.balanceText)
            case .systemMedium:
                metric("余额", display.balanceText)
                metric("今日费用", display.todayCostText)
                metric("请求", display.requestsText)
            default:
                Text("今日用量")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                metric("请求", display.requestsText)
                metric("Tokens", display.tokensText)
                metric("费用", display.todayCostText)
                Divider()
                Text("账户")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                metric("余额", display.balanceText)
                metric("API 密钥", display.apiKeyCountText)
                Spacer(minLength: 0)
                metric("更新于", display.updatedAtText)
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ToCreate")
                .font(.headline)
            Text("等待 ToCreate 刷新")
                .font(.subheadline)
            Text("打开 App 后会自动更新")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.caption)
    }

    private func statusColor(_ status: WidgetAPIStatus) -> Color {
        switch status {
        case .reachable:
            return .green
        case .unreachable:
            return .red
        case .unknown:
            return .orange
        }
    }
}

private extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(macOSApplicationExtension 14.0, *) {
            containerBackground(.background, for: .widget)
        } else {
            background(Color.clear)
        }
    }
}
