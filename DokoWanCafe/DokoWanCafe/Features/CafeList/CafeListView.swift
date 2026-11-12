import SwiftUI

/// 一覧の1行（再設計 第1弾）: 写真（なければカテゴリの絵柄のタイル）と、3行（店名／答え1行／営業・距離）。
/// 詳細を開かなくても「入れるか・今開いているか・どれくらいで着くか」が分かる。条件文は詳細とカードで読む。
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
        // 大きな文字では写真と店名の1行の下に、答え・営業と距離を全幅で並べる
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        CafeThumbnailView(cafe: cafe, size: 56)
                        nameLine
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    details
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    CafeThumbnailView(cafe: cafe, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        nameLine
                        details
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    /// 答えの1行と、営業・距離の1行
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            AnswerLineView(cafe: cafe)
            OpenAndDistanceLineView(
                line: OpenLine.make(hours: cafe.hours, at: now, isTargetTime: isTargetTime),
                walking: walking
            )
        }
    }
}
