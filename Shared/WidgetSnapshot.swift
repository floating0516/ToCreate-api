import Foundation

enum WidgetAPIStatus: String, Codable, Equatable {
    case reachable
    case unreachable
    case unknown

    var title: String {
        switch self {
        case .reachable:
            return "API 可连通"
        case .unreachable:
            return "API 不可连通"
        case .unknown:
            return "API 待确认"
        }
    }

    var symbol: String {
        switch self {
        case .reachable, .unreachable, .unknown:
            return "●"
        }
    }
}

typealias APIStatus = WidgetAPIStatus

struct WidgetSnapshot: Codable, Equatable {
    var apiStatus: WidgetAPIStatus
    var balance: Double?
    var todayRequests: Double?
    var todayTokens: Double?
    var todayCost: Double?
    var apiKeyCount: Double?
    var updatedAt: Date?
    var privacyModeEnabled: Bool
}

struct WidgetSnapshotDisplay: Equatable {
    let snapshot: WidgetSnapshot
    let now: Date

    init(snapshot: WidgetSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    var statusText: String {
        "\(snapshot.apiStatus.symbol) \(snapshot.apiStatus.title)"
    }

    var balanceText: String {
        snapshot.privacyModeEnabled ? "已隐藏" : currency(snapshot.balance)
    }

    var todayCostText: String {
        snapshot.privacyModeEnabled ? "已隐藏" : currency(snapshot.todayCost)
    }

    var apiKeyCountText: String {
        if snapshot.privacyModeEnabled {
            return "已隐藏"
        }
        guard let apiKeyCount = snapshot.apiKeyCount else {
            return "—"
        }
        return "\(integer(apiKeyCount)) 个"
    }

    var requestsText: String {
        guard let todayRequests = snapshot.todayRequests else {
            return "—"
        }
        return "\(integer(todayRequests)) 次"
    }

    var tokensText: String {
        compactInteger(snapshot.todayTokens)
    }

    var updatedAtText: String {
        guard let updatedAt = snapshot.updatedAt else {
            return "—"
        }
        return DateFormatter.localizedString(from: updatedAt, dateStyle: .none, timeStyle: .short)
    }

    var isStale: Bool {
        guard let updatedAt = snapshot.updatedAt else {
            return true
        }
        return now.timeIntervalSince(updatedAt) > 600
    }

    private func currency(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$" + String(format: "%.2f", value)
    }

    private func integer(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private func compactInteger(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }
        let absolute = abs(value)
        if absolute >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if absolute >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return integer(value)
    }
}
