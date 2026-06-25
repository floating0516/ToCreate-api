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

    static func compactCurrency(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }

        let absolute = abs(value)
        if absolute >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        }
        if absolute >= 1_000 {
            return String(format: "$%.1fK", value / 1_000)
        }
        return displayCurrency(value)
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
    static let metricRowTitles = [AppBranding.displayName, "API 状态", "今日用量", "请求", "Tokens", "费用", "账户", "余额", "API 密钥", "更新于"]
    static let showsChannelStatus = false
    static let labelColumnWidth: CGFloat = 72
    static let serviceStatusTitles = (ok: "● API 可连通", partial: "● API 待确认", unavailable: "● API 不可连通", offline: "● 未连接")

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
    static let width: CGFloat = 600
    static let height: CGFloat = 590
    static let horizontalPadding: CGFloat = 26
    static let verticalPadding: CGFloat = 22
    static let rowSpacing: CGFloat = 11
    static let labelColumnWidth: CGFloat = 108
    static let controlColumnWidth: CGFloat = 330
    static let thresholdFieldWidth: CGFloat = 92
    static let footerHeight: CGFloat = 52
    static let layoutUsesAlignedGrid = true
}

enum StatusBarProgressLayout {
    static let maximumVisibleItems = 3

    static func titleWidth(_ title: String) -> CGFloat {
        guard !title.isEmpty else {
            return 0
        }

        return min(max(CGFloat(title.count) * 8, 112), 160)
    }

    static func requiredStatusItemLength(itemCount: Int) -> CGFloat? {
        guard itemCount > 0 else {
            return nil
        }

        return CGFloat(min(itemCount, maximumVisibleItems)) * 48 + 24
    }

    static func requiredStatusItemLength(itemCount: Int, title: String) -> CGFloat? {
        guard let progressLength = requiredStatusItemLength(itemCount: itemCount) else {
            return nil
        }

        return progressLength + titleWidth(title)
    }
}

enum StatusBarProgressPresentation {
    enum TextPosition: Equatable {
        case aboveBar
        case belowBar
    }

    static let previewTitle = "日"
    static let previewPercent = "62%"
    static let previewFraction = 0.62
    static let textColorName = "white"
    static let textWeightName = "bold"
    static let textPosition = TextPosition.aboveBar
    static let labelFontSize: CGFloat = 10
    static let percentFontSize: CGFloat = 10
    static let viewHeight: CGFloat = 20
}

enum StatusBarState: Equatable {
    case refreshing
    case healthy
    case partial
    case unavailable
    case offline

    static func from(ok: Int, abnormal: Int, unknown: Int) -> StatusBarState {
        if ok > 0 {
            return .healthy
        }
        if abnormal > 0 || unknown > 0 {
            return .partial
        }
        return .offline
    }

    var symbolName: String {
        "dog"
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
            return "\(AppBranding.statusMessagePrefix) API 可连通"
        case .partial:
            return "\(AppBranding.statusMessagePrefix) API 待确认"
        case .unavailable:
            return "\(AppBranding.statusMessagePrefix) API 不可连通"
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

enum StatusBarMetricOption: String, CaseIterable, Equatable, Hashable {
    case balance
    case todayCost
    case todayRequests
    case todayTokens
    case subscriptionDaily
    case subscriptionWeekly
    case subscriptionMonthly

    var title: String {
        switch self {
        case .balance:
            return "余额"
        case .todayCost:
            return "今日费用"
        case .todayRequests:
            return "请求次数"
        case .todayTokens:
            return "Tokens"
        case .subscriptionDaily:
            return "订阅：每日"
        case .subscriptionWeekly:
            return "订阅：每周"
        case .subscriptionMonthly:
            return "订阅：每月"
        }
    }

    var compactLabel: String {
        switch self {
        case .balance:
            return "余"
        case .todayCost:
            return "费"
        case .todayRequests:
            return "请求"
        case .todayTokens:
            return "Tok"
        case .subscriptionDaily:
            return "日"
        case .subscriptionWeekly:
            return "周"
        case .subscriptionMonthly:
            return "月"
        }
    }
}

struct SubscriptionDashboardMetric: Equatable {
    let used: Double?
    let limit: Double?
    let resetText: String?

    var menuText: String {
        let value = "\(MetricsFormatter.displayCurrency(used)) / \(MetricsFormatter.displayCurrency(limit))"
        guard let resetText, !resetText.isEmpty else {
            return value
        }
        return "\(value) · \(resetText)"
    }

    var statusBarText: String {
        "\(MetricsFormatter.displayCurrency(used))/\(MetricsFormatter.compactCurrency(limit))"
    }

    var usageFraction: Double? {
        guard let used, let limit, limit > 0 else {
            return nil
        }
        return min(max(used / limit, 0), 1)
    }
}

struct StatusBarProgressSnapshot: Equatable {
    let label: String
    let fraction: Double

    var colorName: String {
        if fraction >= 0.9 {
            return "systemRed"
        }
        if fraction >= 0.7 {
            return "systemOrange"
        }
        return "systemGreen"
    }

    var color: NSColor {
        switch colorName {
        case "systemRed":
            return .systemRed
        case "systemOrange":
            return .systemOrange
        default:
            return .systemGreen
        }
    }

    var accessibilityLabel: String {
        "\(label) \(Int((fraction * 100).rounded()))%"
    }
}

struct SubscriptionInfo: Equatable {
    let name: String?
    let provider: String?
    let statusText: String?
    let expiryText: String?
    let daily: SubscriptionDashboardMetric
    let weekly: SubscriptionDashboardMetric
    let monthly: SubscriptionDashboardMetric

    var titleText: String {
        [name, provider, statusText]
            .compactMap { value in
                guard let value, !value.isEmpty else {
                    return nil
                }
                return value
            }
            .joined(separator: " · ")
    }

    func metric(for option: StatusBarMetricOption) -> SubscriptionDashboardMetric? {
        switch option {
        case .subscriptionDaily:
            return daily
        case .subscriptionWeekly:
            return weekly
        case .subscriptionMonthly:
            return monthly
        default:
            return nil
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
    var statusBarMetricOptions: [StatusBarMetricOption]

    static let `default` = AppPreferences(
        privacyModeEnabled: false,
        refreshInterval: .off,
        launchAtLoginEnabled: false,
        autoCheckUpdatesEnabled: false,
        channelAlertEnabled: true,
        balanceAlertEnabled: false,
        balanceAlertThreshold: 100,
        dailyCostAlertEnabled: false,
        dailyCostAlertThreshold: 10,
        statusBarMetricOptions: [.subscriptionDaily, .subscriptionWeekly, .subscriptionMonthly]
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
        static let statusBarMetricOptions = "statusBarMetricOptions"
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
            dailyCostAlertThreshold: defaults.object(forKey: Key.dailyCostAlertThreshold) as? Double ?? base.dailyCostAlertThreshold,
            statusBarMetricOptions: (defaults.stringArray(forKey: Key.statusBarMetricOptions) ?? base.statusBarMetricOptions.map(\.rawValue))
                .compactMap(StatusBarMetricOption.init(rawValue:))
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
        defaults.set(preferences.statusBarMetricOptions.map(\.rawValue), forKey: Key.statusBarMetricOptions)
    }
}

struct StatusMetricDisplay {
    let balance: Double?
    let todayRequests: Double?
    let todayTokens: Double?
    let todayCost: Double?
    let apiKeyCount: Double?
    var subscription: SubscriptionInfo? = nil
    let preferences: AppPreferences

    var balanceText: String {
        preferences.privacyModeEnabled ? "已隐藏" : MetricsFormatter.displayCurrency(balance)
    }

    var todayCostText: String {
        preferences.privacyModeEnabled ? "已隐藏" : MetricsFormatter.displayCurrency(todayCost)
    }

    var todayRequestsText: String {
        "\(MetricsFormatter.integer(todayRequests)) 次"
    }

    var tokensText: String {
        MetricsFormatter.compactInteger(todayTokens)
    }

    var apiKeyCountText: String {
        preferences.privacyModeEnabled ? "已隐藏" : apiKeyCount.map { "\(MetricsFormatter.integer($0)) 个" } ?? "—"
    }

    private var statusBarMetricOptionsForTitle: [StatusBarMetricOption] {
        let selected = preferences.statusBarMetricOptions
        let containsOnlySubscriptionOptions = selected.allSatisfy { option in
            switch option {
            case .subscriptionDaily, .subscriptionWeekly, .subscriptionMonthly:
                return true
            default:
                return false
            }
        }

        if (subscription == nil || preferences.privacyModeEnabled) && containsOnlySubscriptionOptions {
            return [.balance, .todayCost]
        }

        return selected
    }

    var statusBarProgressItems: [StatusBarProgressSnapshot] {
        guard !preferences.privacyModeEnabled, let subscription else {
            return []
        }

        return preferences.statusBarMetricOptions.compactMap { option -> StatusBarProgressSnapshot? in
            switch option {
            case .subscriptionDaily, .subscriptionWeekly, .subscriptionMonthly:
                guard let fraction = subscription.metric(for: option)?.usageFraction else {
                    return nil
                }
                return StatusBarProgressSnapshot(label: option.compactLabel, fraction: fraction)
            default:
                return nil
            }
        }
    }

    var statusBarTitle: String {
        statusBarMetricOptionsForTitle.map { option in
            switch option {
            case .balance:
                return "\(option.compactLabel) \(preferences.privacyModeEnabled ? "已隐藏" : MetricsFormatter.compactCurrency(balance))"
            case .todayCost:
                return "\(option.compactLabel) \(preferences.privacyModeEnabled ? "已隐藏" : MetricsFormatter.displayCurrency(todayCost))"
            case .todayRequests:
                return "\(option.compactLabel) \(MetricsFormatter.integer(todayRequests))"
            case .todayTokens:
                return "\(option.compactLabel) \(MetricsFormatter.compactInteger(todayTokens))"
            case .subscriptionDaily, .subscriptionWeekly, .subscriptionMonthly:
                return ""
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: "  ")
    }
}

enum SubscriptionPayloadParser {
    static func subscriptionInfo(_ value: Any?) -> SubscriptionInfo? {
        guard let object = value as? [String: Any] else {
            return nil
        }

        let daily = dashboardMetric(object["daily"])
        let weekly = dashboardMetric(object["weekly"])
        let monthly = dashboardMetric(object["monthly"])
        guard daily.used != nil || daily.limit != nil || weekly.used != nil || weekly.limit != nil || monthly.used != nil || monthly.limit != nil else {
            return nil
        }

        return SubscriptionInfo(
            name: stringValue(object["name"]),
            provider: stringValue(object["provider"]),
            statusText: stringValue(object["status"] ?? object["statusText"]),
            expiryText: stringValue(object["expiryText"] ?? object["expiresText"] ?? object["expiresAt"]),
            daily: daily,
            weekly: weekly,
            monthly: monthly
        )
    }

    private static func dashboardMetric(_ value: Any?) -> SubscriptionDashboardMetric {
        let object = value as? [String: Any] ?? [:]
        return SubscriptionDashboardMetric(
            used: MetricPayloadParser.doubleValue(object["used"] ?? object["current"]),
            limit: MetricPayloadParser.doubleValue(object["limit"] ?? object["quota"]),
            resetText: stringValue(object["resetText"] ?? object["reset"])
        )
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else {
            return nil
        }
        let string: String
        if let text = value as? String {
            string = text
        } else {
            string = String(describing: value)
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum MetricPayloadParser {
    static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(trimmed)
        default:
            return nil
        }
    }
}

enum MetricValueCache {
    static func replacingMissing(current: Double?, cached: Double?) -> Double? {
        current ?? cached
    }
}

struct AppUpdateInfo: Equatable {
    let version: String
    let downloadURL: URL
    let releasePageURL: URL
    let releaseNotes: String
}

enum UpdateDownloadPlanner {
    static func destinationURL(for update: AppUpdateInfo, updatesDirectory: URL) -> URL {
        updatesDirectory.appendingPathComponent("\(AppBranding.displayName)-v\(update.version).dmg")
    }
}

enum UpdateInstallerScript {
    static func makeScript(dmgPath: String, appName: String, installPath: String) -> String {
        """
        #!/bin/bash
        set -euo pipefail

        DMG_PATH=\(shellQuoted(dmgPath))
        APP_NAME=\(shellQuoted(appName))
        INSTALL_PATH=\(shellQuoted(installPath))
        MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tocreate-update.XXXXXX")"

        cleanup() {
          hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
          rm -rf "$MOUNT_DIR"
        }
        trap cleanup EXIT

        sleep 1
        hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -quiet
        ditto "$MOUNT_DIR/$APP_NAME" "$INSTALL_PATH"
        xattr -dr com.apple.quarantine "$INSTALL_PATH" >/dev/null 2>&1 || true
        open "$INSTALL_PATH"
        """
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
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
    enum ParserError: Error, LocalizedError {
        case invalidPayload
        case missingReleaseURL
        case missingAsset
        case githubError(String)

        var errorDescription: String? {
            switch self {
            case .invalidPayload:
                return "GitHub 返回的不是有效的 Release 信息。"
            case .missingReleaseURL:
                return "GitHub Release 缺少页面地址。"
            case .missingAsset:
                return "GitHub Release 里没有找到 ToCreate.dmg。"
            case .githubError(let message):
                return "GitHub 返回错误：\(message)"
            }
        }
    }

    static func parseLatestRelease(_ data: Data, assetName: String) throws -> AppUpdateInfo {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParserError.invalidPayload
        }

        if let message = errorMessage(from: object) {
            throw ParserError.githubError(message)
        }

        guard let tagName = object["tag_name"] as? String else {
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

    static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return errorMessage(from: object)
    }

    private static func errorMessage(from object: [String: Any]) -> String? {
        (object["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

enum GitHubReleaseRedirectParser {
    enum ParserError: Error, LocalizedError {
        case missingReleaseURL
        case missingVersion

        var errorDescription: String? {
            switch self {
            case .missingReleaseURL:
                return "GitHub 没有返回最新版本页面。"
            case .missingVersion:
                return "GitHub 最新版本页面里没有找到版本号。"
            }
        }
    }

    static func parseLatestReleaseURL(_ releaseURL: URL?, downloadURL: URL) throws -> AppUpdateInfo {
        guard let releaseURL else {
            throw ParserError.missingReleaseURL
        }

        let pathComponents = releaseURL.pathComponents
        let tagName: String?
        if let tagIndex = pathComponents.firstIndex(of: "tag"),
           pathComponents.indices.contains(pathComponents.index(after: tagIndex)) {
            tagName = pathComponents[pathComponents.index(after: tagIndex)]
        } else {
            tagName = pathComponents.last
        }

        guard let tagName,
              tagName.hasPrefix("v") || tagName.first?.isNumber == true else {
            throw ParserError.missingVersion
        }

        return AppUpdateInfo(
            version: normalizedVersion(tagName),
            downloadURL: downloadURL,
            releasePageURL: releaseURL,
            releaseNotes: ""
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
