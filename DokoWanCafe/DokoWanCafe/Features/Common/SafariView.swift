import SafariServices
import SwiftUI

/// アプリ内ブラウザ（写真・雰囲気機能: 公式サイト・食べログ等の http(s) リンクをアプリ内で開く）。
///
/// UIKit 使用理由（憲章 原則V に基づく明記）:
/// `SFSafariViewController` はSwiftUI標準コンポーネントが存在せず、閉じて即アプリへ復帰できる
/// アプリ内ブラウザ体験を提供するため `UIViewControllerRepresentable` で橋渡しする（前例: MKMapView）。
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // 表示するURLは sheet 提示のたびに新規生成される想定のため、更新処理は不要
    }
}
