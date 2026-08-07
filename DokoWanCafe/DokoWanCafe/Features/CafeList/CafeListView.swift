import MapKit
import SwiftUI
import UIKit

/// 一覧画面（T025）: 距離順・犬目線バッジ・距離表示（FR-002/005, SC-002, 設計書4で可否4値バッジから刷新）。
struct CafeListView: View {
    @ObservedObject var viewModel: CafeListViewModel
    /// お気に入り店の肉球表示に使う（設計書4。地図側と同様に呼び出し元から明示的に渡す）
    let favoriteIDs: Set<UUID>

    var body: some View {
        List(viewModel.displayedResults) { item in
            NavigationLink(value: item.cafe) {
                CafeRowView(item: item, isFavorite: favoriteIDs.contains(item.cafe.id))
            }
        }
        .listStyle(.plain)
        .accessibilityLabel(Text("周辺の犬同伴OKカフェ一覧（近い順）"))
    }
}

/// 一覧の1行: 詳細を開かなくても「犬目線の可否」と「距離」が判別できる（SC-002, 設計書4）
struct CafeRowView: View {
    let item: CafeWithDistance
    let isFavorite: Bool

    private var category: MapPinCategory { MapPinCategory.category(for: item.cafe) }

    /// 未確認 or 最終確認から1年超の店に鮮度警告アイコンを出す（設計書4）
    private var showsFreshnessWarning: Bool {
        item.cafe.dogPolicyStatus == .unverified
            || FreshnessEvaluator.isStale(lastVerified: item.cafe.lastVerified)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CafeRowThumbnailView(cafe: item.cafe)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(item.cafe.name)
                        .font(.headline)
                        .lineLimit(2)
                    if isFavorite {
                        FavoritePawIcon()
                    }
                    if showsFreshnessWarning {
                        FreshnessWarningIcon()
                    }
                }
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
                MapPinCategoryBadge(category: category)
                Text(MapViewModel.distanceText(meters: item.distanceMeters))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            "\(item.cafe.name)、\(category.displayName)、\(MapViewModel.distanceText(meters: item.distanceMeters))"
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
