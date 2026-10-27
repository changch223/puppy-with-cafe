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

    @Environment(\.dogProfile) private var dog
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cafe: Cafe { item.cafe }
    private var walking: WalkingTime.Summary { WalkingTime.summary(meters: item.distanceMeters) }

    var body: some View {
        // 大きな文字では横に並べると店名・タグ・徒歩の表示が画面からはみ出すため、縦に積む
        // （写真＋店名の1行 → タグ・条件・営業 → 徒歩の目安）
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        CafeThumbnailView(cafe: cafe, size: 56)
                        nameLine
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    details
                    walkingView(alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    CafeThumbnailView(cafe: cafe, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        nameLine
                        details
                    }

                    Spacer(minLength: 4)

                    walkingView(alignment: .trailing)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(CafePresentation.accessibilityLabel(
            for: item, savedStatus: savedStatus, at: now, isTargetTime: isTargetTime, clock: clock, caption: caption, dog: dog
        )))
    }

    /// 店名と、保存・鮮度のアイコン（大きな文字では店名を省略せず折り返す）
    private var nameLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(cafe.name)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
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
        }
    }

    /// タグ・条件の要点・うちの子の注記・営業の行
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            CafeTagsView(cafe: cafe)
            if let condition = CafePresentation.conditionSummary(for: cafe) {
                Text(condition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            }
            MyDogNoteView(cafe: cafe)
            OpenLineView(line: OpenLine.make(hours: cafe.hours, at: now, isTargetTime: isTargetTime))
        }
    }

    /// 徒歩の目安（標準は右端に右寄せ、大きな文字では下に左寄せ）
    private func walkingView(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(walking.headline)
                .font(.subheadline.bold())
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            if let detail = walking.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
