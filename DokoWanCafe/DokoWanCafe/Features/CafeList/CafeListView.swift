import SwiftUI

/// 一覧の1行（再設計 段階1a）: 写真（なければ頭文字タイル）／店名・タグ・条件の要点・営業の行／徒歩の目安。
/// 詳細を開かなくても「入れるか・今開いているか・どれくらいで着くか」が分かる。
struct CafeRowView: View {
    let item: CafeWithDistance
    /// 保存の状態（行きたい＝肉球、行った＝チェック）。未保存は nil
    let savedStatus: SavedStatus?
    /// 営業の判定に使う時刻（既定は現在。対象時刻・プレビュー・テスト用に注入できる）
    var now: Date = Date()
    /// `now` が「いつ行く？」で決めた対象時刻か
    var isTargetTime = false
    /// 今の時刻（「情報が古い可能性」の判定に使う。対象時刻ではなく今で判定する）。省略時は `now`
    var clock: Date?
    /// 名前の下に添える一言（保存タブの「10/25 に行った」など）
    var caption: String?

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
                    switch savedStatus {
                    case .wantToGo: FavoritePawIcon()
                    case .visited: VisitedCheckIcon()
                    case nil: EmptyView()
                    }
                    if CafePresentation.showsFreshnessWarning(for: cafe, now: clock ?? now) {
                        FreshnessWarningIcon()
                    }
                }
                if let caption {
                    Text(caption)
                        .font(.caption.bold())
                        .foregroundStyle(Color.brand)
                }
                CafeTagsView(cafe: cafe)
                if let condition = CafePresentation.conditionSummary(for: cafe) {
                    Text(condition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                OpenLineView(line: OpenLine.make(hours: cafe.hours, at: now, isTargetTime: isTargetTime))
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
        .accessibilityLabel(Text(CafePresentation.accessibilityLabel(
            for: item, savedStatus: savedStatus, at: now, isTargetTime: isTargetTime, clock: clock, caption: caption
        )))
    }
}
