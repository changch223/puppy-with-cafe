import SwiftUI
import UIKit

/// 検索の状態表示（T029/T060）:
/// 空状態・対象エリア外・位置許可なし・エラーを分かりやすく提示し、
/// 次に取れる行動（範囲拡大・地域変更・再試行・設定）を案内する（FR-017/020/022）。
struct SearchStateView: View {
    @ObservedObject var viewModel: CafeListViewModel
    let onPickArea: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.phase {
            case .idle, .loading:
                ProgressView(String(localized: "周辺のカフェを検索中…"))

            case .empty:
                // 全カフェを絞り込みなしで取得しているため、通常発生するのは
                // 「可否フィルタの組合せで該当が0件」というケースのみ（FR-020）。
                stateContent(
                    systemImage: "cup.and.saucer",
                    title: String(localized: "条件に合う犬同伴OKのカフェが見つかりませんでした"),
                    message: String(localized: "絞り込み条件を変えるか、別の地域で探してみてください。")
                ) {
                    changeAreaButton
                }

            case .outOfArea:
                // FR-022: 対象エリア外は「対象外」と明示し、0件と誤認させない
                stateContent(
                    systemImage: "map",
                    title: String(localized: "この場所は現在サービス対象外です"),
                    message: String(localized: "Puppy With Cafe は現在、東京エリアのみ対応しています。対応エリアは順次拡大予定です。東京の地名を選んで探すことができます。")
                ) {
                    changeAreaButton
                }

            case .locationDenied:
                // FR-017: 位置情報が使えなくても手動の地域指定で検索できる
                stateContent(
                    systemImage: "location.slash",
                    title: String(localized: "位置情報が利用できません"),
                    message: String(localized: "設定アプリで位置情報を許可するか、地域を選んで検索してください。位置情報は周辺検索のみに使われ、保存されません。")
                ) {
                    changeAreaButton
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(String(localized: "設定を開く"), systemImage: "gear")
                    }
                    .buttonStyle(.bordered)
                }

            case .error(let message):
                stateContent(
                    systemImage: "exclamationmark.triangle",
                    title: String(localized: "読み込みに失敗しました"),
                    message: message
                ) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label(String(localized: "再試行"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .loaded, .offline:
                EmptyView()
            }
        }
        .padding(24)
    }

    private var changeAreaButton: some View {
        Button {
            onPickArea()
        } label: {
            Label(String(localized: "地域を選んで探す"), systemImage: "mappin.and.ellipse")
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func stateContent(
        systemImage: String,
        title: String,
        message: String,
        @ViewBuilder actions: () -> some View
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                actions()
            }
            .padding(.top, 4)
        }
        .accessibilityElement(children: .contain)
    }
}
