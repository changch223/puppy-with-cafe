import SwiftUI
import WebKit

/// Instagram投稿の埋め込みカード（写真・雰囲気機能: 表示チェーンの1段目）。
/// `PhotoSourceResolver.instagramEmbedHTML` が生成した定型HTML（blockquote + embed.js）を
/// `loadHTMLString`（baseURL: instagram.com）で読み込む。画像そのものは保存・転載しない
/// （Meta公認の埋め込み形式で出典・帰属を保ったまま端末が直接表示する）。
///
/// UIKit 使用理由（憲章 原則V に基づく明記）:
/// SwiftUI標準コンポーネントにはHTML埋め込み表示手段が無いため `WKWebView` を
/// `UIViewRepresentable` で橋渡しする（前例: MKMapView）。
///
/// 読み込み完了後、埋め込みの実描画（Instagram側の非同期スクリプトによるiframe挿入）を
/// JSで定期計測して高さへ反映する。約8秒経っても内容が測れない場合・ナビゲーション失敗時は
/// `onFail` を呼び、呼び出し側がOGP写真カード等へフォールバックする。
struct InstagramPostEmbedView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat
    let onFail: () -> Void

    /// 表示の上限高さ
    static let maxHeight: CGFloat = 700
    /// 内容が測れない場合のタイムアウト
    static let timeoutSeconds: TimeInterval = 8
    /// 高さ計測のポーリング間隔
    static let pollInterval: TimeInterval = 0.4

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, onFail: onFail)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        // 埋め込みカード自体はスクロールさせない（詳細画面のスクロールに委ねる）
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        context.coordinator.load(html: html, into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onFail = onFail
        context.coordinator.load(html: html, into: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let heightBinding: Binding<CGFloat>
        var onFail: () -> Void

        private weak var pollTimer: Timer?
        private var lastLoadedHTML: String?
        private var didFail = false
        private var didSucceed = false
        private var elapsed: TimeInterval = 0

        init(height: Binding<CGFloat>, onFail: @escaping () -> Void) {
            self.heightBinding = height
            self.onFail = onFail
        }

        /// 同じHTMLの再読み込みは無視し、内容が変わった時だけロードし直す（詳細画面の再利用に対応）
        func load(html: String, into webView: WKWebView) {
            guard html != lastLoadedHTML else { return }
            lastLoadedHTML = html
            resetState()
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.instagram.com"))
        }

        private func resetState() {
            pollTimer?.invalidate()
            pollTimer = nil
            didFail = false
            didSucceed = false
            elapsed = 0
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startPolling(webView: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            fail()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            fail()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // 埋め込み内のリンクをユーザーがタップした場合のみ、アプリ内表示せず外部(Instagramアプリ等)へ渡す。
            // 初回のHTML読み込みや embed.js が生成するiframeの読み込み(.other)は素通しする。
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // MARK: - 高さ計測（ポーリング）

        private func startPolling(webView: WKWebView) {
            guard pollTimer == nil, !didFail else { return }
            let interval = InstagramPostEmbedView.pollInterval
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self, weak webView] timer in
                guard let self, let webView else {
                    timer.invalidate()
                    return
                }
                self.elapsed += interval
                self.measureHeight(of: webView, timer: timer)
            }
            pollTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func measureHeight(of webView: WKWebView, timer: Timer) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self, !self.didFail else { return }
                if let heightValue = result as? Double, heightValue > 0 {
                    self.didSucceed = true
                    self.heightBinding.wrappedValue = min(CGFloat(heightValue), InstagramPostEmbedView.maxHeight)
                }
                if self.elapsed >= InstagramPostEmbedView.timeoutSeconds {
                    timer.invalidate()
                    if !self.didSucceed {
                        self.fail()
                    }
                }
            }
        }

        private func fail() {
            guard !didFail else { return }
            didFail = true
            pollTimer?.invalidate()
            pollTimer = nil
            onFail()
        }
    }
}
