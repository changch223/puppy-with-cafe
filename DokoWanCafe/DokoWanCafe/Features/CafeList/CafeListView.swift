import MapKit
import SwiftUI
import UIKit

/// 一覧画面（T025）: 距離順・可否バッジ・距離表示（FR-002/005, SC-002）。
struct CafeListView: View {
    @ObservedObject var viewModel: CafeListViewModel

    var body: some View {
        List(viewModel.displayedResults) { item in
            NavigationLink(value: item.cafe) {
                CafeRowView(item: item)
            }
        }
        .listStyle(.plain)
        .accessibilityLabel(Text("周辺の犬同伴OKカフェ一覧（近い順）"))
    }
}

/// 一覧の1行: 詳細を開かなくても「可否」と「距離」が判別できる（SC-002）
struct CafeRowView: View {
    let item: CafeWithDistance

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CafeRowThumbnailView(cafe: item.cafe)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.cafe.name)
                    .font(.headline)
                    .lineLimit(2)
                if let condition = item.cafe.dogPolicyCondition,
                   item.cafe.dogPolicyStatus == .conditional {
                    Text(condition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                // 営業状態（構造化営業時間のある店のみ, FR-102）
                OpenStateBadge(state: OpeningHoursEvaluator.state(hours: item.cafe.hours))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: item.cafe.dogPolicyStatus)
                Text(MapViewModel.distanceText(meters: item.distanceMeters))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            "\(item.cafe.name)、\(item.cafe.dogPolicyStatus.displayName)、\(MapViewModel.distanceText(meters: item.distanceMeters))"
        ))
    }
}

/// 一覧行の56×56角丸サムネイル（写真プレビュー機能）。`LinkPreviewService` のキャッシュ経由の画像のみを使い、
/// 埋め込みWebViewは一覧では使わない。キャッシュ命中時は即表示、未キャッシュは非同期取得しつつ
/// スクロールで行が入れ替わってもプレースホルダに切り替わるようにする（`.task(id:)` による自動キャンセル）。
private struct CafeRowThumbnailView: View {
    let cafe: Cafe

    @State private var image: UIImage?

    private static let size: CGFloat = 56

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        Image(systemName: "pawprint.fill")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: Self.size, height: Self.size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
        .task(id: cafe.id) {
            image = nil
            guard let url = PhotoSourceResolver.previewSourceURL(for: cafe) else { return }
            let preview = await LinkPreviewService.shared.preview(for: url)
            guard !Task.isCancelled else { return }
            image = preview?.image
        }
    }
}
