import WidgetKit
import SwiftUI

struct ToCreateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ToCreateWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                let display = WidgetSnapshotDisplay(snapshot: snapshot, now: entry.date)
                switch family {
                case .systemSmall:
                    smallContent(for: display)
                case .systemMedium:
                    mediumContent(for: display)
                default:
                    largeContent(for: display)
                }
            } else {
                emptyState
            }
        }
        .widgetURL(URL(string: "tocreate://open"))
        .widgetBackground()
    }

    private func smallContent(for display: WidgetSnapshotDisplay) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                header(compact: true)
                statusPill(for: display.snapshot.apiStatus)
                Spacer(minLength: 0)
                heroMetric("余额", display.balanceText, size: 26)
            }
        }
    }

    private func mediumContent(for display: WidgetSnapshotDisplay) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    header(compact: false)
                    Spacer()
                    statusPill(for: display.snapshot.apiStatus)
                }

                heroMetric("余额", display.balanceText, size: 28)

                VStack(spacing: 7) {
                    metricRow("今日费用", display.todayCostText)
                    metricRow("请求", display.requestsText)
                }
            }
        }
    }

    private func largeContent(for display: WidgetSnapshotDisplay) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    header(compact: false)
                    Spacer()
                    statusPill(for: display.snapshot.apiStatus)
                }

                heroMetric("余额", display.balanceText, size: 28)

                section("今日用量") {
                    metricRow("请求", display.requestsText)
                    metricRow("Tokens", display.tokensText)
                    metricRow("费用", display.todayCostText)
                }

                section("账户") {
                    metricRow("API 密钥", display.apiKeyCountText)
                    metricRow("更新于", display.updatedAtText)
                }

                if display.isStale {
                    staleHint
                }
            }
        }
    }

    private var emptyState: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                header(compact: false)
                statusPill(for: .unknown)
                Spacer(minLength: 0)
                Text("打开 ToCreate 后会自动更新")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.secondaryText)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    WidgetPalette.backgroundTop,
                    WidgetPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            content()
                .padding(18)
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 6, style: .continuous))

            Text("ToCreate")
                .font(.system(size: compact ? 15 : 17, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.primaryText)
        }
    }

    private func statusPill(for status: WidgetAPIStatus) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 7, height: 7)

            Text(status.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor(status))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(statusBackground(status))
        )
    }

    private func heroMetric(_ label: String, _ value: String, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WidgetPalette.secondaryText)

            Text(value)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .foregroundStyle(WidgetPalette.primaryText)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                content()
            }
        }
        .padding(.top, 2)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(WidgetPalette.secondaryText)
            Spacer(minLength: 10)
            Text(value)
                .foregroundStyle(WidgetPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
    }

    private var staleHint: some View {
        Text("数据可能过期")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(WidgetPalette.warningText)
            .padding(.top, 2)
    }

    private func statusColor(_ status: WidgetAPIStatus) -> Color {
        switch status {
        case .reachable:
            return WidgetPalette.successText
        case .unreachable:
            return WidgetPalette.dangerText
        case .unknown:
            return WidgetPalette.warningText
        }
    }

    private func statusBackground(_ status: WidgetAPIStatus) -> Color {
        switch status {
        case .reachable:
            return WidgetPalette.successBackground
        case .unreachable:
            return WidgetPalette.dangerBackground
        case .unknown:
            return WidgetPalette.warningBackground
        }
    }
}

private enum WidgetPalette {
    static let primaryText = Color(red: 0.17, green: 0.17, blue: 0.18)
    static let secondaryText = Color(red: 0.48, green: 0.48, blue: 0.50)
    static let successText = Color(red: 0.22, green: 0.58, blue: 0.30)
    static let successBackground = Color(red: 0.91, green: 0.97, blue: 0.92)
    static let dangerText = Color(red: 0.82, green: 0.23, blue: 0.22)
    static let dangerBackground = Color(red: 1.00, green: 0.91, blue: 0.90)
    static let warningText = Color(red: 0.72, green: 0.48, blue: 0.12)
    static let warningBackground = Color(red: 1.00, green: 0.95, blue: 0.84)
    static let backgroundTop = Color(red: 0.99, green: 0.99, blue: 1.00)
    static let backgroundBottom = Color(red: 0.94, green: 0.97, blue: 1.00)
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
