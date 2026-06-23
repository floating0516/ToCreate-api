import AppKit
import ServiceManagement
import UserNotifications
import WebKit

@main
final class LiheAPIApp: NSObject, NSApplicationDelegate, NSMenuDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, @preconcurrency UNUserNotificationCenterDelegate {
    private static let delegate = LiheAPIApp()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }

    private let homeURL = URL(string: "https://api.lihe.chat")!

    private var window: NSWindow!
    private var webView: WKWebView!
    private var addressLabel: NSTextField!
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var reloadButton: NSButton!
    private var statusItem: NSStatusItem!
    private var serviceStatusMenuItem: NSMenuItem!
    private var balanceMenuItem: NSMenuItem!
    private var requestsMenuItem: NSMenuItem!
    private var costMenuItem: NSMenuItem!
    private var tokensMenuItem: NSMenuItem!
    private var channelMenuItem: NSMenuItem!
    private var apiKeysMenuItem: NSMenuItem!
    private var updatedAtMenuItem: NSMenuItem!
    private let preferencesStore = PreferencesStore()
    private lazy var preferences = preferencesStore.load()
    private var metricsRefreshTimer: Timer?
    private var preferencesWindow: NSWindow?
    private var privacyCheckbox: NSButton?
    private var refreshIntervalPopup: NSPopUpButton?
    private var launchAtLoginCheckbox: NSButton?
    private var autoCheckUpdatesCheckbox: NSButton?
    private var channelAlertCheckbox: NSButton?
    private var balanceAlertCheckbox: NSButton?
    private var balanceThresholdField: NSTextField?
    private var dailyCostAlertCheckbox: NSButton?
    private var dailyCostThresholdField: NSTextField?
    private var channelAlertIsActive = false
    private var balanceAlertIsActive = false
    private var dailyCostAlertIsActive = false
    private let updateFeedURL = URL(string: "https://api.github.com/repos/floating0516/ToCreate-api/releases/latest")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        buildStatusItem()
        configureApplicationIcon()
        configureNotifications()
        buildWindow()
        loadEntryPage()
        configureMetricsRefreshTimer()
        configureLaunchAtLogin(preferences.launchAtLoginEnabled, showErrors: false)
        scheduleStartupUpdateCheckIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func buildWindow() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.entryRoutingJavaScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        configuration.userContentController.add(self, name: "liheMetrics")

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        webView.translatesAutoresizingMaskIntoConstraints = false

        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = makeToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(toolbar)
        rootView.addSubview(webView)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: rootView.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),

            webView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = AppBranding.displayName
        window.isReleasedWhenClosed = WindowLifecyclePolicy.releasesMainWindowWhenClosed
        window.center()
        window.minSize = NSSize(width: 900, height: 640)
        window.contentView = rootView
        window.makeKeyAndOrderFront(nil)
    }

    private func makeToolbar() -> NSView {
        let toolbar = NSVisualEffectView()
        toolbar.material = .headerView
        toolbar.blendingMode = .withinWindow

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        backButton = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "后退")!, target: self, action: #selector(goBack))
        forwardButton = NSButton(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "前进")!, target: self, action: #selector(goForward))
        reloadButton = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新")!, target: self, action: #selector(reload))

        [backButton, forwardButton, reloadButton].forEach { button in
            button.bezelStyle = .texturedRounded
            button.isBordered = false
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 28).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            stack.addArrangedSubview(button)
        }

        addressLabel = NSTextField(labelWithString: homeURL.absoluteString)
        addressLabel.lineBreakMode = .byTruncatingMiddle
        addressLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        addressLabel.textColor = .secondaryLabelColor
        addressLabel.backgroundColor = .controlBackgroundColor
        addressLabel.isBezeled = true
        addressLabel.bezelStyle = .roundedBezel
        addressLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(addressLabel)

        let openExternalButton = NSButton(image: NSImage(systemSymbolName: "safari", accessibilityDescription: "默认浏览器打开")!, target: self, action: #selector(openCurrentURLInDefaultBrowser))
        openExternalButton.bezelStyle = .texturedRounded
        openExternalButton.isBordered = false
        stack.addArrangedSubview(openExternalButton)

        let copyButton = NSButton(image: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制页面信息")!, target: self, action: #selector(copyPageReference))
        copyButton.bezelStyle = .texturedRounded
        copyButton.isBordered = false
        stack.addArrangedSubview(copyButton)

        toolbar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: toolbar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor),
        ])

        updateToolbarState()
        return toolbar
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.imagePosition = .imageOnly
        updateStatusBarIcon(.offline)

        let menu = NSMenu()
        menu.delegate = self
        serviceStatusMenuItem = informationalMenuItem("● 正在读取", color: StatusMenuPresentation.warningTextColor)
        balanceMenuItem = informationalMenuItem(metricTitle("余额", "加载中…"), color: StatusMenuPresentation.balanceTextColor)
        requestsMenuItem = informationalMenuItem(metricTitle("请求", "加载中…"), color: StatusMenuPresentation.usageTextColor)
        costMenuItem = informationalMenuItem(metricTitle("费用", "加载中…"), color: StatusMenuPresentation.costTextColor)
        tokensMenuItem = informationalMenuItem(metricTitle("Tokens", "加载中…"), color: StatusMenuPresentation.tokensTextColor)
        channelMenuItem = informationalMenuItem(metricTitle("渠道", "加载中…"), color: StatusMenuPresentation.channelTextColor)
        apiKeysMenuItem = informationalMenuItem(metricTitle("API 密钥", "加载中…"), color: StatusMenuPresentation.apiKeysTextColor)
        updatedAtMenuItem = informationalMenuItem(metricTitle("更新于", "—"), color: StatusMenuPresentation.updatedAtTextColor)

        menu.addItem(headerMenuItem(AppBranding.displayName))
        menu.addItem(serviceStatusMenuItem)
        menu.addItem(.separator())
        menu.addItem(sectionHeaderMenuItem("今日用量"))
        menu.addItem(requestsMenuItem)
        menu.addItem(tokensMenuItem)
        menu.addItem(costMenuItem)
        menu.addItem(.separator())
        menu.addItem(sectionHeaderMenuItem("账户"))
        menu.addItem(balanceMenuItem)
        menu.addItem(apiKeysMenuItem)
        menu.addItem(channelMenuItem)
        menu.addItem(.separator())
        menu.addItem(updatedAtMenuItem)
        menu.addItem(makeRefreshMetricsMenuItem())
        menu.addItem(.separator())
        menu.addItem(withTitle: StatusMenuPresentation.statusMenuActionTitles[1], action: #selector(showWindow), keyEquivalent: "")
        menu.addItem(withTitle: StatusMenuPresentation.statusMenuActionTitles[2], action: #selector(checkForUpdatesFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: StatusMenuPresentation.statusMenuActionTitles[3], action: #selector(openPreferences), keyEquivalent: ",")
        let quitItem = NSMenuItem(title: StatusMenuPresentation.statusMenuActionTitles[4], action: #selector(quitApp), keyEquivalent: "q")
        quitItem.image = nil
        quitItem.onStateImage = nil
        quitItem.offStateImage = nil
        quitItem.mixedStateImage = nil
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func headerMenuItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: StatusMenuPresentation.headerTextColor,
                .font: boldMenuFont(size: NSFont.systemFontSize)
            ]
        )
        return item
    }

    private func sectionHeaderMenuItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: StatusMenuPresentation.headerTextColor,
                .font: boldMenuFont(size: NSFont.smallSystemFontSize)
            ]
        )
        return item
    }

    private func boldMenuFont(size: CGFloat) -> NSFont {
        NSFontManager.shared.convert(NSFont.menuFont(ofSize: size), toHaveTrait: .boldFontMask)
    }

    private func metricTitle(_ label: String, _ value: String) -> String {
        let paddedLabel = label.padding(toLength: 10, withPad: " ", startingAt: 0)
        return "\(paddedLabel)\(value)"
    }

    private func makeRefreshMetricsMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 26))

        let button = NSButton(title: StatusMenuPresentation.statusMenuActionTitles[0], target: self, action: #selector(refreshMenuMetrics))
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.controlSize = .regular
        button.alignment = .left
        button.setButtonType(.momentaryChange)
        button.attributedTitle = NSAttributedString(
            string: StatusMenuPresentation.statusMenuActionTitles[0],
            attributes: [
                .foregroundColor: StatusMenuPresentation.primaryTextColor,
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
        )
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 22)
        ])

        item.view = container
        return item
    }

    private func configureApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else {
            return
        }

        NSApp.applicationIconImage = icon
    }

    private func informationalMenuItem(_ title: String, color: NSColor) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = StatusMenuPresentation.metricsItemsAreEnabled
        setInformationalMenuItem(item, title: title, color: color)
        return item
    }

    private func setInformationalMenuItem(_ item: NSMenuItem, title: String, color: NSColor) {
        item.title = title
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.menuFont(ofSize: NSFont.systemFontSize)
            ]
        )
    }

    private func setBalanceMenuTitle(_ title: String) {
        setInformationalMenuItem(balanceMenuItem, title: title, color: StatusMenuPresentation.balanceTextColor)
    }

    private func setServiceStatusMenuTitle(_ title: String, ok: Int = 0, abnormal: Int = 0, unknown: Int = 1) {
        setInformationalMenuItem(
            serviceStatusMenuItem,
            title: title,
            color: StatusMenuPresentation.channelTextColor(ok: ok, abnormal: abnormal, unknown: unknown)
        )
        updateStatusBarIcon(.from(ok: ok, abnormal: abnormal, unknown: unknown))
    }

    private func setRefreshingStatusMenuTitle(_ title: String) {
        setInformationalMenuItem(
            serviceStatusMenuItem,
            title: title,
            color: StatusMenuPresentation.usageTextColor
        )
        updateStatusBarIcon(.refreshing)
    }

    private func updateStatusBarIcon(_ state: StatusBarState) {
        guard let button = statusItem?.button else {
            return
        }

        let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.accessibilityLabel)
        image?.isTemplate = false
        button.image = image
        button.contentTintColor = state.color
        button.toolTip = state.accessibilityLabel
    }

    private func setRequestsMenuTitle(_ title: String) {
        setInformationalMenuItem(requestsMenuItem, title: title, color: StatusMenuPresentation.usageTextColor)
    }

    private func setCostMenuTitle(_ title: String) {
        setInformationalMenuItem(costMenuItem, title: title, color: StatusMenuPresentation.costTextColor)
    }

    private func setTokensMenuTitle(_ title: String) {
        setInformationalMenuItem(tokensMenuItem, title: title, color: StatusMenuPresentation.tokensTextColor)
    }

    private func setChannelMenuTitle(_ title: String, ok: Int = 0, abnormal: Int = 0, unknown: Int = 1) {
        setInformationalMenuItem(
            channelMenuItem,
            title: title,
            color: StatusMenuPresentation.channelTextColor(ok: ok, abnormal: abnormal, unknown: unknown)
        )
    }

    private func setAPIKeysMenuTitle(_ title: String) {
        setInformationalMenuItem(apiKeysMenuItem, title: title, color: StatusMenuPresentation.apiKeysTextColor)
    }

    private func setUpdatedAtMenuTitle(_ title: String) {
        setInformationalMenuItem(updatedAtMenuItem, title: title, color: StatusMenuPresentation.updatedAtTextColor)
    }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("ToCreate notification authorization failed: %@", error.localizedDescription)
            }
            NSLog("ToCreate notification authorization granted: %@", granted.description)
        }
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = makePreferencesWindow()
        }

        syncPreferencesControls()
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdatesFromMenu() {
        checkForUpdates(silentWhenCurrent: false)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "检查更新…", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 \(AppBranding.displayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let browserItem = NSMenuItem()
        let browserMenu = NSMenu(title: "浏览")
        browserMenu.addItem(withTitle: "后退", action: #selector(goBack), keyEquivalent: "[")
        browserMenu.addItem(withTitle: "前进", action: #selector(goForward), keyEquivalent: "]")
        browserMenu.addItem(.separator())
        browserMenu.addItem(withTitle: "刷新", action: #selector(reload), keyEquivalent: "r")
        browserMenu.addItem(withTitle: "回到首页", action: #selector(loadHome), keyEquivalent: "h")
        browserMenu.addItem(.separator())
        browserMenu.addItem(withTitle: "渠道状态", action: #selector(openChannelStatus), keyEquivalent: "1")
        browserMenu.addItem(withTitle: "余额 / 控制台", action: #selector(openDashboard), keyEquivalent: "2")
        browserMenu.addItem(withTitle: "使用记录", action: #selector(openUsageRecords), keyEquivalent: "3")
        browserMenu.addItem(.separator())
        browserMenu.addItem(withTitle: "在默认浏览器中打开", action: #selector(openCurrentURLInDefaultBrowser), keyEquivalent: "O")
        browserMenu.addItem(withTitle: "复制当前页面信息", action: #selector(copyPageReference), keyEquivalent: "l")
        browserItem.submenu = browserMenu
        mainMenu.addItem(browserItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func goBack() {
        webView.goBack()
    }

    @objc private func goForward() {
        webView.goForward()
    }

    @objc private func reload() {
        webView.reload()
    }

    @objc private func loadHome() {
        loadEntryPage()
    }

    private func loadEntryPage() {
        webView.load(URLRequest(url: homeURL))
    }

    @objc private func openChannelStatus() {
        loadAppPath("/monitor")
    }

    @objc private func openDashboard() {
        loadAppPath("/dashboard")
    }

    @objc private func openUsageRecords() {
        loadAppPath("/usage")
    }

    private func loadAppPath(_ path: String) {
        showWindow()
        guard let url = URL(string: path, relativeTo: homeURL)?.absoluteURL else {
            return
        }
        webView.load(URLRequest(url: url))
    }

    @objc private func openCurrentURLInDefaultBrowser() {
        NSWorkspace.shared.open(webView.url ?? homeURL)
    }

    @objc private func refreshMenuMetrics() {
        refreshMetricsForStatusMenu()
    }

    @objc private func showWindow() {
        if window == nil {
            buildWindow()
            loadEntryPage()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func copyPageReference() {
        let url = webView.url ?? homeURL
        let text = ClipboardFormatter.pageReference(title: webView.title, url: url)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        sendNotification(title: "已复制页面信息", body: url.absoluteString)
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tocreate-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("ToCreate notification failed: %@", error.localizedDescription)
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMetricsForStatusMenu()
    }

    private func refreshMetricsForStatusMenu() {
        guard webView != nil else {
            return
        }

        setRefreshingStatusMenuTitle("正在刷新…")
        setBalanceMenuTitle(metricTitle("余额", "刷新中…"))
        setRequestsMenuTitle(metricTitle("请求", "刷新中…"))
        setCostMenuTitle(metricTitle("费用", "刷新中…"))
        setTokensMenuTitle(metricTitle("Tokens", "刷新中…"))
        setChannelMenuTitle(metricTitle("渠道", "刷新中…"))
        setAPIKeysMenuTitle(metricTitle("API 密钥", "刷新中…"))

        webView.evaluateJavaScript(Self.metricsJavaScript) { [weak self] _, error in
            guard let self, let error else {
                return
            }
            DispatchQueue.main.async {
                self.setBalanceMenuTitle("余额：读取失败")
                self.setServiceStatusMenuTitle("● 读取失败", ok: 0, abnormal: 1, unknown: 0)
                self.setRequestsMenuTitle(self.metricTitle("请求", "读取失败"))
                self.setCostMenuTitle(self.metricTitle("费用", "读取失败"))
                self.setTokensMenuTitle(self.metricTitle("Tokens", "读取失败"))
                self.setChannelMenuTitle(self.metricTitle("渠道", "读取失败"))
                self.setAPIKeysMenuTitle(self.metricTitle("API 密钥", "读取失败"))
                self.setUpdatedAtMenuTitle("错误：\(error.localizedDescription)")
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "liheMetrics" else {
            return
        }

        let json: String
        if let body = message.body as? String {
            json = body
        } else if let data = try? JSONSerialization.data(withJSONObject: message.body),
                  let serialized = String(data: data, encoding: .utf8) {
            json = serialized
        } else {
            setBalanceMenuTitle("余额：无法解析")
            setServiceStatusMenuTitle("● 无法解析", ok: 0, abnormal: 1, unknown: 0)
            setRequestsMenuTitle(metricTitle("请求", "无法解析"))
            setCostMenuTitle(metricTitle("费用", "无法解析"))
            setTokensMenuTitle(metricTitle("Tokens", "无法解析"))
            setChannelMenuTitle(metricTitle("渠道", "无法解析"))
            setAPIKeysMenuTitle(metricTitle("API 密钥", "无法解析"))
            setUpdatedAtMenuTitle(metricTitle("更新于", "—"))
            return
        }

        handleMetricsPayload(json)
    }

    private func handleMetricsPayload(_ json: String) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            setBalanceMenuTitle("余额：无法解析")
            setServiceStatusMenuTitle("● 无法解析", ok: 0, abnormal: 1, unknown: 0)
            setRequestsMenuTitle(metricTitle("请求", "无法解析"))
            setCostMenuTitle(metricTitle("费用", "无法解析"))
            setTokensMenuTitle(metricTitle("Tokens", "无法解析"))
            setChannelMenuTitle(metricTitle("渠道", "无法解析"))
            setAPIKeysMenuTitle(metricTitle("API 密钥", "无法解析"))
            setUpdatedAtMenuTitle(metricTitle("更新于", "—"))
            return
        }

        if let errorMessage = object["error"] as? String {
            setBalanceMenuTitle("余额：—")
            setServiceStatusMenuTitle(StatusMenuPresentation.serviceStatusTitles.offline, ok: 0, abnormal: 0, unknown: 0)
            setRequestsMenuTitle(metricTitle("请求", "—"))
            setCostMenuTitle(metricTitle("费用", "—"))
            setTokensMenuTitle(metricTitle("Tokens", "—"))
            setChannelMenuTitle(metricTitle("渠道", "—"), ok: 0, abnormal: 0, unknown: 0)
            setAPIKeysMenuTitle(metricTitle("API 密钥", "—"))
            setUpdatedAtMenuTitle("提示：\(errorMessage)")
            return
        }

        let balance = object["balance"] as? Double
        let todayRequests = object["todayRequests"] as? Double
        let todayCost = object["todayCost"] as? Double
        let todayTokens = object["todayTokens"] as? Double
        let channel = object["channels"] as? [String: Any]
        let ok = channel?["ok"] as? Int ?? 0
        let abnormal = channel?["abnormal"] as? Int ?? 0
        let unknown = channel?["unknown"] as? Int ?? 0
        let apiKeyCount = object["apiKeyCount"] as? Double
        let metricDisplay = StatusMetricDisplay(
            balance: balance,
            todayCost: todayCost,
            apiKeyCount: apiKeyCount,
            preferences: preferences
        )

        if abnormal > 0 {
            setServiceStatusMenuTitle(StatusMenuPresentation.serviceStatusTitles.unavailable, ok: ok, abnormal: abnormal, unknown: unknown)
        } else if unknown > 0 {
            setServiceStatusMenuTitle(StatusMenuPresentation.serviceStatusTitles.partial, ok: ok, abnormal: abnormal, unknown: unknown)
        } else if ok > 0 {
            setServiceStatusMenuTitle(StatusMenuPresentation.serviceStatusTitles.ok, ok: ok, abnormal: abnormal, unknown: unknown)
        } else {
            setServiceStatusMenuTitle(StatusMenuPresentation.serviceStatusTitles.offline, ok: ok, abnormal: abnormal, unknown: unknown)
        }

        let total = ok + abnormal + unknown
        setRequestsMenuTitle(metricTitle("请求", "\(MetricsFormatter.integer(todayRequests)) 次"))
        setTokensMenuTitle(metricTitle("Tokens", MetricsFormatter.compactInteger(todayTokens)))
        setCostMenuTitle(metricTitle("费用", metricDisplay.todayCostText))
        setBalanceMenuTitle(metricTitle("余额", metricDisplay.balanceText))
        setChannelMenuTitle(metricTitle("渠道", "\(ok) / \(total) 可用"), ok: ok, abnormal: abnormal, unknown: unknown)
        setAPIKeysMenuTitle(metricTitle("API 密钥", metricDisplay.apiKeyCountText))
        setUpdatedAtMenuTitle(metricTitle("更新于", DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)))
        evaluateAlerts(balance: balance, todayCost: todayCost, abnormalChannels: abnormal)
    }

    private func makePreferencesWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PreferencesWindowPresentation.width,
                height: PreferencesWindowPresentation.height
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppBranding.displayName) 偏好设置"
        window.center()
        window.isReleasedWhenClosed = false

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = PreferencesWindowPresentation.rowSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "菜单栏设置")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.textColor = .labelColor
        contentStack.addArrangedSubview(titleLabel)

        let privacy = NSButton(checkboxWithTitle: "隐藏余额、费用和 API 密钥数量", target: nil, action: nil)
        privacyCheckbox = privacy
        contentStack.addArrangedSubview(makePreferenceRow(label: "隐私模式", control: privacy))

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        RefreshIntervalOption.allCases.forEach { option in
            popup.addItem(withTitle: option.title)
            popup.lastItem?.representedObject = option.rawValue
        }
        refreshIntervalPopup = popup
        popup.widthAnchor.constraint(equalToConstant: 142).isActive = true
        contentStack.addArrangedSubview(makePreferenceRow(label: "自动刷新", control: popup))

        let launchAtLogin = NSButton(checkboxWithTitle: "登录后自动启动", target: nil, action: nil)
        launchAtLoginCheckbox = launchAtLogin
        contentStack.addArrangedSubview(makePreferenceRow(label: "开机启动", control: launchAtLogin))

        let autoCheckUpdates = NSButton(checkboxWithTitle: "启动时自动检查更新", target: nil, action: nil)
        autoCheckUpdatesCheckbox = autoCheckUpdates
        contentStack.addArrangedSubview(makePreferenceRow(label: "更新", control: autoCheckUpdates))

        let alertLabel = NSTextField(labelWithString: "提醒")
        alertLabel.font = NSFont.boldSystemFont(ofSize: 13)
        alertLabel.textColor = .secondaryLabelColor
        contentStack.addArrangedSubview(alertLabel)

        let channelAlert = NSButton(checkboxWithTitle: "发送系统通知", target: nil, action: nil)
        channelAlertCheckbox = channelAlert
        contentStack.addArrangedSubview(makePreferenceRow(label: "渠道异常", control: channelAlert))

        let balanceRow = makeThresholdRow(
            label: "余额低于",
            suffix: "美元时提醒",
            checkboxHandler: { self.balanceAlertCheckbox = $0 },
            textFieldHandler: { self.balanceThresholdField = $0 }
        )
        contentStack.addArrangedSubview(balanceRow)

        let costRow = makeThresholdRow(
            label: "今日费用超过",
            suffix: "美元时提醒",
            checkboxHandler: { self.dailyCostAlertCheckbox = $0 },
            textFieldHandler: { self.dailyCostThresholdField = $0 }
        )
        contentStack.addArrangedSubview(costRow)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonRow.addArrangedSubview(spacer)
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(closePreferences))
        let saveButton = NSButton(title: "保存", target: self, action: #selector(savePreferences))
        saveButton.keyEquivalent = "\r"
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(saveButton)

        let container = NSView()
        container.addSubview(contentStack)
        container.addSubview(buttonRow)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: PreferencesWindowPresentation.horizontalPadding),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -PreferencesWindowPresentation.horizontalPadding),
            contentStack.topAnchor.constraint(equalTo: container.topAnchor, constant: PreferencesWindowPresentation.verticalPadding),

            buttonRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: PreferencesWindowPresentation.horizontalPadding),
            buttonRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -PreferencesWindowPresentation.horizontalPadding),
            buttonRow.topAnchor.constraint(greaterThanOrEqualTo: contentStack.bottomAnchor, constant: 16),
            buttonRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            buttonRow.heightAnchor.constraint(equalToConstant: PreferencesWindowPresentation.footerHeight)
        ])
        window.contentView = container
        return window
    }

    private func makePreferenceRow(label: String, control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: label)
        labelView.textColor = .secondaryLabelColor
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: PreferencesWindowPresentation.labelColumnWidth).isActive = true

        control.widthAnchor.constraint(lessThanOrEqualToConstant: PreferencesWindowPresentation.controlColumnWidth).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(control)
        return row
    }

    private func makeThresholdRow(
        label: String,
        suffix: String,
        checkboxHandler: (NSButton) -> Void,
        textFieldHandler: (NSTextField) -> Void
    ) -> NSStackView {
        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        let field = NSTextField(string: "")
        field.formatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter
        }()
        field.widthAnchor.constraint(equalToConstant: PreferencesWindowPresentation.thresholdFieldWidth).isActive = true

        checkboxHandler(checkbox)
        textFieldHandler(field)

        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8
        controls.addArrangedSubview(checkbox)
        controls.addArrangedSubview(field)
        controls.addArrangedSubview(NSTextField(labelWithString: suffix))
        return makePreferenceRow(label: label, control: controls)
    }

    private func syncPreferencesControls() {
        privacyCheckbox?.state = preferences.privacyModeEnabled ? .on : .off
        if let index = RefreshIntervalOption.allCases.firstIndex(of: preferences.refreshInterval) {
            refreshIntervalPopup?.selectItem(at: index)
        }
        launchAtLoginCheckbox?.state = preferences.launchAtLoginEnabled ? .on : .off
        autoCheckUpdatesCheckbox?.state = preferences.autoCheckUpdatesEnabled ? .on : .off
        channelAlertCheckbox?.state = preferences.channelAlertEnabled ? .on : .off
        balanceAlertCheckbox?.state = preferences.balanceAlertEnabled ? .on : .off
        balanceThresholdField?.doubleValue = preferences.balanceAlertThreshold
        dailyCostAlertCheckbox?.state = preferences.dailyCostAlertEnabled ? .on : .off
        dailyCostThresholdField?.doubleValue = preferences.dailyCostAlertThreshold
    }

    @objc private func closePreferences() {
        preferencesWindow?.close()
    }

    @objc private func savePreferences() {
        let selectedRaw = refreshIntervalPopup?.selectedItem?.representedObject as? String
        let selectedInterval = selectedRaw.flatMap(RefreshIntervalOption.init(rawValue:)) ?? .off

        let updated = AppPreferences(
            privacyModeEnabled: privacyCheckbox?.state == .on,
            refreshInterval: selectedInterval,
            launchAtLoginEnabled: launchAtLoginCheckbox?.state == .on,
            autoCheckUpdatesEnabled: autoCheckUpdatesCheckbox?.state == .on,
            channelAlertEnabled: channelAlertCheckbox?.state == .on,
            balanceAlertEnabled: balanceAlertCheckbox?.state == .on,
            balanceAlertThreshold: max(0, balanceThresholdField?.doubleValue ?? AppPreferences.default.balanceAlertThreshold),
            dailyCostAlertEnabled: dailyCostAlertCheckbox?.state == .on,
            dailyCostAlertThreshold: max(0, dailyCostThresholdField?.doubleValue ?? AppPreferences.default.dailyCostAlertThreshold)
        )
        applyPreferences(updated)
        preferencesWindow?.close()
    }

    private func applyPreferences(_ updated: AppPreferences) {
        preferences = updated
        preferencesStore.save(updated)
        configureMetricsRefreshTimer()
        configureLaunchAtLogin(updated.launchAtLoginEnabled, showErrors: true)
        refreshMetricsForStatusMenu()
    }

    private func scheduleStartupUpdateCheckIfNeeded() {
        guard preferences.autoCheckUpdatesEnabled else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkForUpdates(silentWhenCurrent: true)
        }
    }

    private func checkForUpdates(silentWhenCurrent: Bool) {
        var request = URLRequest(url: updateFeedURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppBranding.displayName)/\(currentAppVersion())", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else {
                return
            }

            if let error {
                DispatchQueue.main.async {
                    if !silentWhenCurrent {
                        self.showUpdateCheckFailed(error.localizedDescription)
                    }
                }
                return
            }

            guard let data else {
                DispatchQueue.main.async {
                    if !silentWhenCurrent {
                        self.showUpdateCheckFailed("没有收到更新信息。")
                    }
                }
                return
            }

            do {
                let update = try GitHubReleaseParser.parseLatestRelease(data, assetName: AppBranding.dmgName)
                DispatchQueue.main.async {
                    self.handleUpdateCheckResult(update, silentWhenCurrent: silentWhenCurrent)
                }
            } catch {
                DispatchQueue.main.async {
                    if !silentWhenCurrent {
                        self.showUpdateCheckFailed(error.localizedDescription)
                    }
                }
            }
        }.resume()
    }

    private func handleUpdateCheckResult(_ update: AppUpdateInfo, silentWhenCurrent: Bool) {
        let currentVersion = currentAppVersion()
        guard VersionComparator.isRemoteVersion(update.version, newerThan: currentVersion) else {
            if !silentWhenCurrent {
                let alert = NSAlert()
                alert.messageText = "当前已是最新版本"
                alert.informativeText = "\(AppBranding.displayName) \(currentVersion)"
                alert.addButton(withTitle: "好")
                alert.runModal()
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = "发现新版本 \(update.version)"
        let notes = update.releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = notes.isEmpty ? "当前版本：\(currentVersion)" : "当前版本：\(currentVersion)\n\n\(notes)"
        alert.addButton(withTitle: "下载更新")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(update.downloadURL)
        }
    }

    private func showUpdateCheckFailed(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func currentAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private func configureLaunchAtLogin(_ enabled: Bool, showErrors: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("ToCreate launch at login configuration failed: %@", error.localizedDescription)
            guard showErrors else {
                return
            }

            let alert = NSAlert()
            alert.messageText = "开机启动设置失败"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    private func configureMetricsRefreshTimer() {
        metricsRefreshTimer?.invalidate()
        metricsRefreshTimer = nil

        guard let seconds = preferences.refreshInterval.seconds else {
            return
        }

        metricsRefreshTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshMetricsForStatusMenu()
            }
        }
    }

    private func evaluateAlerts(balance: Double?, todayCost: Double?, abnormalChannels: Int) {
        if preferences.channelAlertEnabled && abnormalChannels > 0 {
            if !channelAlertIsActive {
                sendNotification(title: "\(AppBranding.displayName) 渠道异常", body: "检测到 \(abnormalChannels) 个异常渠道。")
            }
            channelAlertIsActive = true
        } else {
            channelAlertIsActive = false
        }

        if preferences.balanceAlertEnabled, let balance, balance <= preferences.balanceAlertThreshold {
            if !balanceAlertIsActive {
                sendNotification(title: "\(AppBranding.displayName) 余额提醒", body: "当前余额低于 $\(preferences.balanceAlertThreshold)。")
            }
            balanceAlertIsActive = true
        } else {
            balanceAlertIsActive = false
        }

        if preferences.dailyCostAlertEnabled, let todayCost, todayCost >= preferences.dailyCostAlertThreshold {
            if !dailyCostAlertIsActive {
                sendNotification(title: "\(AppBranding.displayName) 今日费用提醒", body: "今日费用已超过 $\(preferences.dailyCostAlertThreshold)。")
            }
            dailyCostAlertIsActive = true
        } else {
            dailyCostAlertIsActive = false
        }
    }

    private func updateToolbarState() {
        guard let webView else {
            return
        }

        backButton?.isEnabled = webView.canGoBack
        forwardButton?.isEnabled = webView.canGoForward
        addressLabel?.stringValue = (webView.url ?? homeURL).absoluteString
        reloadButton?.image = NSImage(systemSymbolName: webView.isLoading ? "xmark" : "arrow.clockwise", accessibilityDescription: "刷新")
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }

        if URLPolicy.destination(for: url) == .embedded {
            decisionHandler(.allow)
        } else {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateToolbarState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updateToolbarState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateToolbarState()
        refreshMetricsForStatusMenu()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateToolbarState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateToolbarState()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else {
            return nil
        }

        if URLPolicy.destination(for: url) == .embedded {
            webView.load(URLRequest(url: url))
        } else {
            NSWorkspace.shared.open(url)
        }

        return nil
    }

    private static let entryRoutingJavaScript = """
    (function () {
      if (location.hostname !== 'api.lihe.chat') return;

      const normalizedPath = location.pathname.replace(/\\/+$/, '') || '/';
      const hasToken = Boolean(localStorage.getItem('auth_token'));

      if (hasToken && (normalizedPath === '/' || normalizedPath === '/login')) {
        location.replace('/dashboard');
      } else if (!hasToken && (normalizedPath === '/' || normalizedPath === '/dashboard')) {
        location.replace('/login');
      }
    })();
    """

    private static let metricsJavaScript = """
    (function () {
      async function run() {
      const apiBase = '/api/v1';
      const token = localStorage.getItem('auth_token');
      const headers = token ? { 'Authorization': 'Bearer ' + token } : {};

      async function api(path) {
        const response = await fetch(apiBase + path, {
          credentials: 'include',
          headers
        });
        const payload = await response.json().catch(() => null);
        if (!response.ok) {
          throw new Error((payload && (payload.message || payload.error || payload.code)) || ('HTTP ' + response.status));
        }
        if (payload && typeof payload === 'object' && 'code' in payload) {
          if (payload.code === 0) return payload.data;
          throw new Error(payload.message || payload.code || 'API error');
        }
        return payload;
      }

      function numberValue(value) {
        const number = Number(value);
        return Number.isFinite(number) ? number : null;
      }

      async function optionalApi(paths) {
        for (const path of paths) {
          try {
            return await api(path);
          } catch (_) {
          }
        }
        return null;
      }

      function listFrom(value) {
        if (Array.isArray(value)) return value;
        if (value && Array.isArray(value.items)) return value.items;
        if (value && Array.isArray(value.monitors)) return value.monitors;
        if (value && Array.isArray(value.tokens)) return value.tokens;
        if (value && Array.isArray(value.keys)) return value.keys;
        if (value && Array.isArray(value.data)) return value.data;
        if (value && value.data && Array.isArray(value.data.items)) return value.data.items;
        return [];
      }

      function countFrom(value) {
        if (!value) return null;
        for (const key of ['total', 'total_count', 'count', 'totalCount']) {
          const number = numberValue(value[key]);
          if (number !== null) return number;
        }
        if (value.pagination) {
          const number = numberValue(value.pagination.total || value.pagination.count);
          if (number !== null) return number;
        }
        const list = listFrom(value);
        return list.length ? list.length : null;
      }

      function classifyStatus(monitor, status) {
        const merged = Object.assign({}, monitor || {}, status || {}, (status && status.result) || {});
        const boolKeys = ['ok', 'healthy', 'available', 'success', 'is_ok', 'is_healthy'];
        for (const key of boolKeys) {
          if (merged[key] === true) return 'ok';
          if (merged[key] === false) return 'abnormal';
        }

        const raw = String(
          merged.status ||
          merged.state ||
          merged.health_status ||
          merged.overall_status ||
          merged.primary_status ||
          merged.last_status ||
          merged.result_status ||
          ''
        ).toLowerCase();

        if (['ok', 'healthy', 'success', 'normal', 'available', 'up', 'passed', 'pass', 'operational'].includes(raw)) return 'ok';
        if (['error', 'failed', 'fail', 'down', 'unhealthy', 'abnormal', 'unavailable', 'timeout'].includes(raw)) return 'abnormal';
        return 'unknown';
      }

      try {
        const [me, stats, monitorPayload, apiKeysPayload] = await Promise.all([
          api('/auth/me'),
          api('/usage/dashboard/stats'),
          optionalApi(['/channel-monitors']),
          optionalApi([
            '/token/?p=0&size=1',
            '/tokens?p=0&size=1',
            '/keys?p=0&size=1',
            '/api-keys?p=0&size=1'
          ])
        ]);

        const monitors = listFrom(monitorPayload);
        const statuses = await Promise.all(monitors.map(async (monitor) => {
          if (!monitor || monitor.id == null) return { monitor, status: null };
          try {
            return { monitor, status: await api('/channel-monitors/' + monitor.id + '/status') };
          } catch (_) {
            return { monitor, status: null };
          }
        }));

        const channelCounts = { total: monitors.length, ok: 0, abnormal: 0, unknown: 0 };
        for (const entry of statuses) {
          channelCounts[classifyStatus(entry.monitor, entry.status)] += 1;
        }
        window.webkit.messageHandlers.liheMetrics.postMessage(JSON.stringify({
          balance: numberValue(me && me.balance),
          todayRequests: numberValue(stats && stats.today_requests),
          todayCost: numberValue(stats && (stats.today_actual_cost ?? stats.today_cost)),
          todayTokens: numberValue(stats && stats.today_tokens),
          channels: channelCounts,
          apiKeyCount: countFrom(apiKeysPayload)
        }));
      } catch (error) {
        window.webkit.messageHandlers.liheMetrics.postMessage(JSON.stringify({ error: error && error.message ? error.message : String(error) }));
      }
      }
      run();
    })();
    """
}
