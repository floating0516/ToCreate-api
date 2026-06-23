import AppKit
import SwiftUI

struct LauncherView: View {
    private let homeURL = URL(string: "https://api.lihe.chat")!

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 92, height: 92)
                .cornerRadius(20)

            VStack(spacing: 8) {
                Text(AppBranding.displayName)
                    .font(.system(size: 30, weight: .semibold))

                Text("Mac 启动器已就绪。点击下方按钮，在默认浏览器中打开你的 API 分发网站。")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button {
                openWebsite()
            } label: {
                Text("打开 api.lihe.chat")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 220)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Button("复制网址") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(homeURL.absoluteString, forType: .string)
            }
            .buttonStyle(.link)

            Text(homeURL.absoluteString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(42)
        .frame(width: 560, height: 430)
    }

    private func openWebsite() {
        NSWorkspace.shared.open(homeURL)
    }
}
