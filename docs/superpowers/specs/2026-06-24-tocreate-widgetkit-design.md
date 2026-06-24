# ToCreate macOS 桌面小组件设计

日期：2026-06-24

## 背景

ToCreate 目前已经是一个 macOS 菜单栏工具，主 App 内嵌 `https://api.lihe.chat`，并在菜单栏弹窗里显示 API 连通状态、今日用量、余额、API 密钥数量和更新时间。

用户希望进一步增加“桌面小组件”。本设计选择真正的 macOS 系统小组件，也就是 WidgetKit 小组件，而不是普通悬浮窗。

## 目标

第一版小组件用于在桌面或通知中心快速查看 ToCreate 的核心状态：

- API 是否可连通
- 账户余额
- 今日请求数
- 今日 Tokens
- 今日费用
- API 密钥数量
- 最新更新时间

小组件不承担登录、不嵌入网页、不直接管理 API Token。它只展示主 App 已经采集并写入共享区的数据快照。

## 非目标

第一版不做以下内容：

- 不在小组件里登录
- 不在小组件里直接打开网页或管理 API Key
- 不让小组件独立请求完整业务接口
- 不做复杂图表、趋势曲线或历史统计
- 不做 iOS 小组件
- 不做锁屏小组件

## 推荐架构

采用“主 App 采集数据，小组件读取快照”的架构。

```text
ToCreate 主 App
  ├─ 内嵌网页 / 登录态 / API 请求
  ├─ 菜单栏状态展示
  └─ 写入共享快照
        ↓ App Group
WidgetKit Extension
  ├─ 读取共享快照
  ├─ 跟随隐私模式展示/隐藏敏感数字
  └─ 点击后打开 ToCreate 主 App
```

这个架构比“小组件自己请求 API”更稳定，因为 WidgetKit 的运行频率、生命周期和网络权限都受到系统调度限制，不适合承载登录态和复杂接口请求。

## 工程结构

当前项目是 Swift Package，只有一个可执行 App target。真正的 WidgetKit 小组件需要 Xcode 工程和 Widget Extension。

建议新增：

```text
ToCreate.xcodeproj
ToCreateWidget/
  ├─ ToCreateWidget.swift
  ├─ ToCreateWidgetBundle.swift
  └─ Assets.xcassets
Shared/
  ├─ WidgetSnapshot.swift
  └─ WidgetSnapshotStore.swift
```

其中：

- 主 App target 继续复用现有 `Sources/LiheAPI` 代码。
- Widget Extension 使用 WidgetKit + SwiftUI。
- `Shared` 里的快照模型由主 App 和 Widget 共用。
- 打包脚本后续需要改成基于 Xcode archive/build，而不是只用 `swift build`。

## App Group

主 App 和 Widget 需要使用同一个 App Group，例如：

```text
group.chat.lihe.api.mac
```

主 App 将最新快照写入 App Group 的共享 `UserDefaults`，Widget 从同一个 suite 读取。

如果暂时没有 Apple Developer 账号，开发阶段可以先完成代码结构和本地调试；正式分发系统 Widget 时，签名和 App Group capability 最终仍需要 Apple Developer 账号。

## 数据快照模型

建议快照结构：

```swift
struct WidgetSnapshot: Codable, Equatable {
    var apiStatus: APIStatus
    var balance: Double?
    var todayRequests: Double?
    var todayTokens: Double?
    var todayCost: Double?
    var apiKeyCount: Double?
    var updatedAt: Date?
    var privacyModeEnabled: Bool
}

enum APIStatus: String, Codable {
    case reachable
    case unreachable
    case unknown
}
```

主 App 每次成功刷新菜单栏指标时，同步更新 `WidgetSnapshot`。

如果接口部分失败：

- API 不可连通：`apiStatus = .unreachable`
- 指标缺失但 App 仍可连通：保留已有缓存值，更新时间可不更新
- 没有任何快照：Widget 显示等待状态

## 隐私模式

小组件跟随 ToCreate 偏好设置里的“隐私模式”。

隐私模式关闭：

```text
余额        $399,478.22
今日费用    $0.12
API 密钥    6 个
```

隐私模式开启：

```text
余额        已隐藏
今日费用    已隐藏
API 密钥    已隐藏
```

请求数和 Tokens 暂时不视为敏感信息，默认继续显示。如果后续用户希望更严格，可以扩展为隐藏全部用量数字。

## 小组件尺寸

第一版支持三个尺寸。

### 小号

```text
ToCreate
● API 可连通
余额 $399,478.22
```

适合只看服务状态和账户余额。

### 中号

```text
ToCreate
● API 可连通

余额        $399,478.22
今日费用    $0.12
请求        36 次
```

适合作为默认推荐尺寸。

### 大号

```text
ToCreate
● API 可连通

今日用量
请求        36 次
Tokens      338.1K
费用        $0.12

账户
余额        $399,478.22
API 密钥     6 个

更新于      11:16:43
```

适合用户想把它作为桌面监控卡片。

## 交互

小组件保持轻量：

- 点击任意位置打开 ToCreate 主 App。
- 第一版不做按钮级交互。
- 不在小组件里刷新数据；刷新由主 App 和 WidgetKit timeline 共同驱动。

Widget URL scheme 可使用：

```text
tocreate://open
```

主 App 后续可注册该 URL scheme，收到后显示主窗口。

## 刷新策略

主 App：

- 菜单栏刷新成功后写入快照。
- 用户手动刷新后写入快照。
- 自动刷新开启时，每次自动刷新成功后写入快照。

Widget：

- Timeline 每 5–15 分钟请求一次刷新。
- 实际刷新频率由 macOS 控制，不能保证秒级更新。
- Widget 只读取最近快照，不承担实时请求。

过期提示：

- 快照 10 分钟内：正常显示更新时间。
- 快照超过 10 分钟：显示“数据可能过期”。
- 无快照：显示“等待 ToCreate 刷新”。

## 错误与空状态

无快照：

```text
ToCreate
等待 ToCreate 刷新
打开 App 后会自动更新
```

API 不可连通：

```text
ToCreate
● API 不可连通
上次更新 11:16:43
```

隐私模式开启：

```text
ToCreate
● API 可连通
余额 已隐藏
费用 已隐藏
```

数据过期：

```text
ToCreate
● API 可连通
数据可能过期
更新于 10:55:02
```

## 测试计划

单元测试：

- `WidgetSnapshot` 可正确编码/解码。
- `WidgetSnapshotStore` 可写入和读取共享快照。
- 隐私模式下格式化结果为“已隐藏”。
- 无数据、过期数据、不可连通状态都有明确展示模型。

集成验证：

- 主 App 刷新菜单栏数据后，共享快照更新。
- Widget 能读取快照并显示。
- 点击 Widget 能打开 ToCreate 主 App。
- 隐私模式切换后，小组件下一次刷新反映设置变化。

打包验证：

- Xcode 构建包含主 App 和 Widget Extension。
- 安装后系统小组件列表能看到 ToCreate。
- DMG 中的 App 安装到 `/Applications` 后，小组件仍可添加。

## 实施顺序

建议分四步实现：

1. 新增共享快照模型和存储层。
2. 主 App 刷新指标时写入快照。
3. 新增 Xcode 工程和 Widget Extension。
4. 更新打包脚本，让 Release DMG 包含 Widget Extension。

## 风险

主要风险是签名与 App Group：

- 真正的 Widget Extension 依赖 Xcode target 和 capability。
- App Group 正式分发通常需要 Apple Developer 账号配置。
- 目前项目使用 ad-hoc 签名，可能无法完整启用正式 App Group。

如果短期没有 Apple Developer 账号，可以先完成代码结构和本地开发验证；正式面向用户分发时，再补开发者账号签名和 App Group 配置。

## 决策

第一版采用 WidgetKit 系统小组件，主 App 写共享快照，小组件读取展示。小组件跟随隐私模式，不独立登录，不直接请求业务 API。默认推荐中号小组件作为主要体验。
