import XCTest
@testable import LiheAPI

final class NativeFeaturesTests: XCTestCase {
    private static var projectRootPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
    }

    private static func projectFile(_ relativePath: String) -> String {
        URL(fileURLWithPath: projectRootPath)
            .appendingPathComponent(relativePath)
            .path
    }

    func testAppBrandingUsesToCreateName() {
        XCTAssertEqual(AppBranding.displayName, "ToCreate")
        XCTAssertEqual(AppBranding.dmgName, "ToCreate.dmg")
        XCTAssertEqual(AppBranding.bundleAppName, "ToCreate.app")
        XCTAssertEqual(AppBranding.statusMessagePrefix, "ToCreate")
        XCTAssertEqual(AppBranding.repositoryURL.absoluteString, "https://github.com/floating0516/ToCreate-api")
        XCTAssertEqual(AppBranding.updateFeedDescription, "GitHub Releases")
    }

    func testAboutInfoFormatsVersionRepositoryAndUpdateSource() {
        let about = AboutInfo(
            appName: AppBranding.displayName,
            version: "0.1.1",
            build: "2",
            repositoryURL: AppBranding.repositoryURL,
            updateFeedDescription: AppBranding.updateFeedDescription
        )

        XCTAssertEqual(about.displayVersion, "0.1.1 (2)")
        XCTAssertTrue(about.informativeText.contains("版本：0.1.1 (2)"))
        XCTAssertTrue(about.informativeText.contains("仓库：https://github.com/floating0516/ToCreate-api"))
        XCTAssertTrue(about.informativeText.contains("更新源：GitHub Releases"))
        XCTAssertTrue(about.informativeText.contains("更新方式：检查并下载 DMG"))
    }

    func testPageReferenceUsesURLWhenTitleIsMissing() {
        let url = URL(string: "https://api.lihe.chat/dashboard")!

        XCTAssertEqual(
            ClipboardFormatter.pageReference(title: nil, url: url),
            "https://api.lihe.chat/dashboard"
        )
    }

    func testPageReferenceIncludesTitleAndURL() {
        let url = URL(string: "https://api.lihe.chat/dashboard")!

        XCTAssertEqual(
            ClipboardFormatter.pageReference(title: "控制台", url: url),
            "控制台\nhttps://api.lihe.chat/dashboard"
        )
    }

    func testCurrencyFormatting() {
        XCTAssertEqual(MetricsFormatter.currency(12.345678), "$12.3457")
        XCTAssertEqual(MetricsFormatter.currency(nil), "—")
    }

    func testDisplayCurrencyFormattingUsesGroupingAndTwoDecimals() {
        XCTAssertEqual(MetricsFormatter.displayCurrency(399_481.5740), "$399,481.57")
        XCTAssertEqual(MetricsFormatter.displayCurrency(7.7457), "$7.75")
        XCTAssertEqual(MetricsFormatter.displayCurrency(nil), "—")
    }

    func testIntegerFormatting() {
        XCTAssertEqual(MetricsFormatter.integer(1234.4), "1234")
        XCTAssertEqual(MetricsFormatter.integer(nil), "—")
    }

    func testCompactIntegerFormatting() {
        XCTAssertEqual(MetricsFormatter.compactInteger(999), "999")
        XCTAssertEqual(MetricsFormatter.compactInteger(12_345), "12.3K")
        XCTAssertEqual(MetricsFormatter.compactInteger(18_643_388), "18.6M")
        XCTAssertEqual(MetricsFormatter.compactInteger(nil), "—")
    }

    func testChannelSummaryFormatting() {
        XCTAssertEqual(
            MetricsFormatter.channelSummary(ok: 3, abnormal: 1, unknown: 0),
            "正常 3 / 异常 1"
        )

        XCTAssertEqual(
            MetricsFormatter.channelSummary(ok: 0, abnormal: 0, unknown: 2),
            "正常 0 / 异常 0 / 待确认 2"
        )
    }

    func testCompactChannelStatusFormatting() {
        XCTAssertEqual(MetricsFormatter.compactChannelStatus(ok: 3, abnormal: 0, unknown: 0), "● 正常 3")
        XCTAssertEqual(MetricsFormatter.compactChannelStatus(ok: 3, abnormal: 1, unknown: 0), "● 异常 1")
        XCTAssertEqual(MetricsFormatter.compactChannelStatus(ok: 0, abnormal: 0, unknown: 2), "● 待确认 2")
        XCTAssertEqual(MetricsFormatter.compactChannelStatus(ok: 0, abnormal: 0, unknown: 0), "—")
    }

    func testChannelMonitorOperationalStatusIsRecognizedByMenuScript() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("merged.primary_status"))
        XCTAssertTrue(appSource.contains("'operational'"))
    }

    func testMetricMenuItemsArePresentedAsReadableInformationalRows() {
        XCTAssertTrue(StatusMenuPresentation.metricsItemsAreEnabled)
        XCTAssertTrue(StatusMenuPresentation.refreshControlKeepsMenuOpen)
        XCTAssertEqual(StatusMenuPresentation.refreshControlStyleName, "plainMenuRow")
        XCTAssertEqual(StatusMenuPresentation.metricTextAlpha, 1)
        XCTAssertEqual(StatusMenuPresentation.balanceTextColorName, "systemGreen")
        XCTAssertEqual(StatusMenuPresentation.usageTextColorName, "controlAccentColor")
        XCTAssertEqual(StatusMenuPresentation.channelTextColorName, "systemOrange")
        XCTAssertEqual(StatusMenuPresentation.updatedAtTextColorName, "secondaryLabelColor")
    }

    func testStatusMenuKeepsOnlyEssentialActions() {
        XCTAssertEqual(StatusMenuPresentation.statusMenuActionTitles, ["刷新状态", "打开主窗口", "检查更新", "偏好设置…", "退出"])
        XCTAssertEqual(StatusMenuPresentation.quitActionName, "quitApp")
    }

    func testStatusMenuUsesFormalGroupedSections() {
        XCTAssertEqual(
            StatusMenuPresentation.metricRowTitles,
            ["ToCreate", "API 状态", "今日用量", "请求", "Tokens", "费用", "账户", "余额", "API 密钥", "更新于"]
        )
        XCTAssertFalse(StatusMenuPresentation.showsChannelStatus)
        XCTAssertEqual(StatusMenuPresentation.statusMenuActionTitles, ["刷新状态", "打开主窗口", "检查更新", "偏好设置…", "退出"])
        XCTAssertEqual(StatusMenuPresentation.serviceStatusTitles.ok, "● API 可连通")
        XCTAssertEqual(StatusMenuPresentation.serviceStatusTitles.partial, "● API 待确认")
        XCTAssertEqual(StatusMenuPresentation.serviceStatusTitles.unavailable, "● API 不可连通")
        XCTAssertEqual(StatusMenuPresentation.serviceStatusTitles.offline, "● 未连接")
        XCTAssertEqual(StatusMenuPresentation.labelColumnWidth, 72)
    }

    func testMainWindowIsRetainedAfterCloseForMenuBarReopen() {
        XCTAssertFalse(WindowLifecyclePolicy.releasesMainWindowWhenClosed)
    }

    func testMainWindowEntryRoutesByLoginState() {
        XCTAssertEqual(EntryPageRouting.loginPath, "/login")
        XCTAssertEqual(EntryPageRouting.dashboardPath, "/dashboard")
        XCTAssertEqual(EntryPageRouting.authTokenStorageKey, "auth_token")
    }

    func testMainWindowEntryRoutingScriptUsesLoginAndDashboard() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("entryRoutingJavaScript"))
        XCTAssertTrue(appSource.contains("localStorage.getItem('auth_token')"))
        XCTAssertTrue(appSource.contains("location.replace('/login')"))
        XCTAssertTrue(appSource.contains("location.replace('/dashboard')"))
    }

    func testAppPreferencesDefaultsAreConservative() {
        let preferences = AppPreferences.default

        XCTAssertFalse(preferences.privacyModeEnabled)
        XCTAssertEqual(preferences.refreshInterval, .off)
        XCTAssertFalse(preferences.launchAtLoginEnabled)
        XCTAssertFalse(preferences.autoCheckUpdatesEnabled)
        XCTAssertTrue(preferences.channelAlertEnabled)
        XCTAssertFalse(preferences.balanceAlertEnabled)
        XCTAssertEqual(preferences.balanceAlertThreshold, 100)
        XCTAssertFalse(preferences.dailyCostAlertEnabled)
        XCTAssertEqual(preferences.dailyCostAlertThreshold, 10)
    }

    func testRefreshIntervalOptionsExposeMenuTitlesAndSeconds() {
        XCTAssertEqual(RefreshIntervalOption.off.title, "关闭")
        XCTAssertNil(RefreshIntervalOption.off.seconds)
        XCTAssertEqual(RefreshIntervalOption.oneMinute.title, "每 1 分钟")
        XCTAssertEqual(RefreshIntervalOption.oneMinute.seconds, 60)
        XCTAssertEqual(RefreshIntervalOption.fiveMinutes.seconds, 300)
        XCTAssertEqual(RefreshIntervalOption.fifteenMinutes.seconds, 900)
    }

    func testPreferenceStorePersistsValues() {
        let defaults = UserDefaults(suiteName: "LiheAPITests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)

        var preferences = AppPreferences.default
        preferences.privacyModeEnabled = true
        preferences.refreshInterval = .fiveMinutes
        preferences.launchAtLoginEnabled = true
        preferences.autoCheckUpdatesEnabled = true
        preferences.balanceAlertEnabled = true
        preferences.balanceAlertThreshold = 42.5
        preferences.dailyCostAlertEnabled = true
        preferences.dailyCostAlertThreshold = 3.25

        store.save(preferences)

        XCTAssertEqual(store.load(), preferences)
    }

    func testMetricDisplayRespectsPrivacyMode() {
        let publicDisplay = StatusMetricDisplay(
            balance: 399_481.574,
            todayCost: 7.7457,
            apiKeyCount: 6,
            preferences: .default
        )

        XCTAssertEqual(publicDisplay.balanceText, "$399,481.57")
        XCTAssertEqual(publicDisplay.todayCostText, "$7.75")
        XCTAssertEqual(publicDisplay.apiKeyCountText, "6 个")

        var privatePreferences = AppPreferences.default
        privatePreferences.privacyModeEnabled = true
        let privateDisplay = StatusMetricDisplay(
            balance: 399_481.574,
            todayCost: 7.7457,
            apiKeyCount: 6,
            preferences: privatePreferences
        )

        XCTAssertEqual(privateDisplay.balanceText, "已隐藏")
        XCTAssertEqual(privateDisplay.todayCostText, "已隐藏")
        XCTAssertEqual(privateDisplay.apiKeyCountText, "已隐藏")
    }

    func testWidgetSnapshotCodableRoundTrip() throws {
        let snapshot = WidgetSnapshot(
            apiStatus: .reachable,
            balance: 399_478.22,
            todayRequests: 36,
            todayTokens: 338_100,
            todayCost: 0.12,
            apiKeyCount: 6,
            updatedAt: Date(timeIntervalSince1970: 1_782_300_000),
            privacyModeEnabled: false
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testWidgetSnapshotDisplayHonorsPrivacyMode() {
        let publicSnapshot = WidgetSnapshot(
            apiStatus: .reachable,
            balance: 399_478.22,
            todayRequests: 36,
            todayTokens: 338_100,
            todayCost: 0.12,
            apiKeyCount: 6,
            updatedAt: Date(timeIntervalSince1970: 1_782_300_000),
            privacyModeEnabled: false
        )

        let privateSnapshot = WidgetSnapshot(
            apiStatus: .reachable,
            balance: 399_478.22,
            todayRequests: 36,
            todayTokens: 338_100,
            todayCost: 0.12,
            apiKeyCount: 6,
            updatedAt: Date(timeIntervalSince1970: 1_782_300_000),
            privacyModeEnabled: true
        )

        XCTAssertEqual(WidgetSnapshotDisplay(snapshot: publicSnapshot).balanceText, "$399,478.22")
        XCTAssertEqual(WidgetSnapshotDisplay(snapshot: publicSnapshot).todayCostText, "$0.12")
        XCTAssertEqual(WidgetSnapshotDisplay(snapshot: publicSnapshot).apiKeyCountText, "6 个")
        XCTAssertEqual(WidgetSnapshotDisplay(snapshot: publicSnapshot).tokensText, "338.1K")

        XCTAssertEqual(WidgetSnapshotDisplay(snapshot: privateSnapshot).balanceText, "已隐藏")
        XCTAssertEqual(WidgetSnapshotDisplay(snapshot: privateSnapshot).todayCostText, "已隐藏")
        XCTAssertEqual(WidgetSnapshotDisplay(snapshot: privateSnapshot).apiKeyCountText, "已隐藏")
        XCTAssertEqual(WidgetSnapshotDisplay(snapshot: privateSnapshot).tokensText, "338.1K")
    }

    func testWidgetSnapshotDisplayDetectsStaleData() {
        let oldSnapshot = WidgetSnapshot(
            apiStatus: .reachable,
            balance: 1,
            todayRequests: 2,
            todayTokens: 3,
            todayCost: 4,
            apiKeyCount: 5,
            updatedAt: Date(timeIntervalSince1970: 100),
            privacyModeEnabled: false
        )

        XCTAssertTrue(
            WidgetSnapshotDisplay(
                snapshot: oldSnapshot,
                now: Date(timeIntervalSince1970: 100 + 601)
            ).isStale
        )
    }

    func testWidgetSnapshotStoreSavesAndLoadsSnapshot() throws {
        let defaults = UserDefaults(suiteName: "WidgetSnapshotStoreTests-\(UUID().uuidString)")!
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetSnapshotStoreTests-\(UUID().uuidString).json")
        let store = WidgetSnapshotStore(defaults: defaults, fileURL: fileURL)
        let snapshot = WidgetSnapshot(
            apiStatus: .reachable,
            balance: 99,
            todayRequests: 10,
            todayTokens: 20,
            todayCost: 0.3,
            apiKeyCount: 4,
            updatedAt: Date(timeIntervalSince1970: 1_782_300_000),
            privacyModeEnabled: false
        )

        try store.save(snapshot)

        XCTAssertEqual(try store.load(), snapshot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testWidgetSnapshotStoreFallsBackToDefaultsWhenFileIsMissing() throws {
        let defaults = UserDefaults(suiteName: "WidgetSnapshotStoreTests-\(UUID().uuidString)")!
        let missingFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MissingWidgetSnapshot-\(UUID().uuidString).json")
        let store = WidgetSnapshotStore(defaults: defaults, fileURL: missingFileURL)
        let snapshot = WidgetSnapshot(
            apiStatus: .reachable,
            balance: 88,
            todayRequests: 9,
            todayTokens: 18,
            todayCost: 0.2,
            apiKeyCount: 3,
            updatedAt: Date(timeIntervalSince1970: 1_782_300_001),
            privacyModeEnabled: false
        )
        let data = try JSONEncoder().encode(snapshot)

        defaults.set(data, forKey: WidgetSnapshotStore.snapshotKey)

        XCTAssertEqual(try store.load(), snapshot)
    }

    func testWidgetSnapshotStoreReturnsNilWhenEmpty() throws {
        let defaults = UserDefaults(suiteName: "WidgetSnapshotStoreTests-\(UUID().uuidString)")!
        let missingFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MissingWidgetSnapshot-\(UUID().uuidString).json")
        let store = WidgetSnapshotStore(defaults: defaults, fileURL: missingFileURL)

        XCTAssertNil(try store.load())
    }

    func testMainAppWritesWidgetSnapshotAfterMetricsRefresh() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("private let widgetSnapshotStore = WidgetSnapshotStore()"))
        XCTAssertTrue(appSource.contains("writeWidgetSnapshot("))
        XCTAssertTrue(appSource.contains("WidgetSnapshot("))
        XCTAssertTrue(appSource.contains("privacyModeEnabled: preferences.privacyModeEnabled"))
        XCTAssertTrue(appSource.contains("WidgetCenter.shared.reloadTimelines(ofKind: \"ToCreateWidget\")"))
    }

    func testAppRegistersToCreateURLSchemeForWidgetOpen() throws {
        let plist = try String(contentsOfFile: Self.projectFile("Resources/Info.plist"))
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(plist.contains("<string>tocreate</string>"))
        XCTAssertTrue(appSource.contains("func application(_ application: NSApplication, open urls: [URL])"))
        XCTAssertTrue(appSource.contains("showWindow()"))
    }

    func testWidgetSourceFilesDefineWidgetKitExtension() throws {
        let widget = try String(contentsOfFile: Self.projectFile("ToCreateWidget/ToCreateWidget.swift"))
        let view = try String(contentsOfFile: Self.projectFile("ToCreateWidget/ToCreateWidgetView.swift"))
        let bundle = try String(contentsOfFile: Self.projectFile("ToCreateWidget/ToCreateWidgetBundle.swift"))

        XCTAssertTrue(widget.contains("import WidgetKit"))
        XCTAssertTrue(widget.contains("StaticConfiguration"))
        XCTAssertTrue(widget.contains("WidgetSnapshotStore"))
        XCTAssertTrue(widget.contains("TimelineProvider"))
        XCTAssertTrue(view.contains("@Environment(\\.widgetFamily)"))
        XCTAssertTrue(view.contains("widgetURL(URL(string: \"tocreate://open\"))"))
        XCTAssertTrue(bundle.contains("@main"))
    }

    func testAppAndWidgetEntitlementsUseSameAppGroup() throws {
        let appEntitlements = try String(contentsOfFile: Self.projectFile("Resources/ToCreate.entitlements"))
        let widgetEntitlements = try String(contentsOfFile: Self.projectFile("ToCreateWidget/ToCreateWidget.entitlements"))

        XCTAssertTrue(appEntitlements.contains("group.chat.lihe.api.mac"))
        XCTAssertTrue(widgetEntitlements.contains("group.chat.lihe.api.mac"))
        XCTAssertTrue(appEntitlements.contains("com.apple.security.application-groups"))
        XCTAssertTrue(widgetEntitlements.contains("com.apple.security.application-groups"))
        XCTAssertTrue(appEntitlements.contains("com.apple.security.app-sandbox"))
        XCTAssertTrue(widgetEntitlements.contains("com.apple.security.app-sandbox"))
        XCTAssertTrue(appEntitlements.contains("com.apple.security.network.client"))
    }

    func testXcodeProjectDefinesAppAndWidgetTargets() throws {
        let project = try String(contentsOfFile: Self.projectFile("ToCreate.xcodeproj/project.pbxproj"))

        XCTAssertTrue(project.contains("ToCreate"))
        XCTAssertTrue(project.contains("ToCreateWidgetExtension"))
        XCTAssertTrue(project.contains("com.apple.product-type.application"))
        XCTAssertTrue(project.contains("com.apple.product-type.app-extension"))
        XCTAssertTrue(project.contains("ToCreateWidget.appex"))
        XCTAssertTrue(project.contains("CODE_SIGN_ENTITLEMENTS = Resources/ToCreate.entitlements"))
        XCTAssertTrue(project.contains("CODE_SIGN_ENTITLEMENTS = ToCreateWidget/ToCreateWidget.entitlements"))
    }

    func testMainAppInfoPlistUsesXcodeExecutableName() throws {
        let plist = try String(contentsOfFile: Self.projectFile("Resources/Info.plist"))

        XCTAssertTrue(plist.contains("<key>CFBundleExecutable</key>"))
        XCTAssertTrue(plist.contains("<string>$(EXECUTABLE_NAME)</string>"))
        XCTAssertTrue(plist.contains("<key>CFBundleIconFile</key>"))
        XCTAssertTrue(plist.contains("<key>CFBundleIconName</key>"))
        XCTAssertTrue(plist.contains("<string>AppIcon</string>"))
    }

    func testWidgetBuildUsesMacOS14MinimumForDesktopWidgets() throws {
        let appPlist = try String(contentsOfFile: Self.projectFile("Resources/Info.plist"))
        let project = try String(contentsOfFile: Self.projectFile("ToCreate.xcodeproj/project.pbxproj"))

        XCTAssertTrue(appPlist.contains("<key>LSMinimumSystemVersion</key>"))
        XCTAssertTrue(appPlist.contains("<string>14.0</string>"))
        XCTAssertTrue(project.contains("MACOSX_DEPLOYMENT_TARGET = 14.0"))
        XCTAssertFalse(project.contains("MACOSX_DEPLOYMENT_TARGET = 13.0"))
    }

    func testMetricPayloadParserAcceptsStringNumbers() {
        XCTAssertEqual(MetricPayloadParser.doubleValue("399478.22"), 399_478.22)
        XCTAssertEqual(MetricPayloadParser.doubleValue(399_478.22), 399_478.22)
        XCTAssertNil(MetricPayloadParser.doubleValue("not-a-number"))
    }

    func testMetricsScriptUsesFallbackBalanceFields() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("firstNumber("))
        XCTAssertTrue(appSource.contains("me && me.user && me.user.balance"))
        XCTAssertTrue(appSource.contains("stats && stats.balance"))
        XCTAssertTrue(appSource.contains("stats && stats.remaining_balance"))
    }

    func testMetricsRefreshRetriesAfterPageLoadAndMissingBalance() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("scheduleMetricsRefreshAfterPageLoad"))
        XCTAssertTrue(appSource.contains("scheduleBalanceRetryIfNeeded"))
        XCTAssertTrue(appSource.contains("balanceRetryAttemptsRemaining"))
        XCTAssertTrue(appSource.contains("DispatchQueue.main.asyncAfter"))
    }

    func testMetricsKeepLastSuccessfulBalanceWhenRefreshPayloadOmitsIt() throws {
        XCTAssertEqual(MetricValueCache.replacingMissing(current: nil, cached: 399_478.22), 399_478.22)
        XCTAssertEqual(MetricValueCache.replacingMissing(current: 12.5, cached: 399_478.22), 12.5)

        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))
        XCTAssertTrue(appSource.contains("lastSuccessfulBalance"))
        XCTAssertTrue(appSource.contains("MetricValueCache.replacingMissing(current: balance, cached: lastSuccessfulBalance)"))
        XCTAssertFalse(appSource.contains("setBalanceMenuTitle(metricTitle(\"余额\", \"刷新中…\"))"))
    }

    func testPreferencesWindowIsARealSettingsWindow() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("preferencesWindow"))
        XCTAssertTrue(appSource.contains("隐私模式"))
        XCTAssertTrue(appSource.contains("自动刷新"))
        XCTAssertFalse(appSource.contains("后续可以在这里加入隐私模式"))
    }

    func testPreferencesWindowUsesCompactAlignedLayout() throws {
        XCTAssertEqual(PreferencesWindowPresentation.width, 460)
        XCTAssertEqual(PreferencesWindowPresentation.height, 364)
        XCTAssertEqual(PreferencesWindowPresentation.labelColumnWidth, 108)
        XCTAssertEqual(PreferencesWindowPresentation.controlColumnWidth, 190)
        XCTAssertTrue(PreferencesWindowPresentation.layoutUsesAlignedGrid)

        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))
        XCTAssertTrue(appSource.contains("PreferencesWindowPresentation.width"))
        XCTAssertTrue(appSource.contains("makePreferenceRow"))
        XCTAssertTrue(appSource.contains("buttonRow.topAnchor.constraint"))
    }

    func testStatusBarStateReflectsServiceHealth() {
        XCTAssertEqual(StatusBarState.from(ok: 2, abnormal: 0, unknown: 0), .healthy)
        XCTAssertEqual(StatusBarState.from(ok: 1, abnormal: 0, unknown: 1), .healthy)
        XCTAssertEqual(StatusBarState.from(ok: 1, abnormal: 1, unknown: 0), .healthy)
        XCTAssertEqual(StatusBarState.from(ok: 0, abnormal: 1, unknown: 0), .partial)
        XCTAssertEqual(StatusBarState.from(ok: 0, abnormal: 0, unknown: 0), .offline)
        XCTAssertEqual(StatusBarState.refreshing, .refreshing)
    }

    func testStatusMenuRemovesChannelRowFromAccountSection() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertFalse(appSource.contains("menu.addItem(channelMenuItem)"))
        XCTAssertFalse(appSource.contains("setChannelMenuTitle(metricTitle(\"渠道\""))
    }

    func testStatusBarStateDefinesIconColorAndAccessibilityLabel() {
        XCTAssertEqual(StatusBarState.healthy.symbolName, "checkmark.circle.fill")
        XCTAssertEqual(StatusBarState.healthy.colorName, "systemGreen")
        XCTAssertEqual(StatusBarState.partial.symbolName, "exclamationmark.circle.fill")
        XCTAssertEqual(StatusBarState.partial.colorName, "systemOrange")
        XCTAssertEqual(StatusBarState.unavailable.symbolName, "xmark.circle.fill")
        XCTAssertEqual(StatusBarState.unavailable.colorName, "systemRed")
        XCTAssertEqual(StatusBarState.offline.symbolName, "circle.dashed")
        XCTAssertEqual(StatusBarState.offline.colorName, "secondaryLabelColor")
        XCTAssertEqual(StatusBarState.refreshing.accessibilityLabel, "ToCreate 正在刷新")
    }

    func testLaunchAtLoginUsesNativeServiceManagementAndPreferencesUI() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("import ServiceManagement"))
        XCTAssertTrue(appSource.contains("SMAppService.mainApp"))
        XCTAssertTrue(appSource.contains("configureLaunchAtLogin"))
        XCTAssertTrue(appSource.contains("开机启动"))
        XCTAssertTrue(appSource.contains("登录后自动启动"))
    }

    func testMainMenuIncludesStandardEditingCommandsForWebTextFields() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("let editMenu = NSMenu(title: \"编辑\")"))
        XCTAssertTrue(appSource.contains("#selector(NSText.cut(_:))"))
        XCTAssertTrue(appSource.contains("#selector(NSText.copy(_:))"))
        XCTAssertTrue(appSource.contains("#selector(NSText.paste(_:))"))
        XCTAssertTrue(appSource.contains("#selector(NSText.selectAll(_:))"))
        XCTAssertTrue(appSource.contains("keyEquivalent: \"v\""))
    }

    func testGitHubReleaseParserFindsToCreateDmgAsset() throws {
        let json = """
        {
          "tag_name": "v0.1.1",
          "html_url": "https://github.com/floating0516/ToCreate-api/releases/tag/v0.1.1",
          "body": "修复问题并提升稳定性。",
          "assets": [
            {
              "name": "ToCreate.dmg",
              "browser_download_url": "https://github.com/floating0516/ToCreate-api/releases/download/v0.1.1/ToCreate.dmg"
            }
          ]
        }
        """

        let update = try GitHubReleaseParser.parseLatestRelease(
            Data(json.utf8),
            assetName: AppBranding.dmgName
        )

        XCTAssertEqual(update.version, "0.1.1")
        XCTAssertEqual(update.releaseNotes, "修复问题并提升稳定性。")
        XCTAssertEqual(update.releasePageURL.absoluteString, "https://github.com/floating0516/ToCreate-api/releases/tag/v0.1.1")
        XCTAssertEqual(update.downloadURL.absoluteString, "https://github.com/floating0516/ToCreate-api/releases/download/v0.1.1/ToCreate.dmg")
    }

    func testUpdateDownloadPlannerUsesVersionedDmgInDownloads() {
        let downloads = URL(fileURLWithPath: "/Users/test/Downloads", isDirectory: true)
        let destination = UpdateDownloadPlanner.destinationURL(
            for: AppUpdateInfo(
                version: "0.1.2",
                downloadURL: URL(string: "https://example.com/ToCreate.dmg")!,
                releasePageURL: URL(string: "https://example.com/release")!,
                releaseNotes: ""
            ),
            downloadsDirectory: downloads
        )

        XCTAssertEqual(destination.path, "/Users/test/Downloads/ToCreate-v0.1.2.dmg")
    }

    func testUpdateInstallerScriptMountsDmgCopiesAppAndRelaunches() {
        let script = UpdateInstallerScript.makeScript(
            dmgPath: "/Users/test/Downloads/ToCreate-v0.1.2.dmg",
            appName: AppBranding.bundleAppName,
            installPath: "/Applications/ToCreate.app"
        )

        XCTAssertTrue(script.contains("hdiutil attach"))
        XCTAssertTrue(script.contains("/Users/test/Downloads/ToCreate-v0.1.2.dmg"))
        XCTAssertTrue(script.contains("ditto"))
        XCTAssertTrue(script.contains("/Applications/ToCreate.app"))
        XCTAssertTrue(script.contains("open \"$INSTALL_PATH\""))
        XCTAssertTrue(script.contains("ToCreate.app"))
    }

    func testVersionComparatorHandlesSemanticVersions() {
        XCTAssertTrue(VersionComparator.isRemoteVersion("0.1.1", newerThan: "0.1.0"))
        XCTAssertTrue(VersionComparator.isRemoteVersion("0.1.10", newerThan: "0.1.2"))
        XCTAssertFalse(VersionComparator.isRemoteVersion("0.1.0", newerThan: "0.1.0"))
        XCTAssertFalse(VersionComparator.isRemoteVersion("0.1.0", newerThan: "0.1.1"))
        XCTAssertTrue(VersionComparator.isRemoteVersion("v1.0.0", newerThan: "0.9.9"))
    }

    func testUpdateUIIsConnectedToGitHubReleases() throws {
        let appSource = try String(contentsOfFile: Self.projectFile("Sources/LiheAPI/LiheAPIApp.swift"))

        XCTAssertTrue(appSource.contains("checkForUpdatesFromMenu"))
        XCTAssertTrue(appSource.contains("showAboutWindow"))
        XCTAssertTrue(appSource.contains("api.github.com/repos/floating0516/ToCreate-api/releases/latest"))
        XCTAssertTrue(appSource.contains("downloadAndOpenUpdate"))
        XCTAssertTrue(appSource.contains("UpdateDownloadPlanner.destinationURL"))
        XCTAssertTrue(appSource.contains("installAndRelaunchUpdate"))
        XCTAssertTrue(appSource.contains("UpdateInstallerScript.makeScript"))
        XCTAssertTrue(appSource.contains("启动时自动检查更新"))
        XCTAssertTrue(StatusMenuPresentation.statusMenuActionTitles.contains("检查更新"))
    }

    func testReleaseScriptAutomatesSafeGitHubReleaseFlow() throws {
        let scriptPath = Self.projectFile("scripts/release.sh")
        let script = try String(contentsOfFile: scriptPath)

        XCTAssertTrue(script.contains("Usage: ./scripts/release.sh <version> <release-notes>"))
        XCTAssertTrue(script.contains("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
        XCTAssertTrue(script.contains("git status --porcelain"))
        XCTAssertTrue(script.contains("gh auth status"))
        XCTAssertTrue(script.contains("git rev-parse \"v$VERSION\""))
        XCTAssertTrue(script.contains("CFBundleShortVersionString"))
        XCTAssertTrue(script.contains("CFBundleVersion"))
        XCTAssertTrue(script.contains("swift test"))
        XCTAssertTrue(script.contains("./scripts/package_app.sh"))
        XCTAssertTrue(script.contains("dist/ToCreate.dmg"))
        XCTAssertTrue(script.contains("git tag \"v$VERSION\""))
        XCTAssertTrue(script.contains("gh release create \"v$VERSION\""))
    }

    func testPackageScriptBuildsXcodeAppAndSignsWidgetBundle() throws {
        let script = try String(contentsOfFile: Self.projectFile("scripts/package_app.sh"))

        XCTAssertTrue(script.contains("xcodebuild"))
        XCTAssertTrue(script.contains("-project \"$ROOT/ToCreate.xcodeproj\""))
        XCTAssertTrue(script.contains("-scheme ToCreate"))
        XCTAssertTrue(script.contains("DEVELOPMENT_TEAM=\"${DEVELOPMENT_TEAM:-}\""))
        XCTAssertTrue(script.contains("-allowProvisioningUpdates"))
        XCTAssertTrue(script.contains("CODE_SIGN_STYLE=Automatic"))
        XCTAssertTrue(script.contains("CODE_SIGNING_ALLOWED=NO"))
        XCTAssertTrue(script.contains("ditto \"$DERIVED_DATA/Build/Products/Release/ToCreate.app\" \"$APP\""))
        XCTAssertTrue(script.contains("Keeping Xcode-managed development signature and provisioning profiles."))
        XCTAssertTrue(script.contains("ToCreateWidget.entitlements"))
        XCTAssertTrue(script.contains("Resources/ToCreate.entitlements"))
        XCTAssertTrue(script.contains("codesign --verify --deep --strict \"$APP\""))
    }
}
