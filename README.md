# ToCreate for Mac

这是 `https://api.lihe.chat` 的轻量 macOS 客户端，使用 AppKit 和 WKWebView 构建。当前版本会在 Mac 应用窗口内直接嵌入网站。

## 本地构建

```bash
cd /Users/lihe/Desktop/LiheAPI-Mac
bash scripts/package_app.sh
```

构建产物：

- `dist/ToCreate.dmg`

## 发布新版

发布前先确保本地 Git 工作区是干净的，并且已经登录 GitHub CLI：

```bash
gh auth status
```

发布命令：

```bash
./scripts/release.sh 0.1.2 "这里填写本次更新说明"
```

脚本会自动完成：

- 修改 `Resources/Info.plist` 里的版本号和 build 号
- 运行 `swift test`
- 重新生成 `dist/ToCreate.dmg`
- 提交版本号变更
- 创建并推送 `v版本号` tag
- 创建 GitHub Release
- 上传 `ToCreate.dmg`

## 测试安装

打开 `dist/ToCreate.dmg`，把 `ToCreate` 拖入 Applications。当前版本使用本机临时签名，没有 Apple 公证，仅用于自己测试。

如果 macOS 拦截首次启动，请在 Finder 中按住 Control 点击应用并选择“打开”；或者前往“系统设置 → 隐私与安全性”允许打开。

安装后可以添加桌面小组件：

1. 先打开一次 `ToCreate`，让应用刷新并写入最新状态。
2. 在桌面空白处右键，选择“编辑小组件”。
3. 搜索 `ToCreate`，添加小号、中号或大号小组件。
4. 点击小组件会打开 `ToCreate` 主窗口。

小组件显示的是 App 最近一次刷新的快照；如果长时间没有打开 App，小组件会提示数据可能过期。

如果“小组件库”里搜不到 `ToCreate`，通常不是小组件代码没有打包，而是当前 DMG 使用本机临时签名。WidgetKit 对 extension 注册更严格，建议先在 Xcode 的 `Settings → Accounts` 登录 Apple ID，然后用开发签名重新打包：

```bash
DEVELOPMENT_TEAM=L269VPSDX3 bash scripts/package_app.sh
```

如果 Xcode 提示找不到 provisioning profile，请在 Xcode 里确认账号已登录，并允许 Xcode 自动管理签名。

## 快捷键

- `⌘R`：刷新
- `⌘[`：后退
- `⌘]`：前进
- `⌘H`：回到首页
- `⌘1`：渠道状态
- `⌘2`：余额 / 控制台
- `⌘3`：使用记录
- `⌘L`：复制当前页面标题和链接
- `⇧⌘O`：在默认浏览器中打开当前页面
- `⌘,`：偏好设置
- `⌘Q`：退出

## 原生能力

- 菜单栏小图标：可查看服务状态、今日用量、余额、API 密钥数量、渠道可用状态，并支持手动刷新。
- 桌面小组件：可在 macOS 桌面查看 API 连通状态、今日请求、Tokens、费用、余额和 API 密钥数量，点击小组件可回到主窗口。
- 偏好设置：支持隐私模式、自动刷新间隔、开机启动、启动时自动检查更新、渠道异常提醒、余额阈值提醒、今日费用阈值提醒。
- 更新检查：通过 GitHub Releases 检查最新版，发现新版后下载 `ToCreate.dmg` 到 Downloads，并尝试自动安装和重启。
- 关于窗口：显示当前版本、Build、GitHub 仓库和更新源信息。
- 系统通知：首次启动会请求通知权限，可在渠道异常、余额过低或今日费用超过阈值时提醒。
- 剪贴板增强：可复制当前页面标题和链接。
- 主窗口：未登录时进入登录页，已登录时进入控制台，并在应用内嵌网页，不跳默认浏览器。
