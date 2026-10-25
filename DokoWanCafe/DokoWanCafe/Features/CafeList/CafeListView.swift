import SwiftUI

/// 一覧の1行（再設計 段階1a）: 写真（なければ頭文字タイル）／店名・タグ・条件の要点・営業の行／徒歩の目安。
/// 詳細を開かなくても「入れるか・今開いているか・どれくらいで着くか」が分かる。
struct CafeRowView: View {
    let item: CafeWithDistance
    let isFavorite: Bool
    /// 営業の判定に使う時刻（既定は現在。プレビュー・テスト用に注入できる）
    var now: Date = Date()

    private var cafe: Cafe { item.cafe }
    private var walking: WalkingTime.Summary { WalkingTime.summary(meters: item.distanceMeters) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CafeThumbnailView(cafe: cafe, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(cafe.name)
                        .font(.headline)
                        .lineLimit(2)
                    if isFavorite {
                        FavoritePawIcon()
                    }
                    if CafePresentation.showsFreshnessWarning(for: cafe, now: now) {
                        FreshnessWarningIcon()
                    }
                }
                CafeTagsView(cafe: cafe)
                if let condition = CafePresentation.conditionSummary(for: cafe) {
                    Text(condition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                OpenLineView(line: OpenLine.make(hours: cafe.hours, at: now))
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(walking.headline)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.trailing)
                if let detail = walking.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(CafePresentation.accessibilityLabel(for: item, isFavorite: isFavorite, at: now)))
    }
}
