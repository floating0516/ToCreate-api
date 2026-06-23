import AppKit
import Combine
import SwiftUI
import WebKit

@MainActor
final class BrowserModel: ObservableObject {
    static let homeURL = URL(string: "https://api.lihe.chat")!

    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var currentURL = homeURL
    @Published private(set) var isLoading = false
    @Published var message: String?

    fileprivate weak var webView: WKWebView?
    private var loadingTimeoutTask: Task<Void, Never>?

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        message = nil
        webView?.reload()
    }

    func loadHome() {
        message = nil
        webView?.load(URLRequest(url: Self.homeURL))
    }

    func openInDefaultBrowser() {
        NSWorkspace.shared.open(currentURL)
    }

    fileprivate func synchronize(with webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        currentURL = webView.url ?? Self.homeURL
    }

    fileprivate func didStartLoading(_ webView: WKWebView) {
        synchronize(with: webView)
        isLoading = true
        message = nil

        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isLoading else { return }
                self.message = "页面仍在加载。如果长时间停住，可以刷新或在默认浏览器中打开。"
            }
        }
    }

    fileprivate func didFinishLoading(_ webView: WKWebView) {
        loadingTimeoutTask?.cancel()
        isLoading = false
        message = nil
        synchronize(with: webView)
    }

    fileprivate func didFailLoading(_ error: Error, webView: WKWebView) {
        loadingTimeoutTask?.cancel()
        isLoading = false
        synchronize(with: webView)

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        message = "页面加载失败：\(error.localizedDescription)"
    }
}

struct BrowserShellView: View {
    @ObservedObject var model: BrowserModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            ZStack(alignment: .top) {
                BrowserView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let message = model.message {
                    messageBanner(message)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 640)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.canGoBack)

            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canGoForward)

            Button {
                model.reload()
            } label: {
                Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
            }

            Text(model.currentURL.absoluteString)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                model.openInDefaultBrowser()
            } label: {
                Image(systemName: "safari")
            }
            .help("在默认浏览器中打开")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func messageBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Button("刷新") {
                model.reload()
            }

            Button("浏览器打开") {
                model.openInDefaultBrowser()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(radius: 8)
        .padding(.top, 14)
    }
}

struct BrowserView: NSViewRepresentable {
    @ObservedObject var model: BrowserModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        model.webView = webView
        webView.load(URLRequest(url: BrowserModel.homeURL))

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let webView = nsView.subviews.compactMap({ $0 as? WKWebView }).first else {
            return
        }
        model.synchronize(with: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let model: BrowserModel

        init(model: BrowserModel) {
            self.model = model
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

            switch URLPolicy.destination(for: url) {
            case .embedded:
                decisionHandler(.allow)
            case .external:
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.didStartLoading(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            model.synchronize(with: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.didFinishLoading(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.didFailLoading(error, webView: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.didFailLoading(error, webView: webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            model.message = "网页进程意外退出，已自动重新加载。"
            webView.reload()
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }

            if URLPolicy.destination(for: url) == .embedded {
                webView.load(URLRequest(url: url))
            } else {
                NSWorkspace.shared.open(url)
            }

            return nil
        }
    }
}
