# ToCreate WidgetKit Desktop Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 ToCreate 增加真正的 macOS WidgetKit 桌面小组件，展示 API 连通状态、余额、今日用量、API 密钥数量和更新时间。

**Architecture:** 主 App 继续负责登录、WebView、API 数据采集和菜单栏显示；每次刷新成功后写入一个共享 `WidgetSnapshot`。Widget Extension 不登录、不请求业务 API，只读取共享快照并用 SwiftUI 展示，小组件点击后打开 ToCreate 主 App。

**Tech Stack:** Swift 6、AppKit、WebKit、SwiftUI、WidgetKit、UserDefaults App Group、XCTest、Xcode project、DMG packaging。

**Implementation status on 2026-06-24:** Tasks 0–8 are implemented and committed on `feature/tocreate-widgetkit`. `swift test` passes, `xcodebuild` builds the app/widget targets, and `scripts/package_app.sh` creates `dist/ToCreate.dmg` with `ToCreateWidget.appex` embedded. Task 9 was verified by inspecting the packaged DMG without overwriting the currently installed `/Applications/ToCreate.app`; final widget visibility still needs a manual Finder/Desktop check after the user installs the DMG.

---

## Current State And Constraints

- Current repo path: `/Users/lihe/Desktop/LiheAPI-Mac`
- Current app executable target: `LiheAPI`
- User-facing app name: `ToCreate`
- Current bundle identifier: `chat.lihe.api.mac`
- Current project type: Swift Package only; no `.xcodeproj`
- Existing package script uses `swift build` and manually assembles `ToCreate.app`
- WidgetKit requires an app extension target, which requires an Xcode project for realistic local testing and packaging
- Current working tree has unrelated menu/balance bugfix changes in:
  - `Sources/LiheAPI/LiheAPIApp.swift`
  - `Sources/LiheAPI/NativeFeatures.swift`
  - `Tests/LiheAPITests/NativeFeaturesTests.swift`

## Proposed File Structure

Create:

- `Shared/WidgetSnapshot.swift`  
  Snapshot model, status enum, formatting model for widget display.

- `Shared/WidgetSnapshotStore.swift`  
  Store for reading/writing snapshots from shared `UserDefaults`.

- `ToCreateWidget/ToCreateWidgetBundle.swift`  
  Widget bundle entry point.

- `ToCreateWidget/ToCreateWidget.swift`  
  Timeline provider and widget configuration.

- `ToCreateWidget/ToCreateWidgetView.swift`  
  SwiftUI view for small/medium/large widget layouts.

- `ToCreateWidget/Info.plist`  
  Widget extension Info.plist.

- `Resources/ToCreate.entitlements`  
  App entitlements with App Group.

- `ToCreateWidget/ToCreateWidget.entitlements`  
  Widget extension entitlements with the same App Group.

- `ToCreate.xcodeproj/project.pbxproj`  
  Xcode project containing the main app target and widget extension target.

Modify:

- `Package.swift`  
  Include `Shared` sources in the Swift Package target and tests so shared model/store can be tested with `swift test`.

- `Sources/LiheAPI/LiheAPIApp.swift`  
  Write widget snapshot after metrics refresh and handle `tocreate://open`.

- `Sources/LiheAPI/NativeFeatures.swift`  
  Reuse existing formatters from widget-facing display model if helpful.

- `Tests/LiheAPITests/NativeFeaturesTests.swift`  
  Add tests for snapshot formatting and app integration hooks.

- `scripts/package_app.sh`  
  Switch from pure `swift build` packaging to Xcode build packaging when `ToCreate.xcodeproj` exists.

- `scripts/release.sh`  
  Keep existing release flow, but ensure it calls the updated packaging script and validates the built `.app`.

## App Group

Use this group identifier consistently:

```text
group.chat.lihe.api.mac
```

Use this UserDefaults suite:

```swift
UserDefaults(suiteName: "group.chat.lihe.api.mac")
```

Use this snapshot key:

```swift
"widgetSnapshot"
```

If App Group is unavailable under ad-hoc signing during local testing, `WidgetSnapshotStore` must gracefully fall back to `.standard` so unit tests and development builds remain usable. Formal distribution should later use an Apple Developer account and real App Group capability.

---

### Task 0: Commit Or Isolate Current Balance/Menu Fixes

**Files:**

- Existing modified files:
  - `Sources/LiheAPI/LiheAPIApp.swift`
  - `Sources/LiheAPI/NativeFeatures.swift`
  - `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Inspect the current unrelated diff**

Run:

```bash
git status --short
git diff -- Sources/LiheAPI/LiheAPIApp.swift Sources/LiheAPI/NativeFeatures.swift Tests/LiheAPITests/NativeFeaturesTests.swift
```

Expected: Only the balance/menu fixes from the previous work are present.

- [ ] **Step 2: Verify the current app tests before committing**

Run:

```bash
swift test
```

Expected: all tests pass, currently around `42` tests with `0` failures.

- [ ] **Step 3: Commit the unrelated fix separately**

Run:

```bash
git add Sources/LiheAPI/LiheAPIApp.swift Sources/LiheAPI/NativeFeatures.swift Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "fix: keep cached balance in status menu"
```

Expected: one commit containing only the balance/menu fix. Widget work starts from a clean tree.

- [ ] **Step 4: Confirm clean tree except ignored build artifacts**

Run:

```bash
git status --short
```

Expected: no tracked modified files.

---

### Task 1: Add Widget Snapshot Model And Display Formatting

**Files:**

- Create: `Shared/WidgetSnapshot.swift`
- Modify: `Package.swift`
- Modify: `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Write the failing tests**

Append these tests to `Tests/LiheAPITests/NativeFeaturesTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter NativeFeaturesTests/testWidgetSnapshotCodableRoundTrip
```

Expected: fail because `WidgetSnapshot` is not defined.

- [ ] **Step 3: Create the model**

Create `Shared/WidgetSnapshot.swift`:

```swift
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
        case .reachable:
            return "●"
        case .unreachable:
            return "●"
        case .unknown:
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
```

- [ ] **Step 4: Include `Shared` in the Swift Package**

Modify `Package.swift` so the executable target includes both app sources and shared sources:

```swift
.executableTarget(
    name: "LiheAPI",
    path: ".",
    sources: [
        "Sources/LiheAPI",
        "Shared"
    ],
    resources: []
),
```

Keep the test target unchanged:

```swift
.testTarget(name: "LiheAPITests", dependencies: ["LiheAPI"])
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter NativeFeaturesTests/testWidgetSnapshotCodableRoundTrip
swift test --filter NativeFeaturesTests/testWidgetSnapshotDisplayHonorsPrivacyMode
swift test --filter NativeFeaturesTests/testWidgetSnapshotDisplayDetectsStaleData
```

Expected: all three pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add Package.swift Shared/WidgetSnapshot.swift Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "feat: add widget snapshot model"
```

---

### Task 2: Add Shared Snapshot Store

**Files:**

- Create: `Shared/WidgetSnapshotStore.swift`
- Modify: `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Write failing store tests**

Append:

```swift
func testWidgetSnapshotStoreSavesAndLoadsSnapshot() throws {
    let defaults = UserDefaults(suiteName: "WidgetSnapshotStoreTests-\(UUID().uuidString)")!
    let store = WidgetSnapshotStore(defaults: defaults)
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
}

func testWidgetSnapshotStoreReturnsNilWhenEmpty() throws {
    let defaults = UserDefaults(suiteName: "WidgetSnapshotStoreTests-\(UUID().uuidString)")!
    let store = WidgetSnapshotStore(defaults: defaults)

    XCTAssertNil(try store.load())
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
swift test --filter NativeFeaturesTests/testWidgetSnapshotStoreSavesAndLoadsSnapshot
```

Expected: fail because `WidgetSnapshotStore` is not defined.

- [ ] **Step 3: Create store**

Create `Shared/WidgetSnapshotStore.swift`:

```swift
import Foundation

enum WidgetSnapshotStoreError: Error, Equatable {
    case encodingFailed
}

struct WidgetSnapshotStore {
    static let appGroupIdentifier = "group.chat.lihe.api.mac"
    static let snapshotKey = "widgetSnapshot"

    let defaults: UserDefaults

    init(defaults: UserDefaults = WidgetSnapshotStore.sharedDefaults()) {
        self.defaults = defaults
    }

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    func save(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: Self.snapshotKey)
    }

    func load() throws -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: Self.snapshotKey) else {
            return nil
        }
        return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
```

- [ ] **Step 4: Run store tests**

Run:

```bash
swift test --filter NativeFeaturesTests/testWidgetSnapshotStoreSavesAndLoadsSnapshot
swift test --filter NativeFeaturesTests/testWidgetSnapshotStoreReturnsNilWhenEmpty
```

Expected: both pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add Shared/WidgetSnapshotStore.swift Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "feat: add widget snapshot store"
```

---

### Task 3: Write Snapshots From Main App Metrics Refresh

**Files:**

- Modify: `Sources/LiheAPI/LiheAPIApp.swift`
- Modify: `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Write source-level integration test**

Append:

```swift
func testMainAppWritesWidgetSnapshotAfterMetricsRefresh() throws {
    let appSource = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/Sources/LiheAPI/LiheAPIApp.swift")

    XCTAssertTrue(appSource.contains("private let widgetSnapshotStore = WidgetSnapshotStore()"))
    XCTAssertTrue(appSource.contains("writeWidgetSnapshot("))
    XCTAssertTrue(appSource.contains("WidgetSnapshot("))
    XCTAssertTrue(appSource.contains("privacyModeEnabled: preferences.privacyModeEnabled"))
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
swift test --filter NativeFeaturesTests/testMainAppWritesWidgetSnapshotAfterMetricsRefresh
```

Expected: fail because app does not write widget snapshot yet.

- [ ] **Step 3: Add store property**

In `Sources/LiheAPI/LiheAPIApp.swift`, near the other private properties, add:

```swift
private let widgetSnapshotStore = WidgetSnapshotStore()
```

- [ ] **Step 4: Add snapshot writer**

Add this helper near `handleMetricsPayload`:

```swift
private func writeWidgetSnapshot(
    apiStatus: WidgetAPIStatus,
    balance: Double?,
    todayRequests: Double?,
    todayTokens: Double?,
    todayCost: Double?,
    apiKeyCount: Double?,
    updatedAt: Date
) {
    let snapshot = WidgetSnapshot(
        apiStatus: apiStatus,
        balance: balance,
        todayRequests: todayRequests,
        todayTokens: todayTokens,
        todayCost: todayCost,
        apiKeyCount: apiKeyCount,
        updatedAt: updatedAt,
        privacyModeEnabled: preferences.privacyModeEnabled
    )

    do {
        try widgetSnapshotStore.save(snapshot)
    } catch {
        NSLog("ToCreate widget snapshot save failed: %@", error.localizedDescription)
    }
}
```

- [ ] **Step 5: Call writer on successful metrics payload**

In `handleMetricsPayload(_:)`, after computing `displayBalance`, `todayRequests`, `todayTokens`, `todayCost`, `apiKeyCount`, add:

```swift
let updatedAt = Date()
writeWidgetSnapshot(
    apiStatus: .reachable,
    balance: displayBalance,
    todayRequests: todayRequests,
    todayTokens: todayTokens,
    todayCost: todayCost,
    apiKeyCount: apiKeyCount,
    updatedAt: updatedAt
)
setUpdatedAtMenuTitle(metricTitle("更新于", DateFormatter.localizedString(from: updatedAt, dateStyle: .none, timeStyle: .medium)))
```

Replace the existing `setUpdatedAtMenuTitle(metricTitle("更新于", DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)))` line with the `updatedAt` version above.

- [ ] **Step 6: Write unreachable snapshot on error state**

In the `if let errorMessage = object["error"] as? String` branch, before `return`, add:

```swift
writeWidgetSnapshot(
    apiStatus: .unreachable,
    balance: lastSuccessfulBalance,
    todayRequests: nil,
    todayTokens: nil,
    todayCost: nil,
    apiKeyCount: nil,
    updatedAt: Date()
)
```

- [ ] **Step 7: Run tests**

Run:

```bash
swift test --filter NativeFeaturesTests/testMainAppWritesWidgetSnapshotAfterMetricsRefresh
swift test
```

Expected: all pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/LiheAPI/LiheAPIApp.swift Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "feat: write widget snapshots from app metrics"
```

---

### Task 4: Add URL Scheme For Widget Tap-To-Open

**Files:**

- Modify: `Resources/Info.plist`
- Modify: `Sources/LiheAPI/LiheAPIApp.swift`
- Modify: `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Write tests**

Append:

```swift
func testAppRegistersToCreateURLSchemeForWidgetOpen() throws {
    let plist = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/Resources/Info.plist")
    let appSource = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/Sources/LiheAPI/LiheAPIApp.swift")

    XCTAssertTrue(plist.contains("<string>tocreate</string>"))
    XCTAssertTrue(appSource.contains("func application(_ application: NSApplication, open urls: [URL])"))
    XCTAssertTrue(appSource.contains("showWindow()"))
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
swift test --filter NativeFeaturesTests/testAppRegistersToCreateURLSchemeForWidgetOpen
```

Expected: fail because URL scheme is not registered.

- [ ] **Step 3: Add URL scheme to plist**

In `Resources/Info.plist`, before `</dict>`, add:

```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>ToCreate</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>tocreate</string>
			</array>
		</dict>
	</array>
```

- [ ] **Step 4: Handle URL in AppDelegate**

Add to `LiheAPIApp`:

```swift
func application(_ application: NSApplication, open urls: [URL]) {
    guard urls.contains(where: { $0.scheme == "tocreate" }) else {
        return
    }
    showWindow()
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter NativeFeaturesTests/testAppRegistersToCreateURLSchemeForWidgetOpen
swift test
```

Expected: all pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add Resources/Info.plist Sources/LiheAPI/LiheAPIApp.swift Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "feat: add widget open URL scheme"
```

---

### Task 5: Add Widget SwiftUI Code

**Files:**

- Create: `ToCreateWidget/ToCreateWidgetBundle.swift`
- Create: `ToCreateWidget/ToCreateWidget.swift`
- Create: `ToCreateWidget/ToCreateWidgetView.swift`
- Create: `ToCreateWidget/Info.plist`
- Modify: `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Write source existence test**

Append:

```swift
func testWidgetSourceFilesDefineWidgetKitExtension() throws {
    let widget = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/ToCreateWidget/ToCreateWidget.swift")
    let view = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/ToCreateWidget/ToCreateWidgetView.swift")
    let bundle = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/ToCreateWidget/ToCreateWidgetBundle.swift")

    XCTAssertTrue(widget.contains("import WidgetKit"))
    XCTAssertTrue(widget.contains("StaticConfiguration"))
    XCTAssertTrue(widget.contains("WidgetSnapshotStore"))
    XCTAssertTrue(widget.contains("TimelineProvider"))
    XCTAssertTrue(view.contains("@Environment(\\.widgetFamily)"))
    XCTAssertTrue(view.contains("widgetURL(URL(string: \"tocreate://open\"))"))
    XCTAssertTrue(bundle.contains("@main"))
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
swift test --filter NativeFeaturesTests/testWidgetSourceFilesDefineWidgetKitExtension
```

Expected: fail because files do not exist.

- [ ] **Step 3: Create bundle file**

Create `ToCreateWidget/ToCreateWidgetBundle.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct ToCreateWidgetBundle: WidgetBundle {
    var body: some Widget {
        ToCreateWidget()
    }
}
```

- [ ] **Step 4: Create widget timeline file**

Create `ToCreateWidget/ToCreateWidget.swift`:

```swift
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
```

- [ ] **Step 5: Create widget view file**

Create `ToCreateWidget/ToCreateWidgetView.swift`:

```swift
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
        .containerBackground(.background, for: .widget)
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
```

- [ ] **Step 6: Create widget Info.plist**

Create `ToCreateWidget/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
```

- [ ] **Step 7: Run source test**

Run:

```bash
swift test --filter NativeFeaturesTests/testWidgetSourceFilesDefineWidgetKitExtension
```

Expected: pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add ToCreateWidget Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "feat: add WidgetKit source files"
```

---

### Task 6: Add Entitlements

**Files:**

- Create: `Resources/ToCreate.entitlements`
- Create: `ToCreateWidget/ToCreateWidget.entitlements`
- Modify: `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Write entitlement tests**

Append:

```swift
func testAppAndWidgetEntitlementsUseSameAppGroup() throws {
    let appEntitlements = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/Resources/ToCreate.entitlements")
    let widgetEntitlements = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/ToCreateWidget/ToCreateWidget.entitlements")

    XCTAssertTrue(appEntitlements.contains("group.chat.lihe.api.mac"))
    XCTAssertTrue(widgetEntitlements.contains("group.chat.lihe.api.mac"))
    XCTAssertTrue(appEntitlements.contains("com.apple.security.application-groups"))
    XCTAssertTrue(widgetEntitlements.contains("com.apple.security.application-groups"))
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
swift test --filter NativeFeaturesTests/testAppAndWidgetEntitlementsUseSameAppGroup
```

Expected: fail because files do not exist.

- [ ] **Step 3: Create app entitlements**

Create `Resources/ToCreate.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.chat.lihe.api.mac</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: Create widget entitlements**

Create `ToCreateWidget/ToCreateWidget.entitlements` with the same content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.chat.lihe.api.mac</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter NativeFeaturesTests/testAppAndWidgetEntitlementsUseSameAppGroup
swift test
```

Expected: all pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add Resources/ToCreate.entitlements ToCreateWidget/ToCreateWidget.entitlements Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "feat: add app group entitlements"
```

---

### Task 7: Add Xcode Project With App And Widget Targets

**Files:**

- Create: `ToCreate.xcodeproj/project.pbxproj`
- Modify: `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Write project structure test**

Append:

```swift
func testXcodeProjectDefinesAppAndWidgetTargets() throws {
    let project = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/ToCreate.xcodeproj/project.pbxproj")

    XCTAssertTrue(project.contains("ToCreate"))
    XCTAssertTrue(project.contains("ToCreateWidgetExtension"))
    XCTAssertTrue(project.contains("com.apple.product-type.application"))
    XCTAssertTrue(project.contains("com.apple.product-type.app-extension"))
    XCTAssertTrue(project.contains("ToCreateWidget.appex"))
    XCTAssertTrue(project.contains("CODE_SIGN_ENTITLEMENTS = Resources/ToCreate.entitlements"))
    XCTAssertTrue(project.contains("CODE_SIGN_ENTITLEMENTS = ToCreateWidget/ToCreateWidget.entitlements"))
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
swift test --filter NativeFeaturesTests/testXcodeProjectDefinesAppAndWidgetTargets
```

Expected: fail because `ToCreate.xcodeproj` does not exist.

- [ ] **Step 3: Create a minimal Xcode project**

Create `ToCreate.xcodeproj/project.pbxproj` with:

- One macOS application target named `ToCreate`
- One WidgetKit app extension target named `ToCreateWidgetExtension`
- App source files:
  - `Sources/LiheAPI/LiheAPIApp.swift`
  - `Sources/LiheAPI/LauncherView.swift`
  - `Sources/LiheAPI/NativeFeatures.swift`
  - `Sources/LiheAPI/URLPolicy.swift`
  - `Sources/LiheAPI/WebView.swift`
  - `Shared/WidgetSnapshot.swift`
  - `Shared/WidgetSnapshotStore.swift`
- Widget source files:
  - `ToCreateWidget/ToCreateWidgetBundle.swift`
  - `ToCreateWidget/ToCreateWidget.swift`
  - `ToCreateWidget/ToCreateWidgetView.swift`
  - `Shared/WidgetSnapshot.swift`
  - `Shared/WidgetSnapshotStore.swift`
- App resources:
  - `Resources/Info.plist`
  - `Resources/AppIconSource.png`
- Widget Info.plist:
  - `ToCreateWidget/Info.plist`
- Copy Files build phase embedding `ToCreateWidgetExtension.appex` inside the app.

Use these build settings:

```text
PRODUCT_NAME = ToCreate
PRODUCT_BUNDLE_IDENTIFIER = chat.lihe.api.mac
MACOSX_DEPLOYMENT_TARGET = 13.0
SWIFT_VERSION = 6.0
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = -
CODE_SIGN_ENTITLEMENTS = Resources/ToCreate.entitlements
```

Widget target:

```text
PRODUCT_NAME = ToCreateWidget
PRODUCT_BUNDLE_IDENTIFIER = chat.lihe.api.mac.widget
WRAPPER_EXTENSION = appex
MACOSX_DEPLOYMENT_TARGET = 13.0
SWIFT_VERSION = 6.0
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = -
CODE_SIGN_ENTITLEMENTS = ToCreateWidget/ToCreateWidget.entitlements
```

- [ ] **Step 4: Verify Xcode project is readable**

Run:

```bash
xcodebuild -list -project ToCreate.xcodeproj
```

Expected output includes:

```text
Targets:
    ToCreate
    ToCreateWidgetExtension
```

- [ ] **Step 5: Build app and widget with Xcode**

Run:

```bash
xcodebuild -project ToCreate.xcodeproj -scheme ToCreate -configuration Release -derivedDataPath DerivedData CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES build
```

Expected: build succeeds and produces `ToCreate.app` containing `Contents/PlugIns/ToCreateWidget.appex` or `Contents/PlugIns/ToCreateWidgetExtension.appex`.

- [ ] **Step 6: Run project structure test and full tests**

Run:

```bash
swift test --filter NativeFeaturesTests/testXcodeProjectDefinesAppAndWidgetTargets
swift test
```

Expected: all pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add ToCreate.xcodeproj Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "build: add Xcode project with widget target"
```

---

### Task 8: Update Packaging Script For Widget-Aware App Build

**Files:**

- Modify: `scripts/package_app.sh`
- Modify: `Tests/LiheAPITests/NativeFeaturesTests.swift`

- [ ] **Step 1: Write packaging test**

Append:

```swift
func testPackageScriptBuildsXcodeProjectWhenWidgetIsPresent() throws {
    let script = try String(contentsOfFile: "/Users/lihe/Desktop/LiheAPI-Mac/scripts/package_app.sh")

    XCTAssertTrue(script.contains("xcodebuild -project ToCreate.xcodeproj"))
    XCTAssertTrue(script.contains("Contents/PlugIns"))
    XCTAssertTrue(script.contains("ToCreateWidget"))
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
swift test --filter NativeFeaturesTests/testPackageScriptBuildsXcodeProjectWhenWidgetIsPresent
```

Expected: fail because script still uses only `swift build`.

- [ ] **Step 3: Update packaging script**

Change `scripts/package_app.sh` to:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/tocreate-package.XXXXXX")"
STAGING="$WORK/dmg"
DMG="$WORK/ToCreate.dmg"
OUTPUT_DMG="$DIST/ToCreate.dmg"
DERIVED_DATA="$WORK/DerivedData"
APP="$WORK/ToCreate.app"

trap 'rm -rf "$WORK"' EXIT

cd "$ROOT"

rm -rf "$DIST"
mkdir -p "$DIST" "$STAGING"

if [ -d "$ROOT/ToCreate.xcodeproj" ]; then
  xcodebuild \
    -project "$ROOT/ToCreate.xcodeproj" \
    -scheme ToCreate \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_ALLOWED=YES \
    build

  BUILT_APP="$(find "$DERIVED_DATA/Build/Products/Release" -maxdepth 1 -name 'ToCreate.app' -type d | head -n 1)"
  if [ -z "$BUILT_APP" ]; then
    echo "ToCreate.app was not produced by xcodebuild" >&2
    exit 1
  fi
  cp -R "$BUILT_APP" "$APP"
else
  swift build -c release
  BIN_DIR="$(swift build -c release --show-bin-path)"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  cp "$BIN_DIR/LiheAPI" "$APP/Contents/MacOS/LiheAPI"
  cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
fi

ICONSET="$WORK/AppIcon.iconset"
ICON="$WORK/AppIcon.icns"
swift "$ROOT/scripts/generate_icon.swift" "$ICONSET" "$ROOT/Resources/AppIconSource.png"
iconutil --convert icns "$ICONSET" --output "$ICON"
mkdir -p "$APP/Contents/Resources"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

if [ -d "$APP/Contents/PlugIns" ]; then
  find "$APP/Contents/PlugIns" -name '*.appex' -maxdepth 1 -print
fi

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
    -volname "ToCreate" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"
hdiutil verify "$DMG"

mv "$DMG" "$OUTPUT_DMG"

echo "DMG: $OUTPUT_DMG"
```

- [ ] **Step 4: Run packaging test**

Run:

```bash
swift test --filter NativeFeaturesTests/testPackageScriptBuildsXcodeProjectWhenWidgetIsPresent
```

Expected: pass.

- [ ] **Step 5: Build DMG**

Run:

```bash
./scripts/package_app.sh
```

Expected:

- Script exits `0`
- `dist/ToCreate.dmg` exists
- output includes a `ToCreateWidget` `.appex` path when Xcode project is present

- [ ] **Step 6: Verify packaged app contains widget extension**

Run:

```bash
rm -rf /tmp/tocreate-widget-verify
mkdir -p /tmp/tocreate-widget-verify
hdiutil attach dist/ToCreate.dmg -mountpoint /tmp/tocreate-widget-verify -nobrowse -quiet
find /tmp/tocreate-widget-verify/ToCreate.app/Contents/PlugIns -maxdepth 2 -type d -name '*.appex' -print
hdiutil detach /tmp/tocreate-widget-verify -quiet
```

Expected: prints a `.appex` path.

- [ ] **Step 7: Commit**

Run:

```bash
git add scripts/package_app.sh Tests/LiheAPITests/NativeFeaturesTests.swift
git commit -m "build: package app with widget extension"
```

---

### Task 9: Local Install Verification

**Files:**

- No source file changes expected.

- [ ] **Step 1: Install packaged app**

Run:

```bash
pkill -x LiheAPI || true
rm -rf /tmp/tocreate-widget-install
mkdir -p /tmp/tocreate-widget-install
hdiutil attach dist/ToCreate.dmg -mountpoint /tmp/tocreate-widget-install -nobrowse -quiet
rm -rf /Applications/ToCreate.app
ditto /tmp/tocreate-widget-install/ToCreate.app /Applications/ToCreate.app
hdiutil detach /tmp/tocreate-widget-install -quiet
```

Expected: app copied to `/Applications/ToCreate.app`.

- [ ] **Step 2: Verify code signature and extension existence**

Run:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/ToCreate.app
find /Applications/ToCreate.app/Contents/PlugIns -maxdepth 2 -type d -name '*.appex' -print
```

Expected:

- codesign verification succeeds
- `.appex` path is printed

- [ ] **Step 3: Launch app**

Run:

```bash
open -a /Applications/ToCreate.app
sleep 3
pgrep -fl 'LiheAPI|ToCreate'
```

Expected: ToCreate process is running.

- [ ] **Step 4: Confirm widget visibility manually**

Manual check:

1. Open macOS widget gallery.
2. Search `ToCreate`.
3. Confirm ToCreate appears.
4. Add small, medium, and large widgets.
5. Confirm the widgets show snapshot data or the empty state.

Expected: Widget appears if macOS accepts the ad-hoc signed extension. If it does not appear, record this as a signing/App Group limitation and continue to Task 10.

---

### Task 10: Document Signing Limitation And Release Notes

**Files:**

- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-06-24-tocreate-widgetkit-design.md`

- [ ] **Step 1: Add README section**

Add:

```markdown
## macOS 小组件

ToCreate 计划支持 WidgetKit 桌面小组件。小组件读取主 App 写入的状态快照，用于展示 API 连通状态、余额、今日用量、API 密钥数量和更新时间。

注意：真正的 WidgetKit 小组件依赖 Xcode Extension、App Group 和签名能力。开发阶段可以本地构建验证；正式分发时建议使用 Apple Developer 账号配置 App Group 和签名。
```

- [ ] **Step 2: Update spec implementation status**

In `docs/superpowers/specs/2026-06-24-tocreate-widgetkit-design.md`, add a new section near the end:

```markdown
## 实施状态

本设计对应的实现计划位于 `docs/superpowers/plans/2026-06-24-tocreate-widgetkit.md`。实现完成后，需要记录本地构建、小组件可见性、签名和 App Group 验证结果。
```

- [ ] **Step 3: Run full verification**

Run:

```bash
swift test
./scripts/package_app.sh
```

Expected:

- tests pass
- package script exits `0`
- `dist/ToCreate.dmg` is produced

- [ ] **Step 4: Commit docs**

Run:

```bash
git add README.md docs/superpowers/specs/2026-06-24-tocreate-widgetkit-design.md
git commit -m "docs: document widget signing requirements"
```

---

## Final Verification Checklist

Run:

```bash
git status --short
swift test
./scripts/package_app.sh
ls -lh dist/ToCreate.dmg
```

Expected:

- `git status --short` is clean
- all tests pass
- package script exits `0`
- `dist/ToCreate.dmg` exists

Then install and check:

```bash
pkill -x LiheAPI || true
rm -rf /tmp/tocreate-final-widget-check
mkdir -p /tmp/tocreate-final-widget-check
hdiutil attach dist/ToCreate.dmg -mountpoint /tmp/tocreate-final-widget-check -nobrowse -quiet
rm -rf /Applications/ToCreate.app
ditto /tmp/tocreate-final-widget-check/ToCreate.app /Applications/ToCreate.app
hdiutil detach /tmp/tocreate-final-widget-check -quiet
codesign --verify --deep --strict --verbose=2 /Applications/ToCreate.app
find /Applications/ToCreate.app/Contents/PlugIns -maxdepth 2 -type d -name '*.appex' -print
open -a /Applications/ToCreate.app
```

Manual expected result:

- App opens
- Menu bar still works
- Widget extension is embedded
- Widget gallery either shows ToCreate or, if blocked, failure is attributable to signing/App Group limitation rather than missing files
