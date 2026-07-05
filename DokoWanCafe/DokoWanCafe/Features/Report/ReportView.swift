import SwiftUI
import UIKit

/// 誤り報告（T040/T041/T067, FR-023/024/028。2026-07-05 構成Bへ改訂: research.md R11）。
///
/// v1 は Google フォーム（店舗情報プリフィル）で受け付ける。サインインは不要（FR-028 改訂）。
/// 送信された内容は運営がマスターデータへ反映（＝承認）するまで表示に反映されない（FR-024）。
struct ReportView: View {
    let cafe: Cafe
    @Environment(\.dismiss) private var dismiss
    @State private var didOpenForm = false

    private var formURL: URL? {
        AppEnvironment.reportFormURL(cafeName: cafe.name, cafeID: cafe.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let formURL {
                    formIntroView(formURL)
                } else {
                    unavailableView
                }
            }
            .navigationTitle(String(localized: "情報の誤りを報告"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
        }
    }

    // MARK: - フォーム誘導

    private func formIntroView(_ url: URL) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("「\(cafe.name)」の情報の誤りを報告")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("現在の表示: \(cafe.dogPolicyStatus.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("報告フォームが開きます（サインイン不要）。送信された内容は運営が確認し、正しいと判断したものだけがデータに反映されます。即時には反映されません。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                UIApplication.shared.open(url)
                didOpenForm = true
            } label: {
                Label(String(localized: "報告フォームを開く"), systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if didOpenForm {
                Text("ご協力ありがとうございます。反映まで数日かかることがあります。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .accessibilityElement(children: .contain)
    }

    // MARK: - フォーム未設定（準備中）

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("報告の受付は準備中です")
                .font(.headline)
            Text("誤り報告フォームは現在準備中です。公開までしばらくお待ちください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
