import AppKit
import ServiceManagement
import UserNotifications
import WebKit

final class StatusBarProgressView: NSView {
    private struct BarLayer {
        let labelLayer: CATextLayer
        let percentLayer: CATextLayer
        let trackLayer: CALayer
        let progressLayer: CALayer
    }

    private let titleLayer = CATextLayer()
    private var barLayers: [BarLayer] = []
    private var snapshots: [StatusBarProgressSnapshot] = []
    private var title = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        isHidden = true
        layer?.masksToBounds = false
        titleLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        titleLayer.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        titleLayer.fontSize = 10
        titleLayer.alignmentMode = .left
        titleLayer.foregroundColor = NSColor.white.cgColor
        layer?.addSublayer(titleLayer)
    }

    override func layout() {
        super.layout()
        guard !snapshots.isEmpty else {
            return
        }

        let titleWidth = StatusBarProgressLayout.titleWidth(title)
        titleLayer.frame = NSRect(x: bounds.minX, y: bounds.minY + 4, width: titleWidth, height: 12)
        let gap: CGFloat = 6
        let visibleCount = CGFloat(min(snapshots.count, StatusBarProgressLayout.maximumVisibleItems))
        let progressOriginX = bounds.minX + titleWidth + (titleWidth > 0 ? gap : 0)
        let progressWidth = max(42, bounds.width - titleWidth - (titleWidth > 0 ? gap : 0))
        let segmentWidth = max(42, (progressWidth - gap * CGFloat(max(0, snapshots.count - 1))) / visibleCount)
        for (index, snapshot) in snapshots.enumerated() {
            guard index < barLayers.count else {
                continue
            }

            let originX = progressOriginX + CGFloat(index) * (segmentWidth + gap)
            let textHeight: CGFloat = 12
            let textY = bounds.maxY - textHeight
            let labelFrame = NSRect(x: originX, y: textY, width: 12, height: textHeight)
            let percentFrame = NSRect(x: originX + 14, y: textY, width: max(24, segmentWidth - 14), height: textHeight)
            let trackFrame = NSRect(
                x: originX,
                y: bounds.minY + 1,
                width: max(24, segmentWidth),
                height: 4
            )
            let bar = barLayers[index]
            bar.labelLayer.frame = labelFrame
            bar.percentLayer.frame = percentFrame
            bar.trackLayer.frame = trackFrame
            bar.progressLayer.frame = NSRect(
                x: trackFrame.minX,
                y: trackFrame.minY,
                width: trackFrame.width * CGFloat(snapshot.fraction),
                height: trackFrame.height
            )
            bar.trackLayer.cornerRadius = 2
            bar.progressLayer.cornerRadius = 2
        }
    }

    func update(title: String, snapshots: [StatusBarProgressSnapshot]) {
        guard !snapshots.isEmpty else {
            isHidden = true
            toolTip = nil
            self.title = ""
            titleLayer.string = ""
            self.snapshots = []
            barLayers.forEach { bar in
                bar.labelLayer.removeFromSuperlayer()
                bar.percentLayer.removeFromSuperlayer()
                bar.trackLayer.removeFromSuperlayer()
                bar.progressLayer.removeFromSuperlayer()
            }
            barLayers.removeAll()
            return
        }

        isHidden = false
        self.title = title
        self.snapshots = Array(snapshots.prefix(3))
        titleLayer.string = title
        toolTip = ([title].filter { !$0.isEmpty } + self.snapshots.map(\.accessibilityLabel)).joined(separator: " · ")
        rebuildLayersIfNeeded()
        for (index, snapshot) in self.snapshots.enumerated() {
            guard index < barLayers.count else {
                continue
            }
            let bar = barLayers[index]
            bar.progressLayer.backgroundColor = snapshot.color.cgColor
        }
        refreshLayerText()
        needsLayout = true
    }

    private func refreshLayerText() {
        for (index, snapshot) in snapshots.enumerated() {
            guard index < barLayers.count else {
                continue
            }
            barLayers[index].labelLayer.string = snapshot.label
            barLayers[index].percentLayer.string = "\(Int((snapshot.fraction * 100).rounded()))%"
        }
    }

    private func rebuildLayersIfNeeded() {
        guard barLayers.count != snapshots.count else {
            return
        }

        barLayers.forEach { bar in
            bar.labelLayer.removeFromSuperlayer()
            bar.percentLayer.removeFromSuperlayer()
            bar.trackLayer.removeFromSuperlayer()
            bar.progressLayer.removeFromSuperlayer()
        }
        barLayers = snapshots.map { _ in
            let labelLayer = CATextLayer()
            labelLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            labelLayer.font = NSFont.boldSystemFont(ofSize: StatusBarProgressPresentation.labelFontSize)
            labelLayer.fontSize = StatusBarProgressPresentation.labelFontSize
            labelLayer.alignmentMode = .center
            labelLayer.foregroundColor = NSColor.white.cgColor

            let percentLayer = CATextLayer()
            percentLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            percentLayer.font = NSFont.monospacedDigitSystemFont(ofSize: StatusBarProgressPresentation.percentFontSize, weight: .bold)
            percentLayer.fontSize = StatusBarProgressPresentation.percentFontSize
            percentLayer.alignmentMode = .right
            percentLayer.foregroundColor = NSColor.white.cgColor

            let trackLayer = CALayer()
            trackLayer.backgroundColor = NSColor.white.withAlphaComponent(0.28).cgColor
            trackLayer.cornerRadius = 2

            let progressLayer = CALayer()
            progressLayer.cornerRadius = 2
            progressLayer.backgroundColor = NSColor.systemGreen.cgColor

            layer?.addSublayer(labelLayer)
            layer?.addSublayer(percentLayer)
            layer?.addSublayer(trackLayer)
            layer?.addSublayer(progressLayer)
            return BarLayer(labelLayer: labelLayer, percentLayer: percentLayer, trackLayer: trackLayer, progressLayer: progressLayer)
        }
    }
}

final class StatusBarProgressPreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let pillRect = NSRect(x: 0, y: bounds.midY - 8, width: 54, height: 16)
        NSColor.systemGreen.setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: 8, yRadius: 8).fill()
        let label = StatusBarProgressPresentation.previewTitle as NSString
        label.draw(
            in: NSRect(x: 8, y: pillRect.minY + 2, width: 12, height: 12),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: StatusBarProgressPresentation.labelFontSize, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
        let percent = StatusBarProgressPresentation.previewPercent as NSString
        percent.draw(
            in: NSRect(x: 22, y: pillRect.minY + 2, width: 28, height: 12),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: StatusBarProgressPresentation.percentFontSize, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
        let trackRect = NSRect(x: pillRect.maxX + 8, y: bounds.midY - 2, width: max(24, bounds.width - pillRect.maxX - 8), height: 4)
        NSColor.separatorColor.withAlphaComponent(0.38).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: 2, yRadius: 2).fill()
        NSColor.systemGreen.setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: trackRect.minX,
                y: trackRect.minY,
                width: trackRect.width * CGFloat(StatusBarProgressPresentation.previewFraction),
                height: 4
            ),
            xRadius: 2,
            yRadius: 2
        ).fill()
    }
}

@main
final class LiheAPIApp: NSObject, NSApplicationDelegate, NSMenuDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, @preconcurrency URLSessionDownloadDelegate, @preconcurrency UNUserNotificationCenterDelegate {
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
    private var statusBarProgressView: StatusBarProgressView?
    private var serviceStatusMenuItem: NSMenuItem!
    private var balanceMenuItem: NSMenuItem!
    private var requestsMenuItem: NSMenuItem!
    private var costMenuItem: NSMenuItem!
    private var tokensMenuItem: NSMenuItem!
    private var apiKeysMenuItem: NSMenuItem!
    private var subscriptionSectionMenuItem: NSMenuItem!
    private var subscriptionTitleMenuItem: NSMenuItem!
    private var subscriptionExpiryMenuItem: NSMenuItem!
    private var subscriptionDailyMenuItem: NSMenuItem!
    private var subscriptionWeeklyMenuItem: NSMenuItem!
    private var subscriptionMonthlyMenuItem: NSMenuItem!
    private var subscriptionSeparatorMenuItem: NSMenuItem!
    private var updatedAtMenuItem: NSMenuItem!
    private let preferencesStore = PreferencesStore()
    private lazy var preferences = preferencesStore.load()
    private var metricsRefreshTimer: Timer?
    private var preferencesWindow: NSWindow?
    private var updateProgressWindow: NSWindow?
    private var updateProgressIndicator: NSProgressIndicator?
    private var updateProgressLabel: NSTextField?
    private var updateDownloadSession: URLSession?
    private var updateProgressTask: URLSessionDownloadTask?
    private var pendingUpdateDownload: PendingUpdateDownload?
    private var privacyCheckbox: NSButton?
    private var refreshIntervalPopup: NSPopUpButton?
    private var launchAtLoginCheckbox: NSButton?
    private var autoCheckUpdatesCheckbox: NSButton?
    private var channelAlertCheckbox: NSButton?
    private var balanceAlertCheckbox: NSButton?
    private var balanceThresholdField: NSTextField?
    private var dailyCostAlertCheckbox: NSButton?
    private var dailyCostThresholdField: NSTextField?
    private var statusBarMetricCheckboxes: [StatusBarMetricOption: NSButton] = [:]
    private var channelAlertIsActive = false
    private var balanceAlertIsActive = false
    private var dailyCostAlertIsActive = false
    private var balanceRetryAttemptsRemaining = 0
    private var lastSuccessfulBalance: Double?
    private var latestBalance: Double?
    private var latestTodayRequests: Double?
    private var latestTodayTokens: Double?
    private var latestTodayCost: Double?
    private var latestAPIKeyCount: Double?
    private var latestSubscription: SubscriptionInfo?
    private var statusBarTitle = ""
    private var statusBarProgressItems: [StatusBarProgressSnapshot] = []
    private var currentStatusBarState: StatusBarState = .offline
    private let updateFeedURL = URL(string: "https://github.com/floating0516/ToCreate-api/releases/latest")!
    private let latestDMGDownloadURL = URL(string: "https://github.com/floating0516/ToCreate-api/releases/latest/download/ToCreate.dmg")!

    private struct PendingUpdateDownload {
        let update: AppUpdateInfo
        let updatesDirectory: URL
        let destinationURL: URL
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        buildStatusItem()
        updateStatusBarMetricsFromLatestValues()
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showWindow()
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "tocreate" }) else {
            return
        }
        showWindow()
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        updateStatusBarIcon(.offline)

        let menu = NSMenu()
        menu.delegate = self
        serviceStatusMenuItem = informationalMenuItem("● 正在读取", color: StatusMenuPresentation.warningTextColor)
        balanceMenuItem = informationalMenuItem(metricTitle("余额", "加载中…"), color: StatusMenuPresentation.balanceTextColor)
        requestsMenuItem = informationalMenuItem(metricTitle("请求", "加载中…"), color: StatusMenuPresentation.usageTextColor)
        costMenuItem = informationalMenuItem(metricTitle("费用", "加载中…"), color: StatusMenuPresentation.costTextColor)
        tokensMenuItem = informationalMenuItem(metricTitle("Tokens", "加载中…"), color: StatusMenuPresentation.tokensTextColor)
        apiKeysMenuItem = informationalMenuItem(metricTitle("API 密钥", "加载中…"), color: StatusMenuPresentation.apiKeysTextColor)
        subscriptionSectionMenuItem = sectionHeaderMenuItem("订阅")
        subscriptionTitleMenuItem = informationalMenuItem(metricTitle("套餐", "—"), color: StatusMenuPresentation.primaryTextColor)
        subscriptionExpiryMenuItem = informationalMenuItem(metricTitle("到期", "—"), color: StatusMenuPresentation.updatedAtTextColor)
        subscriptionDailyMenuItem = informationalMenuItem(metricTitle("每日", "—"), color: StatusMenuPresentation.primaryTextColor)
        subscriptionWeeklyMenuItem = informationalMenuItem(metricTitle("每周", "—"), color: StatusMenuPresentation.primaryTextColor)
        subscriptionMonthlyMenuItem = informationalMenuItem(metricTitle("每月", "—"), color: StatusMenuPresentation.primaryTextColor)
        subscriptionSeparatorMenuItem = .separator()
        setSubscriptionMenuVisible(false)
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
        menu.addItem(.separator())
        menu.addItem(subscriptionSectionMenuItem)
        menu.addItem(subscriptionTitleMenuItem)
        menu.addItem(subscriptionExpiryMenuItem)
        menu.addItem(subscriptionDailyMenuItem)
        menu.addItem(subscriptionWeeklyMenuItem)
        menu.addItem(subscriptionMonthlyMenuItem)
        menu.addItem(subscriptionSeparatorMenuItem)
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

    private func setServiceStatusMenuTitle(_ title: String, ok: Int = 0, abnormal: Int = 0, unknown: Int = 1, state: StatusBarState? = nil) {
        setInformationalMenuItem(
            serviceStatusMenuItem,
            title: title,
            color: StatusMenuPresentation.channelTextColor(ok: ok, abnormal: abnormal, unknown: unknown)
        )
        updateStatusBarIcon(state ?? .from(ok: ok, abnormal: abnormal, unknown: unknown))
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
        currentStatusBarState = state
        guard let button = statusItem?.button else {
            return
        }

        button.toolTip = state.accessibilityLabel
        applyStatusItemTitle()
    }

    private func applyStatusItemTitle() {
        guard let button = statusItem?.button else {
            return
        }

        let title = statusBarTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let showsProgress = !statusBarProgressItems.isEmpty
        if showsProgress, let progressLength = StatusBarProgressLayout.requiredStatusItemLength(itemCount: statusBarProgressItems.count, title: title) {
            statusItem.length = progressLength
        } else {
            statusItem.length = title.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
        }
        if showsProgress {
            button.image = nil
            button.imagePosition = .noImage
        } else {
            let image = makeLucideDogStatusImage(statusColor: currentStatusBarState.color, accessibilityLabel: currentStatusBarState.accessibilityLabel)
            image?.isTemplate = false
            button.image = image
            button.imagePosition = title.isEmpty ? .imageOnly : .imageLeft
        }
        button.contentTintColor = nil
        button.attributedTitle = NSAttributedString(
            string: showsProgress || title.isEmpty ? "" : " \(title)",
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            ]
        )
        ensureStatusBarProgressView(on: button)
        statusBarProgressView?.update(title: title, snapshots: statusBarProgressItems)
    }

    private func updateStatusBarMetricsTitle(_ display: StatusMetricDisplay?) {
        statusBarTitle = display?.statusBarTitle ?? ""
        statusBarProgressItems = display?.statusBarProgressItems ?? []
        applyStatusItemTitle()
    }

    private func ensureStatusBarProgressView(on button: NSStatusBarButton) {
        if let statusBarProgressView, statusBarProgressView.superview === button {
            return
        }

        statusBarProgressView?.removeFromSuperview()
        let progressView = StatusBarProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 7),
            progressView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -7),
            progressView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            progressView.heightAnchor.constraint(equalToConstant: StatusBarProgressPresentation.viewHeight)
        ])
        statusBarProgressView = progressView
    }

    private func updateStatusBarMetricsFromLatestValues() {
        let display = StatusMetricDisplay(
            balance: latestBalance,
            todayRequests: latestTodayRequests,
            todayTokens: latestTodayTokens,
            todayCost: latestTodayCost,
            apiKeyCount: latestAPIKeyCount,
            subscription: latestSubscription,
            preferences: preferences
        )
        updateStatusBarMetricsTitle(display)
    }

    private func makeLucideDogStatusImage(statusColor: NSColor, accessibilityLabel: String) -> NSImage? {
        let lucideDogNosePath = "M11.25 16.25h1.5L12 17z"
        _ = lucideDogNosePath

        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.accessibilityDescription = accessibilityLabel
        image.lockFocus()

        let iconColor = NSColor.white
        iconColor.setStroke()
        iconColor.setFill()

        let scale = 18.0 / 24.0
        let transform = AffineTransform(
            m11: scale,
            m12: 0,
            m21: 0,
            m22: -scale,
            tX: 0,
            tY: 18
        )

        func transformedPath(_ path: NSBezierPath) -> NSBezierPath {
            let transformed = path
            transformed.transform(using: transform)
            return transformed
        }

        func draw(_ path: NSBezierPath) {
            let transformed = transformedPath(path)
            transformed.lineWidth = 1.45
            transformed.lineCapStyle = .round
            transformed.lineJoinStyle = .round
            transformed.stroke()
        }

        let headFill = NSBezierPath()
        headFill.move(to: NSPoint(x: 4.42, y: 11.247))
        headFill.curve(to: NSPoint(x: 8.2, y: 5.25), controlPoint1: NSPoint(x: 4.72, y: 8.75), controlPoint2: NSPoint(x: 6.05, y: 5.78))
        headFill.curve(to: NSPoint(x: 15.8, y: 5.25), controlPoint1: NSPoint(x: 10.5, y: 4.7), controlPoint2: NSPoint(x: 13.5, y: 4.7))
        headFill.curve(to: NSPoint(x: 19.507, y: 11.247), controlPoint1: NSPoint(x: 17.95, y: 5.78), controlPoint2: NSPoint(x: 19.2, y: 8.75))
        headFill.curve(to: NSPoint(x: 20, y: 14.556), controlPoint1: NSPoint(x: 19.83, y: 12.25), controlPoint2: NSPoint(x: 20, y: 13.34))
        headFill.curve(to: NSPoint(x: 12, y: 21), controlPoint1: NSPoint(x: 20, y: 18.728), controlPoint2: NSPoint(x: 16.418, y: 21))
        headFill.curve(to: NSPoint(x: 4, y: 14.556), controlPoint1: NSPoint(x: 7.582, y: 21), controlPoint2: NSPoint(x: 4, y: 18.728))
        headFill.curve(to: NSPoint(x: 4.42, y: 11.247), controlPoint1: NSPoint(x: 4, y: 13.45), controlPoint2: NSPoint(x: 4.14, y: 12.35))
        headFill.close()
        iconColor.withAlphaComponent(0.35).setFill()
        transformedPath(headFill).fill()
        iconColor.setStroke()
        iconColor.setFill()

        let face = NSBezierPath()
        face.move(to: NSPoint(x: 4.42, y: 11.247))
        face.curve(to: NSPoint(x: 4, y: 14.556), controlPoint1: NSPoint(x: 4.14, y: 12.35), controlPoint2: NSPoint(x: 4, y: 13.45))
        face.curve(to: NSPoint(x: 12, y: 21), controlPoint1: NSPoint(x: 4, y: 18.728), controlPoint2: NSPoint(x: 7.582, y: 21))
        face.curve(to: NSPoint(x: 20, y: 14.556), controlPoint1: NSPoint(x: 16.418, y: 21), controlPoint2: NSPoint(x: 20, y: 18.728))
        face.curve(to: NSPoint(x: 19.507, y: 11.247), controlPoint1: NSPoint(x: 20, y: 13.34), controlPoint2: NSPoint(x: 19.83, y: 12.25))
        draw(face)

        let ears = NSBezierPath()
        ears.move(to: NSPoint(x: 8.5, y: 8.5))
        ears.curve(to: NSPoint(x: 6.156, y: 11), controlPoint1: NSPoint(x: 8.116, y: 9.55), controlPoint2: NSPoint(x: 7.417, y: 10.528))
        ears.curve(to: NSPoint(x: 2.5, y: 10), controlPoint1: NSPoint(x: 4.225, y: 11.722), controlPoint2: NSPoint(x: 2.58, y: 10.703))
        ears.curve(to: NSPoint(x: 6.5, y: 3), controlPoint1: NSPoint(x: 2.387, y: 9.006), controlPoint2: NSPoint(x: 3.677, y: 3.47))
        ears.curve(to: NSPoint(x: 10.151, y: 5.235), controlPoint1: NSPoint(x: 8.423, y: 2.679), controlPoint2: NSPoint(x: 10.151, y: 3.845))
        ears.curve(to: NSPoint(x: 14, y: 5.277), controlPoint1: NSPoint(x: 11.2, y: 5.02), controlPoint2: NSPoint(x: 12.75, y: 5.02))
        ears.curve(to: NSPoint(x: 17.767, y: 3), controlPoint1: NSPoint(x: 14, y: 3.887), controlPoint2: NSPoint(x: 15.844, y: 2.679))
        ears.curve(to: NSPoint(x: 21.767, y: 10), controlPoint1: NSPoint(x: 20.59, y: 3.47), controlPoint2: NSPoint(x: 21.88, y: 9.006))
        ears.curve(to: NSPoint(x: 18.111, y: 11), controlPoint1: NSPoint(x: 21.687, y: 10.703), controlPoint2: NSPoint(x: 20.042, y: 11.722))
        ears.curve(to: NSPoint(x: 15.872, y: 8.5), controlPoint1: NSPoint(x: 16.85, y: 10.528), controlPoint2: NSPoint(x: 16.256, y: 9.55))
        draw(ears)

        let leftEye = NSBezierPath()
        leftEye.move(to: NSPoint(x: 8, y: 14))
        leftEye.line(to: NSPoint(x: 8, y: 14.5))
        draw(leftEye)

        let rightEye = NSBezierPath()
        rightEye.move(to: NSPoint(x: 16, y: 14))
        rightEye.line(to: NSPoint(x: 16, y: 14.5))
        draw(rightEye)

        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 11.25, y: 16.25))
        nose.line(to: NSPoint(x: 12.75, y: 16.25))
        nose.line(to: NSPoint(x: 12, y: 17))
        nose.close()
        let transformedNose = nose
        transformedNose.transform(using: transform)
        transformedNose.fill()

        NSColor.black.withAlphaComponent(0.28).setFill()
        let statusDotBacking = NSBezierPath(ovalIn: NSRect(x: 11.3, y: 1.1, width: 6.8, height: 6.8))
        statusDotBacking.fill()

        statusColor.setFill()
        let statusDot = NSBezierPath(ovalIn: NSRect(x: 12.1, y: 1.9, width: 5.2, height: 5.2))
        statusDot.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
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

    private func setAPIKeysMenuTitle(_ title: String) {
        setInformationalMenuItem(apiKeysMenuItem, title: title, color: StatusMenuPresentation.apiKeysTextColor)
    }

    private func setSubscriptionMenuVisible(_ isVisible: Bool) {
        [
            subscriptionSectionMenuItem,
            subscriptionTitleMenuItem,
            subscriptionExpiryMenuItem,
            subscriptionDailyMenuItem,
            subscriptionWeeklyMenuItem,
            subscriptionMonthlyMenuItem,
            subscriptionSeparatorMenuItem
        ].forEach { item in
            item?.isHidden = !isVisible
        }
    }

    private func updateSubscriptionMenu(_ subscription: SubscriptionInfo?) {
        guard let subscription else {
            setSubscriptionMenuVisible(false)
            return
        }

        setSubscriptionMenuVisible(true)
        setInformationalMenuItem(
            subscriptionTitleMenuItem,
            title: metricTitle("套餐", subscription.titleText.isEmpty ? "—" : subscription.titleText),
            color: StatusMenuPresentation.primaryTextColor
        )
        setInformationalMenuItem(
            subscriptionExpiryMenuItem,
            title: metricTitle("到期", subscription.expiryText ?? "—"),
            color: StatusMenuPresentation.updatedAtTextColor
        )
        setInformationalMenuItem(
            subscriptionDailyMenuItem,
            title: metricTitle("每日", subscription.daily.menuText),
            color: StatusMenuPresentation.primaryTextColor
        )
        setInformationalMenuItem(
            subscriptionWeeklyMenuItem,
            title: metricTitle("每周", subscription.weekly.menuText),
            color: StatusMenuPresentation.primaryTextColor
        )
        setInformationalMenuItem(
            subscriptionMonthlyMenuItem,
            title: metricTitle("每月", subscription.monthly.menuText),
            color: StatusMenuPresentation.primaryTextColor
        )
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

    @objc private func showAboutWindow() {
        let about = AboutInfo(
            appName: AppBranding.displayName,
            version: currentAppVersion(),
            build: currentBuildNumber(),
            repositoryURL: AppBranding.repositoryURL,
            updateFeedDescription: AppBranding.updateFeedDescription
        )

        let alert = NSAlert()
        alert.messageText = about.appName
        alert.informativeText = about.informativeText
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "打开 GitHub")
        alert.addButton(withTitle: "好")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(about.repositoryURL)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 \(AppBranding.displayName)", action: #selector(showAboutWindow), keyEquivalent: "")
        appMenu.addItem(.separator())
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

    private func scheduleMetricsRefreshAfterPageLoad() {
        balanceRetryAttemptsRemaining = 3
        refreshMetricsForStatusMenu()
        scheduleMetricsRefresh(after: 0.8)
        scheduleMetricsRefresh(after: 2.0)
    }

    private func scheduleMetricsRefresh(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.refreshMetricsForStatusMenu()
        }
    }

    private func scheduleBalanceRetryIfNeeded(balance: Double?) {
        guard balance == nil, balanceRetryAttemptsRemaining > 0 else {
            balanceRetryAttemptsRemaining = 0
            return
        }

        balanceRetryAttemptsRemaining -= 1
        scheduleMetricsRefresh(after: 1.0)
    }

    private func refreshMetricsForStatusMenu() {
        guard webView != nil else {
            return
        }

        setRefreshingStatusMenuTitle("正在刷新…")
        setRequestsMenuTitle(metricTitle("请求", "刷新中…"))
        setCostMenuTitle(metricTitle("费用", "刷新中…"))
        setTokensMenuTitle(metricTitle("Tokens", "刷新中…"))
        setAPIKeysMenuTitle(metricTitle("API 密钥", "刷新中…"))

        webView.evaluateJavaScript(Self.metricsJavaScript) { [weak self] _, error in
            guard let self, let error else {
                return
            }
            DispatchQueue.main.async {
                self.setBalanceMenuTitle("余额：读取失败")
                self.setServiceStatusMenuTitle("● 读取失败", ok: 0, abnormal: 1, unknown: 0, state: .unavailable)
                self.setRequestsMenuTitle(self.metricTitle("请求", "读取失败"))
                self.setCostMenuTitle(self.metricTitle("费用", "读取失败"))
                self.setTokensMenuTitle(self.metricTitle("Tokens", "读取失败"))
                self.setAPIKeysMenuTitle(self.metricTitle("API 密钥", "读取失败"))
                self.latestSubscription = nil
                self.updateSubscriptionMenu(nil)
                self.updateStatusBarMetricsFromLatestValues()
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
            setServiceStatusMenuTitle("● 无法解析", ok: 0, abnormal: 1, unknown: 0, state: .unavailable)
            setRequestsMenuTitle(metricTitle("请求", "无法解析"))
            setCostMenuTitle(metricTitle("费用", "无法解析"))
            setTokensMenuTitle(metricTitle("Tokens", "无法解析"))
            setAPIKeysMenuTitle(metricTitle("API 密钥", "无法解析"))
            latestSubscription = nil
            updateSubscriptionMenu(nil)
            setUpdatedAtMenuTitle(metricTitle("更新于", "—"))
            return
        }

        handleMetricsPayload(json)
    }

    private func handleMetricsPayload(_ json: String) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            setBalanceMenuTitle("余额：无法解析")
            setServiceStatusMenuTitle("● 无法解析", ok: 0, abnormal: 1, unknown: 0, state: .unavailable)
            setRequestsMenuTitle(metricTitle("请求", "无法解析"))
            setCostMenuTitle(metricTitle("费用", "无法解析"))
            setTokensMenuTitle(metricTitle("Tokens", "无法解析"))
            setAPIKeysMenuTitle(metricTitle("API 密钥", "无法解析"))
            latestSubscription = nil
            updateSubscriptionMenu(nil)
            setUpdatedAtMenuTitle(metricTitle("更新于", "—"))
            updateStatusBarMetricsFromLatestValues()
            return
        }

        if let errorMessage = object["error"] as? String {
            setBalanceMenuTitle("余额：—")
            setServiceStatusMenuTitle(StatusMenuPresentation.serviceStatusTitles.offline, ok: 0, abnormal: 0, unknown: 0)
            setRequestsMenuTitle(metricTitle("请求", "—"))
            setCostMenuTitle(metricTitle("费用", "—"))
            setTokensMenuTitle(metricTitle("Tokens", "—"))
            setAPIKeysMenuTitle(metricTitle("API 密钥", "—"))
            latestSubscription = nil
            updateSubscriptionMenu(nil)
            setUpdatedAtMenuTitle("提示：\(errorMessage)")
            updateStatusBarMetricsFromLatestValues()
            return
        }

        let balance = MetricPayloadParser.doubleValue(object["balance"])
        let todayRequests = MetricPayloadParser.doubleValue(object["todayRequests"])
        let todayCost = MetricPayloadParser.doubleValue(object["todayCost"])
        let todayTokens = MetricPayloadParser.doubleValue(object["todayTokens"])
        let channel = object["channels"] as? [String: Any]
        let abnormal = channel?["abnormal"] as? Int ?? 0
        let apiKeyCount = MetricPayloadParser.doubleValue(object["apiKeyCount"])
        let subscription = SubscriptionPayloadParser.subscriptionInfo(object["subscription"])
        let displayBalance = MetricValueCache.replacingMissing(current: balance, cached: lastSuccessfulBalance)
        if let balance {
            lastSuccessfulBalance = balance
        }
        latestBalance = displayBalance
        latestTodayRequests = todayRequests
        latestTodayTokens = todayTokens
        latestTodayCost = todayCost
        latestAPIKeyCount = apiKeyCount
        latestSubscription = subscription
        let metricDisplay = StatusMetricDisplay(
            balance: displayBalance,
            todayRequests: todayRequests,
            todayTokens: todayTokens,
            todayCost: todayCost,
            apiKeyCount: apiKeyCount,
            subscription: subscription,
            preferences: preferences
        )

        setServiceStatusMenuTitle(StatusMenuPresentation.serviceStatusTitles.ok, ok: 1, abnormal: 0, unknown: 0)
        updateStatusBarMetricsTitle(metricDisplay)

        let updatedAt = Date()
        setRequestsMenuTitle(metricTitle("请求", "\(MetricsFormatter.integer(todayRequests)) 次"))
        setTokensMenuTitle(metricTitle("Tokens", MetricsFormatter.compactInteger(todayTokens)))
        setCostMenuTitle(metricTitle("费用", metricDisplay.todayCostText))
        setBalanceMenuTitle(metricTitle("余额", metricDisplay.balanceText))
        setAPIKeysMenuTitle(metricTitle("API 密钥", metricDisplay.apiKeyCountText))
        updateSubscriptionMenu(subscription)
        setUpdatedAtMenuTitle(metricTitle("更新于", DateFormatter.localizedString(from: updatedAt, dateStyle: .none, timeStyle: .medium)))
        scheduleBalanceRetryIfNeeded(balance: balance)
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

        contentStack.addArrangedSubview(makeStatusBarMetricOptionsPanel())

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

    private func makeStatusBarMetricOptionsPanel() -> NSView {
        statusBarMetricCheckboxes.removeAll()

        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 9
        panel.edgeInsets = NSEdgeInsets(top: 13, left: 15, bottom: 13, right: 15)
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 8
        panel.layer?.borderWidth = 0
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.36).cgColor
        panel.widthAnchor.constraint(equalToConstant: 548).isActive = true

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        let headerText = NSStackView()
        headerText.orientation = .vertical
        headerText.alignment = .leading
        headerText.spacing = 2
        let headerTitle = NSTextField(labelWithString: "菜单栏指标")
        headerTitle.font = .boldSystemFont(ofSize: 14)
        headerTitle.textColor = .labelColor
        let headerSubtitle = NSTextField(labelWithString: "普通指标和订阅额度可同时显示")
        headerSubtitle.font = .systemFont(ofSize: 12)
        headerSubtitle.textColor = .secondaryLabelColor
        headerText.addArrangedSubview(headerTitle)
        headerText.addArrangedSubview(headerSubtitle)
        header.addArrangedSubview(headerText)
        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(headerSpacer)
        panel.addArrangedSubview(header)

        let regularMetrics = NSStackView()
        regularMetrics.orientation = .horizontal
        regularMetrics.alignment = .centerY
        regularMetrics.spacing = 12
        [StatusBarMetricOption.balance, .todayCost, .todayRequests, .todayTokens].forEach { option in
            let checkbox = NSButton(checkboxWithTitle: option.title, target: nil, action: nil)
            checkbox.identifier = NSUserInterfaceItemIdentifier(option.rawValue)
            statusBarMetricCheckboxes[option] = checkbox
            regularMetrics.addArrangedSubview(checkbox)
        }
        panel.addArrangedSubview(regularMetrics)

        let subscriptionLabel = NSTextField(labelWithString: "订阅额度")
        subscriptionLabel.font = .boldSystemFont(ofSize: 12)
        subscriptionLabel.textColor = .secondaryLabelColor
        panel.addArrangedSubview(subscriptionLabel)

        let subscriptionRows = NSStackView()
        subscriptionRows.orientation = .vertical
        subscriptionRows.alignment = .leading
        subscriptionRows.spacing = 5
        [
            (StatusBarMetricOption.subscriptionDaily, "每日额度", "今日额度进度"),
            (StatusBarMetricOption.subscriptionWeekly, "每周额度", "本周额度进度"),
            (StatusBarMetricOption.subscriptionMonthly, "每月额度", "本月额度进度")
        ].forEach { option, title, subtitle in
            subscriptionRows.addArrangedSubview(makeMetricIndicatorRow(option: option, title: title, subtitle: subtitle))
        }
        panel.addArrangedSubview(subscriptionRows)

        return panel
    }

    private func makeMetricIndicatorRow(option: StatusBarMetricOption, title: String, subtitle: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 9
        row.edgeInsets = NSEdgeInsets(top: 7, left: 10, bottom: 7, right: 10)
        row.wantsLayer = true
        row.layer?.cornerRadius = 7
        row.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.56).cgColor
        row.widthAnchor.constraint(equalToConstant: 518).isActive = true
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.identifier = NSUserInterfaceItemIdentifier(option.rawValue)
        statusBarMetricCheckboxes[option] = checkbox
        row.addArrangedSubview(checkbox)

        let icon = NSTextField(labelWithString: option.compactLabel)
        icon.font = .boldSystemFont(ofSize: 12)
        icon.textColor = .white
        icon.alignment = .center
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 7
        icon.layer?.backgroundColor = NSColor.systemGreen.cgColor
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        row.addArrangedSubview(icon)

        let labels = NSStackView()
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        labels.addArrangedSubview(titleLabel)
        labels.addArrangedSubview(subtitleLabel)
        labels.widthAnchor.constraint(equalToConstant: 120).isActive = true
        row.addArrangedSubview(labels)

        let preview = StatusBarProgressPreviewView()
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.widthAnchor.constraint(equalToConstant: 270).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 22).isActive = true
        row.addArrangedSubview(preview)
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
        StatusBarMetricOption.allCases.forEach { option in
            statusBarMetricCheckboxes[option]?.state = preferences.statusBarMetricOptions.contains(option) ? .on : .off
        }
    }

    @objc private func closePreferences() {
        preferencesWindow?.close()
    }

    @objc private func savePreferences() {
        let selectedRaw = refreshIntervalPopup?.selectedItem?.representedObject as? String
        let selectedInterval = selectedRaw.flatMap(RefreshIntervalOption.init(rawValue:)) ?? .off
        let selectedStatusBarMetricOptions = StatusBarMetricOption.allCases.filter { option in
            statusBarMetricCheckboxes[option]?.state == .on
        }

        let updated = AppPreferences(
            privacyModeEnabled: privacyCheckbox?.state == .on,
            refreshInterval: selectedInterval,
            launchAtLoginEnabled: launchAtLoginCheckbox?.state == .on,
            autoCheckUpdatesEnabled: autoCheckUpdatesCheckbox?.state == .on,
            channelAlertEnabled: channelAlertCheckbox?.state == .on,
            balanceAlertEnabled: balanceAlertCheckbox?.state == .on,
            balanceAlertThreshold: max(0, balanceThresholdField?.doubleValue ?? AppPreferences.default.balanceAlertThreshold),
            dailyCostAlertEnabled: dailyCostAlertCheckbox?.state == .on,
            dailyCostAlertThreshold: max(0, dailyCostThresholdField?.doubleValue ?? AppPreferences.default.dailyCostAlertThreshold),
            statusBarMetricOptions: selectedStatusBarMetricOptions
        )
        applyPreferences(updated)
        preferencesWindow?.close()
    }

    private func applyPreferences(_ updated: AppPreferences) {
        preferences = updated
        preferencesStore.save(updated)
        configureMetricsRefreshTimer()
        configureLaunchAtLogin(updated.launchAtLoginEnabled, showErrors: true)
        updateStatusBarMetricsFromLatestValues()
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
        request.setValue("\(AppBranding.displayName)/\(currentAppVersion())", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
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

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let statusDescription = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                DispatchQueue.main.async {
                    if !silentWhenCurrent {
                        self.showUpdateCheckFailed("GitHub 返回 \(httpResponse.statusCode)：\(statusDescription)")
                    }
                }
                return
            }

            do {
                let update = try GitHubReleaseRedirectParser.parseLatestReleaseURL(
                    response?.url,
                    downloadURL: self.latestDMGDownloadURL
                )
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
            downloadAndOpenUpdate(update)
        }
    }

    private func downloadAndOpenUpdate(_ update: AppUpdateInfo) {
        let updatesDirectory = updateDownloadsDirectory()
        let destinationURL = UpdateDownloadPlanner.destinationURL(for: update, updatesDirectory: updatesDirectory)
        pendingUpdateDownload = PendingUpdateDownload(
            update: update,
            updatesDirectory: updatesDirectory,
            destinationURL: destinationURL
        )
        showUpdateProgressWindow(for: update)

        updateDownloadSession?.invalidateAndCancel()
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        updateDownloadSession = session
        let task = session.downloadTask(with: update.downloadURL)
        updateProgressTask = task
        task.resume()
    }

    private func updateDownloadsDirectory() -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return cachesDirectory.appendingPathComponent("Updates", isDirectory: true)
    }

    private func makeUpdateProgressWindow(for update: AppUpdateInfo) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 150),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "正在更新 \(AppBranding.displayName)"
        window.isReleasedWhenClosed = false
        window.level = .floating

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "正在下载 \(AppBranding.displayName) \(update.version)")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = NSTextField(labelWithString: "正在连接更新服务器…")
        detailLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        let progressIndicator = NSProgressIndicator()
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        progressIndicator.isIndeterminate = true
        progressIndicator.style = .bar
        progressIndicator.controlSize = .regular
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.startAnimation(nil)

        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(progressIndicator)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),

            progressIndicator.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            progressIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 12),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])

        window.contentView = contentView
        updateProgressIndicator = progressIndicator
        updateProgressLabel = detailLabel
        return window
    }

    private func showUpdateProgressWindow(for update: AppUpdateInfo) {
        let progressWindow = updateProgressWindow ?? makeUpdateProgressWindow(for: update)
        updateProgressWindow = progressWindow
        updateProgressIndicator?.isIndeterminate = true
        updateProgressIndicator?.doubleValue = 0
        updateProgressIndicator?.startAnimation(nil)
        updateProgressLabel?.stringValue = "正在连接更新服务器…"
        progressWindow.center()
        progressWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateDownloadProgress(totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else {
            updateProgressIndicator?.isIndeterminate = true
            updateProgressIndicator?.startAnimation(nil)
            updateProgressLabel?.stringValue = "正在下载，等待服务器返回文件大小…"
            return
        }

        let percent = min(100, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100))
        updateProgressIndicator?.stopAnimation(nil)
        updateProgressIndicator?.isIndeterminate = false
        updateProgressIndicator?.doubleValue = percent
        updateProgressLabel?.stringValue = "正在下载：\(Int(percent.rounded()))%"
    }

    private func updateDownloadPreparingToInstall() {
        updateProgressIndicator?.stopAnimation(nil)
        updateProgressIndicator?.isIndeterminate = false
        updateProgressIndicator?.doubleValue = 100
        updateProgressLabel?.stringValue = "准备安装…"
    }

    private func closeUpdateProgressWindow() {
        updateProgressWindow?.orderOut(nil)
        updateProgressWindow = nil
        updateProgressIndicator = nil
        updateProgressLabel = nil
    }

    private func completeUpdateDownload(from temporaryURL: URL) {
        guard let pendingUpdateDownload else {
            showUpdateDownloadFailed("没有找到更新下载任务。")
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: pendingUpdateDownload.updatesDirectory,
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: pendingUpdateDownload.destinationURL.path) {
                try FileManager.default.removeItem(at: pendingUpdateDownload.destinationURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: pendingUpdateDownload.destinationURL)

            updateDownloadPreparingToInstall()
            installAndRelaunchUpdate(from: pendingUpdateDownload.destinationURL)
        } catch {
            closeUpdateProgressWindow()
            showUpdateDownloadFailed(error.localizedDescription)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        updateDownloadProgress(
            totalBytesWritten: totalBytesWritten,
            totalBytesExpectedToWrite: totalBytesExpectedToWrite
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        completeUpdateDownload(from: location)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else {
            return
        }

        closeUpdateProgressWindow()
        showUpdateDownloadFailed(error.localizedDescription)
    }

    private func installAndRelaunchUpdate(from dmgURL: URL) {
        let installPath = Bundle.main.bundleURL.path
        let script = UpdateInstallerScript.makeScript(
            dmgPath: dmgURL.path,
            appName: AppBranding.bundleAppName,
            installPath: installPath
        )
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tocreate-install-update-\(UUID().uuidString).sh")

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]
            try process.run()

            NSApp.terminate(nil)
        } catch {
            showUpdateDownloadFailed("更新已下载，但自动安装失败：\(error.localizedDescription)\n\n\(UpdateGatekeeperFallback.message)\n\n安装包位置：\(dmgURL.path)")
            NSWorkspace.shared.open(dmgURL)
        }
    }

    private func showUpdateDownloadFailed(_ message: String) {
        pendingUpdateDownload = nil
        updateProgressTask = nil
        updateDownloadSession?.invalidateAndCancel()
        updateDownloadSession = nil
        closeUpdateProgressWindow()
        let alert = NSAlert()
        alert.messageText = "下载更新失败"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
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

    private func currentBuildNumber() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
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
        scheduleMetricsRefreshAfterPageLoad()
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

      function firstNumber(values) {
        for (const value of values) {
          const number = numberValue(value);
          if (number !== null) return number;
        }
        return null;
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

      function moneyValue(value) {
        if (!value) return null;
        const number = Number(String(value).replace(/[$,\\s]/g, ''));
        return Number.isFinite(number) ? number : null;
      }

      function formatPlatform(value) {
        const text = String(value || '').trim();
        if (!text) return null;
        if (text.toLowerCase() === 'openai') return 'OpenAI';
        if (text.toLowerCase() === 'anthropic') return 'Anthropic';
        if (text.toLowerCase() === 'gemini') return 'Gemini';
        return text;
      }

      function formatSubscriptionStatus(value) {
        const text = String(value || '').toLowerCase();
        if (text === 'active') return '有效';
        if (text === 'expired') return '已过期';
        if (text === 'suspended' || text === 'disabled') return '已暂停';
        return value ? String(value) : null;
      }

      function formatDate(value) {
        if (!value) return null;
        const date = new Date(value);
        if (!Number.isFinite(date.getTime())) return null;
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return year + '/' + month + '/' + day;
      }

      function expiryText(value) {
        if (!value) return null;
        const date = new Date(value);
        if (!Number.isFinite(date.getTime())) return null;
        const days = Math.ceil((date.getTime() - Date.now()) / (24 * 60 * 60 * 1000));
        if (days < 0) return '已过期 (' + formatDate(value) + ')';
        return '剩余 ' + days + ' 天 (' + formatDate(value) + ')';
      }

      function resetTextFromWindow(start, hours) {
        if (!start) return null;
        const startDate = new Date(start);
        if (!Number.isFinite(startDate.getTime())) return null;
        const target = new Date(startDate.getTime() + hours * 60 * 60 * 1000);
        const minutes = Math.floor((target.getTime() - Date.now()) / (60 * 1000));
        if (!Number.isFinite(minutes) || minutes <= 0) return null;
        const days = Math.floor(minutes / (24 * 60));
        const remainingHours = Math.floor((minutes % (24 * 60)) / 60);
        const remainingMinutes = minutes % 60;
        if (days > 0) return days + 'd ' + remainingHours + 'h 后重置';
        if (remainingHours > 0) return remainingHours + 'h ' + remainingMinutes + 'm 后重置';
        return remainingMinutes + 'm 后重置';
      }

      function subscriptionFromAPI(value) {
        const subscriptions = listFrom(value);
        if (!subscriptions.length) return null;
        const subscription = subscriptions.find((item) => String(item && item.status).toLowerCase() === 'active') || subscriptions[0];
        if (!subscription) return null;
        const group = subscription.group || {};

        const daily = {
          used: numberValue(subscription.daily_usage_usd),
          limit: numberValue(group.daily_limit_usd),
          resetText: resetTextFromWindow(subscription.daily_window_start, 24)
        };
        const weekly = {
          used: numberValue(subscription.weekly_usage_usd),
          limit: numberValue(group.weekly_limit_usd),
          resetText: resetTextFromWindow(subscription.weekly_window_start, 168)
        };
        const monthly = {
          used: numberValue(subscription.monthly_usage_usd),
          limit: numberValue(group.monthly_limit_usd),
          resetText: resetTextFromWindow(subscription.monthly_window_start, 720)
        };
        const hasQuota = [daily, weekly, monthly].some((item) => item.used !== null || item.limit !== null);
        if (!hasQuota) return null;

        return {
          name: group.name || null,
          provider: formatPlatform(group.platform),
          status: formatSubscriptionStatus(subscription.status),
          expiryText: expiryText(subscription.expires_at),
          daily,
          weekly,
          monthly
        };
      }

      function subscriptionFromDOM() {
        const text = (document.body && document.body.innerText) || '';
        if (!text) return null;
        const lines = text.split(/\\n+/).map((line) => line.trim()).filter(Boolean);
        const moneyPattern = /\\$\\s*([0-9,]+(?:\\.[0-9]+)?)\\s*\\/\\s*\\$\\s*([0-9,]+(?:\\.[0-9]+)?)/;
        const providerPattern = /OpenAI|Claude|Gemini|Azure|Anthropic/i;
        const statusPattern = /有效|无效|过期|暂停|失效/;

        function firstLineMatching(pattern) {
          return lines.find((line) => pattern.test(line)) || null;
        }

        function compactWhitespace(value) {
          return String(value || '').replace(/\\s+/g, ' ').trim();
        }

        function lineMetric(label) {
          const index = lines.findIndex((line) => line === label || line.includes(label));
          if (index < 0) return { used: null, limit: null, resetText: null };

          const windowLines = lines.slice(index, index + 12);
          const moneyLine = windowLines.find((line) => moneyPattern.test(line));
          const moneyMatch = moneyLine ? moneyLine.match(moneyPattern) : null;
          const resetLine = windowLines.find((line) => /后重置/.test(line));

          return {
            used: moneyMatch ? moneyValue(moneyMatch[1]) : null,
            limit: moneyMatch ? moneyValue(moneyMatch[2]) : null,
            resetText: resetLine ? compactWhitespace(resetLine) : null
          };
        }

        function regexMetric(label) {
          const pattern = new RegExp(label + '[\\\\s\\\\S]{0,240}?\\\\$\\\\s*([0-9,]+(?:\\\\.[0-9]+)?)\\\\s*\\\\/\\\\s*\\\\$\\\\s*([0-9,]+(?:\\\\.[0-9]+)?)([\\\\s\\\\S]{0,100}?((?:\\\\d+d\\\\s*)?(?:\\\\d+h\\\\s*)?(?:\\\\d+m\\\\s*)?后重置))?', 'i');
          const match = text.match(pattern);
          if (!match) return { used: null, limit: null, resetText: null };
          return {
            used: moneyValue(match[1]),
            limit: moneyValue(match[2]),
            resetText: match[4] ? compactWhitespace(match[4]) : null
          };
        }

        function metric(label) {
          const byLine = lineMetric(label);
          if (byLine.used !== null || byLine.limit !== null) return byLine;
          return regexMetric(label);
        }

        const daily = metric('每日');
        const weekly = metric('每周');
        const monthly = metric('每月');
        const hasQuota = [daily, weekly, monthly].some((item) => item.used !== null || item.limit !== null);
        if (!hasQuota) return null;

        const headerLine = lines.find((line) => providerPattern.test(line) && statusPattern.test(line)) || null;
        const providerLine = firstLineMatching(providerPattern);
        const providerMatch = (headerLine || providerLine || '').match(providerPattern);
        const statusMatch = (headerLine || firstLineMatching(statusPattern) || '').match(statusPattern);
        const expiryLine = firstLineMatching(/剩余\\s*\\d+\\s*天|到期|\\d{4}[/-]\\d{1,2}[/-]\\d{1,2}/);
        const nameFromHeader = headerLine && providerMatch ? headerLine.slice(0, providerMatch.index).replace(/[•·]/g, ' ').trim() : null;
        const providerIndex = providerLine ? lines.indexOf(providerLine) : -1;
        const previousLine = providerIndex > 0 ? lines[providerIndex - 1] : null;
        const nameLine = nameFromHeader || previousLine;

        return {
          name: nameLine && !/到期时间|每日|每周|每月/.test(nameLine) ? nameLine : null,
          provider: providerMatch ? providerMatch[0] : providerLine,
          status: statusMatch ? statusMatch[0] : null,
          expiryText: expiryLine,
          daily,
          weekly,
          monthly
        };
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
        const [me, stats, monitorPayload, apiKeysPayload, subscriptionPayload] = await Promise.all([
          api('/auth/me'),
          api('/usage/dashboard/stats'),
          optionalApi(['/channel-monitors']),
          optionalApi([
            '/token/?p=0&size=1',
            '/tokens?p=0&size=1',
            '/keys?p=0&size=1',
            '/api-keys?p=0&size=1'
          ]),
          optionalApi(['/subscriptions/active'])
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
          balance: firstNumber([
            me && me.balance,
            me && me.user && me.user.balance,
            me && me.wallet && me.wallet.balance,
            me && me.account && me.account.balance,
            stats && stats.balance,
            stats && stats.remaining_balance,
            stats && stats.remainingBalance
          ]),
          todayRequests: numberValue(stats && stats.today_requests),
          todayCost: numberValue(stats && (stats.today_actual_cost ?? stats.today_cost)),
          todayTokens: numberValue(stats && stats.today_tokens),
          channels: channelCounts,
          apiKeyCount: countFrom(apiKeysPayload),
          subscription: subscriptionFromAPI(subscriptionPayload) || subscriptionFromDOM()
        }));
      } catch (error) {
        window.webkit.messageHandlers.liheMetrics.postMessage(JSON.stringify({ error: error && error.message ? error.message : String(error) }));
      }
      }
      run();
    })();
    """
}
