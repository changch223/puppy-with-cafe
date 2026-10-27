import SwiftUI

/// ピンを選んだときに一覧シートの中身が変わる「店のカード」（再設計 段階1a）。
/// 写真 or 頭文字タイル・店名・タグ・条件の要点・営業の行・徒歩の目安と、経路／電話／行きたい／共有、「詳しく見る」。
/// 一覧に戻す（✕）と、シートは元の段に戻る。
struct PlaceCardView: View {
    let item: CafeWithDistance
    /// 保存の状態（行きたい／行った）。未保存は nil
    let savedStatus: SavedStatus?
    /// 営業の判定に使う時刻（対象時刻があればその時刻）
    let now: Date
    /// `now` が「いつ行く？」で決めた対象時刻か
    let isTargetTime: Bool
    let containerHeight: CGFloat
    let onShowDetail: () -> Void
    let onOpenRoute: () -> Void
    let onToggleWantToGo: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cafe: Cafe { item.cafe }
    private var walking: WalkingTime.Summary { WalkingTime.summary(meters: item.distanceMeters) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if dynamicTypeSize.isAccessibilitySize {
                    // 大きな文字では写真と閉じるボタンの行の下に、店名・タグ・条件を全幅で並べる（店名を省略しない）
                    HStack(alignment: .top) {
                        CafeThumbnailView(cafe: cafe, size: 56)
                        Spacer(minLength: 0)
                        closeButton
                    }
                    cardInfo
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        CafeThumbnailView(cafe: cafe, size: 72)
                        cardInfo
                            .frame(maxWidth: .infinity, alignment: .leading)
                        closeButton
                    }
                }

                // 大きな文字ではボタンを縦に積み、ラベルが切れないようにする
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    Button(action: onOpenRoute) {
                        CafeDetailActionLabel(
                            title: String(localized: "経路"),
                            systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                            prominent: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(cafe.name)への経路を開く"))

                    if let phoneURL = PhoneLink.url(for: cafe.phone) {
                        Button {
                            openURL(phoneURL)
                        } label: {
                            CafeDetailActionLabel(title: String(localized: "電話"), systemImage: "phone.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("\(cafe.name)に電話する"))
                    }

                    savedButton

                    ShareLink(item: CafeDetailShare.message(for: cafe)) {
                        CafeDetailActionLabel(title: String(localized: "共有"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(cafe.name)を共有"))
                }

                Button(action: onShowDetail) {
                    HStack {
                        Text("詳しく見る")
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityLabel(Text("\(cafe.name)の詳細を見る"))
            }
            .padding(16)
        }
        .frame(height: CafeSheetDetent.cardHeight(
            containerHeight: containerHeight, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        ))
        .sheetChrome()
        .accessibilityElement(children: .contain)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(.secondaryLabel))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(Text("閉じて一覧に戻る"))
    }

    /// 店名・タグ・条件の要点・営業と徒歩の目安
    private var cardInfo: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(cafe.name)
                    .font(.headline)
                    .lineLimit(isLarge ? nil : 2)
                    .fixedSize(horizontal: false, vertical: isLarge)
                // 行った店は名前の横の小さなチェックで示す（押せない表示）
                if savedStatus == .visited {
                    VisitedCheckIcon()
                }
            }
            CafeTagsView(cafe: cafe)
            if let condition = CafePresentation.conditionSummary(for: cafe) {
                Text(condition)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(isLarge ? nil : 2)
            }
            MyDogNoteView(cafe: cafe)
            let line = HStack(spacing: 8) {
                OpenLineView(line: OpenLine.make(hours: cafe.hours, at: now, isTargetTime: isTargetTime))
                Text(walkingText)
                    .font(.caption.bold())
                    .foregroundStyle(Color(.secondaryLabel))
            }
            if isLarge {
                VStack(alignment: .leading, spacing: 4) {
                    OpenLineView(line: OpenLine.make(hours: cafe.hours, at: now, isTargetTime: isTargetTime))
                    Text(walkingText)
                        .font(.caption.bold())
                        .foregroundStyle(Color(.secondaryLabel))
                }
            } else {
                line
            }
        }
    }

    /// 「行きたい」ボタン（トグル）。詳細と同じ表示で、行きたいのときだけ塗った肉球にする。
    /// 行った店は未保存と同じ表示（塗っていない肉球）で、押すと「行きたい」に戻す
    /// （保存から黙って消さない。行った記録を外すのは詳細の「行った ✓」と保存タブのスワイプだけ）。
    /// 行った状態は名前の横のチェックで示す。
    private var savedButton: some View {
        let isWantToGo = savedStatus == .wantToGo
        return Button(action: onToggleWantToGo) {
            CafeDetailActionLabel(
                title: String(localized: "行きたい"),
                systemImage: isWantToGo ? "pawprint.fill" : "pawprint"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isWantToGo ? "行きたいから外す" : "行きたいに入れる"))
    }

    private var walkingText: String {
        if let detail = walking.detail { return "\(walking.headline)・\(detail)" }
        return walking.headline
    }
}
