import AppKit
import Foundation

enum AppBranding {
    static let displayName = "ToCreate"
    static let dmgName = "ToCreate.dmg"
    static let bundleAppName = "ToCreate.app"
    static let statusMessagePrefix = "ToCreate"
    static let repositoryURL = URL(string: "https://github.com/floating0516/ToCreate-api")!
    static let updateFeedDescription = "GitHub Releases"
}

struct AboutInfo {
    let appName: String
    let version: String
    let build: String
    let repositoryURL: URL
    let updateFeedDescription: String

    var displayVersion: String {
        "\(version) (\(build))"
    }

    var informativeText: String {
        """
        版本：\(displayVersion)
        仓库：\(repositoryURL.absoluteString)
        更新源：\(updateFeedDescription)
        更新方式：检查并下载 DMG
        """
    }
}

enum ClipboardFormatter {
    static func pageReference(title: String?, url: URL) -> String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedTitle.isEmpty {
            return url.absoluteString
        }

        return "\(trimmedTitle)\n\(url.absoluteString)"
    }
}

enum MetricsFormatter {
    static func currency(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }

        return "$" + String(format: "%.4f", value)
    }

    static func displayCurrency(_ value: Double?) -> String {
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

    static func integer(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }

        return String(Int(value.rounded()))
    }

    static func compactInteger(_ value: Double?) -> String {
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

    static func channelSummary(ok: Int, abnormal: Int, unknown: Int) -> String {
        if ok + abnormal + unknown == 0 {
            return "暂无渠道"
        }

        var parts = ["正常 \(ok)", "异常 \(abnormal)"]
        if unknown > 0 {
            parts.append("待确认 \(unknown)")
        }
        return parts.joined(separator: " / ")
    }

    static func compactChannelStatus(ok: Int, abnormal: Int, unknown: Int) -> String {
        if abnormal > 0 {
            return "● 异常 \(abnormal)"
        }
        if unknown > 0 {
            return "● 待确认 \(unknown)"
        }
        if ok > 0 {
            return "● 正常 \(ok)"
        }
        return "—"
    }
}

enum StatusMenuPresentation {
    static let metricsItemsAreEnabled = true
    static let refreshControlKeepsMenuOpen = true
    static let refreshControlStyleName = "plainMenuRow"
    static let metricTextAlpha: CGFloat = 1
    static let balanceTextColorName = "systemGreen"
    static let usageTextColorName = "controlAccentColor"
    static let channelTextColorName = "systemOrange"
    static let updatedAtTextColorName = "secondaryLabelColor"
    static let statusMenuActionTitles = ["刷新状态", "打开主窗口", "检查更新", "偏好设置…", "退出"]
    static let quitActionName = "quitApp"
    static let metricRowTitles = [AppBranding.displayName, "服务状态", "今日用量", "请求", "Tokens", "费用", "账户", "余额", "API 密钥", "渠道", "更新于"]
    static let showsChannelStatus = true
    static let labelColumnWidth: CGFloat = 72
    static let serviceStatusTitles = (ok: "● 服务正常", partial: "● 部分渠道异常", unavailable: "● 服务不可用", offline: "● 未连接")

    static var balanceTextColor: NSColor {
        primaryTextColor
    }

    static var usageTextColor: NSColor {
        primaryTextColor
    }

    static var costTextColor: NSColor {
        primaryTextColor
    }

    static var tokensTextColor: NSColor {
        primaryTextColor
    }

    static var channelTextColor: NSColor {
        warningTextColor
    }

    static func channelTextColor(ok: Int, abnormal: Int, unknown: Int) -> NSColor {
        if abnormal > 0 {
            return dangerTextColor
        }
        if unknown > 0 {
            return warningTextColor
        }
        if ok > 0 {
            return successTextColor
        }
        return updatedAtTextColor
    }

    static var apiKeysTextColor: NSColor {
        primaryTextColor
    }

    static var updatedAtTextColor: NSColor {
        secondaryTextColor
    }

    static var headerTextColor: NSColor {
        NSColor(calibratedRed: 0.29, green: 0.33, blue: 0.38, alpha: metricTextAlpha)
    }

    static var primaryTextColor: NSColor {
        NSColor(calibratedRed: 0.37, green: 0.42, blue: 0.46, alpha: metricTextAlpha)
    }

    static var secondaryTextColor: NSColor {
        NSColor(calibratedRed: 0.54, green: 0.58, blue: 0.62, alpha: metricTextAlpha)
    }

    static var successTextColor: NSColor {
        NSColor(calibratedRed: 0.16, green: 0.50, blue: 0.28, alpha: metricTextAlpha)
    }

    static var warningTextColor: NSColor {
        NSColor(calibratedRed: 0.74, green: 0.48, blue: 0.12, alpha: metricTextAlpha)
    }

    static var dangerTextColor: NSColor {
        NSColor(calibratedRed: 0.78, green: 0.18, blue: 0.18, alpha: metricTextAlpha)
    }
}

enum PreferencesWindowPresentation {
    static let width: CGFloat = 460
    static let height: CGFloat = 364
    static let horizontalPadding: CGFloat = 28
    static let verticalPadding: CGFloat = 22
    static let rowSpacing: CGFloat = 12
    static let labelColumnWidth: CGFloat = 108
    static let controlColumnWidth: CGFloat = 190
    static let thresholdFieldWidth: CGFloat = 92
    static let footerHeight: CGFloat = 52
    static let layoutUsesAlignedGrid = true
}

enum StatusBarState: Equatable {
    case refreshing
    case healthy
    case partial
    case unavailable
    case offline

    static func from(ok: Int, abnormal: Int, unknown: Int) -> StatusBarState {
        if abnormal > 0 {
            return .unavailable
        }
        if unknown > 0 {
            return .partial
        }
        if ok > 0 {
            return .healthy
        }
        return .offline
    }

    var symbolName: String {
        switch self {
        case .refreshing:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .healthy:
            return "checkmark.circle.fill"
        case .partial:
            return "exclamationmark.circle.fill"
        case .unavailable:
            return "xmark.circle.fill"
        case .offline:
            return "circle.dashed"
        }
    }

    var colorName: String {
        switch self {
        case .refreshing:
            return "controlAccentColor"
        case .healthy:
            return "systemGreen"
        case .partial:
            return "systemOrange"
        case .unavailable:
            return "systemRed"
        case .offline:
            return "secondaryLabelColor"
        }
    }

    var color: NSColor {
        switch self {
        case .refreshing:
            return .controlAccentColor
        case .healthy:
            return .systemGreen
        case .partial:
            return .systemOrange
        case .unavailable:
            return .systemRed
        case .offline:
            return .secondaryLabelColor
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .refreshing:
            return "\(AppBranding.statusMessagePrefix) 正在刷新"
        case .healthy:
            return "\(AppBranding.statusMessagePrefix) 服务正常"
        case .partial:
            return "\(AppBranding.statusMessagePrefix) 部分渠道异常"
        case .unavailable:
            return "\(AppBranding.statusMessagePrefix) 服务不可用"
        case .offline:
            return "\(AppBranding.statusMessagePrefix) 未连接"
        }
    }
}

enum RefreshIntervalOption: String, CaseIterable, Equatable {
    case off
    case oneMinute
    case fiveMinutes
    case fifteenMinutes

    var title: String {
        switch self {
        case .off:
            return "关闭"
        case .oneMinute:
            return "每 1 分钟"
        case .fiveMinutes:
            return "每 5 分钟"
        case .fifteenMinutes:
            return "每 15 分钟"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .off:
            return nil
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        }
    }
}

struct AppPreferences: Equatable {
    var privacyModeEnabled: Bool
    var refreshInterval: RefreshIntervalOption
    var launchAtLoginEnabled: Bool
    var autoCheckUpdatesEnabled: Bool
    var channelAlertEnabled: Bool
    var balanceAlertEnabled: Bool
    var balanceAlertThreshold: Double
    var dailyCostAlertEnabled: Bool
    var dailyCostAlertThreshold: Double

    static let `default` = AppPreferences(
        privacyModeEnabled: false,
        refreshInterval: .off,
        launchAtLoginEnabled: false,
        autoCheckUpdatesEnabled: false,
        channelAlertEnabled: true,
        balanceAlertEnabled: false,
        balanceAlertThreshold: 100,
        dailyCostAlertEnabled: false,
        dailyCostAlertThreshold: 10
    )
}

struct PreferencesStore {
    private enum Key {
        static let privacyModeEnabled = "privacyModeEnabled"
        static let refreshInterval = "refreshInterval"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let autoCheckUpdatesEnabled = "autoCheckUpdatesEnabled"
        static let channelAlertEnabled = "channelAlertEnabled"
        static let balanceAlertEnabled = "balanceAlertEnabled"
        static let balanceAlertThreshold = "balanceAlertThreshold"
        static let dailyCostAlertEnabled = "dailyCostAlertEnabled"
        static let dailyCostAlertThreshold = "dailyCostAlertThreshold"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppPreferences {
        let base = AppPreferences.default
        let refreshRaw = defaults.string(forKey: Key.refreshInterval) ?? base.refreshInterval.rawValue

        return AppPreferences(
            privacyModeEnabled: defaults.object(forKey: Key.privacyModeEnabled) as? Bool ?? base.privacyModeEnabled,
            refreshInterval: RefreshIntervalOption(rawValue: refreshRaw) ?? base.refreshInterval,
            launchAtLoginEnabled: defaults.object(forKey: Key.launchAtLoginEnabled) as? Bool ?? base.launchAtLoginEnabled,
            autoCheckUpdatesEnabled: defaults.object(forKey: Key.autoCheckUpdatesEnabled) as? Bool ?? base.autoCheckUpdatesEnabled,
            channelAlertEnabled: defaults.object(forKey: Key.channelAlertEnabled) as? Bool ?? base.channelAlertEnabled,
            balanceAlertEnabled: defaults.object(forKey: Key.balanceAlertEnabled) as? Bool ?? base.balanceAlertEnabled,
            balanceAlertThreshold: defaults.object(forKey: Key.balanceAlertThreshold) as? Double ?? base.balanceAlertThreshold,
            dailyCostAlertEnabled: defaults.object(forKey: Key.dailyCostAlertEnabled) as? Bool ?? base.dailyCostAlertEnabled,
            dailyCostAlertThreshold: defaults.object(forKey: Key.dailyCostAlertThreshold) as? Double ?? base.dailyCostAlertThreshold
        )
    }

    func save(_ preferences: AppPreferences) {
        defaults.set(preferences.privacyModeEnabled, forKey: Key.privacyModeEnabled)
        defaults.set(preferences.refreshInterval.rawValue, forKey: Key.refreshInterval)
        defaults.set(preferences.launchAtLoginEnabled, forKey: Key.launchAtLoginEnabled)
        defaults.set(preferences.autoCheckUpdatesEnabled, forKey: Key.autoCheckUpdatesEnabled)
        defaults.set(preferences.channelAlertEnabled, forKey: Key.channelAlertEnabled)
        defaults.set(preferences.balanceAlertEnabled, forKey: Key.balanceAlertEnabled)
        defaults.set(preferences.balanceAlertThreshold, forKey: Key.balanceAlertThreshold)
        defaults.set(preferences.dailyCostAlertEnabled, forKey: Key.dailyCostAlertEnabled)
        defaults.set(preferences.dailyCostAlertThreshold, forKey: Key.dailyCostAlertThreshold)
    }
}

struct StatusMetricDisplay {
    let balance: Double?
    let todayCost: Double?
    let apiKeyCount: Double?
    let preferences: AppPreferences

    var balanceText: String {
        preferences.privacyModeEnabled ? "已隐藏" : MetricsFormatter.displayCurrency(balance)
    }

    var todayCostText: String {
        preferences.privacyModeEnabled ? "已隐藏" : MetricsFormatter.displayCurrency(todayCost)
    }

    var apiKeyCountText: String {
        preferences.privacyModeEnabled ? "已隐藏" : apiKeyCount.map { "\(MetricsFormatter.integer($0)) 个" } ?? "—"
    }
}

struct AppUpdateInfo: Equatable {
    let version: String
    let downloadURL: URL
    let releasePageURL: URL
    let releaseNotes: String
}

enum VersionComparator {
    static func isRemoteVersion(_ remoteVersion: String, newerThan currentVersion: String) -> Bool {
        let remote = numericComponents(from: remoteVersion)
        let current = numericComponents(from: currentVersion)
        let count = max(remote.count, current.count)

        for index in 0..<count {
            let remotePart = index < remote.count ? remote[index] : 0
            let currentPart = index < current.count ? current[index] : 0
            if remotePart > currentPart {
                return true
            }
            if remotePart < currentPart {
                return false
            }
        }
        return false
    }

    private static func numericComponents(from version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".")
            .map { component in
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}

enum GitHubReleaseParser {
    enum ParserError: Error {
        case invalidPayload
        case missingReleaseURL
        case missingAsset
    }

    static func parseLatestRelease(_ data: Data, assetName: String) throws -> AppUpdateInfo {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = object["tag_name"] as? String else {
            throw ParserError.invalidPayload
        }

        guard let releasePageString = object["html_url"] as? String,
              let releasePageURL = URL(string: releasePageString) else {
            throw ParserError.missingReleaseURL
        }

        guard let assets = object["assets"] as? [[String: Any]],
              let asset = assets.first(where: { ($0["name"] as? String) == assetName }),
              let downloadString = asset["browser_download_url"] as? String,
              let downloadURL = URL(string: downloadString) else {
            throw ParserError.missingAsset
        }

        return AppUpdateInfo(
            version: normalizedVersion(tagName),
            downloadURL: downloadURL,
            releasePageURL: releasePageURL,
            releaseNotes: object["body"] as? String ?? ""
        )
    }

    private static func normalizedVersion(_ tagName: String) -> String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}

enum WindowLifecyclePolicy {
    static let releasesMainWindowWhenClosed = false
}

enum EntryPageRouting {
    static let loginPath = "/login"
    static let dashboardPath = "/dashboard"
    static let authTokenStorageKey = "auth_token"
}
