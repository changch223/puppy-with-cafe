import SwiftUI

/// ピンを選んだときに一覧シートの中身が変わる「店のカード」（再設計 段階1a）。
/// 写真 or カテゴリの絵柄のタイル・店名・答え1行・条件の要点・営業の行・徒歩の目安と、経路／電話／行きたい／共有、「詳しく見る」。
/// 一覧に戻す（✕）と、シートは元の段に戻る。
struct PlaceCardView: View {
    let item: CafeWithDistance
    /// 保存の状態（行きたい／行った）。未保存は nil
    let savedStatus: SavedStatus?
    /// 営業の判定に使う時刻（対象時刻があればその時刻）
    let now: Date
    /// `now` が「いつ行く？」で決めた対象時刻か
    let isTargetTime: Bool
    /// 同じ場所（5m 以内）の店（選択中の店を含む・地図のピンの並び）。2店以上のときだけカードの上に切り替えの列を出す
    var sameSpot: [CafeWithDistance] = []
    let containerHeight: CGFloat
    let onShowDetail: () -> Void
    let onOpenRoute: () -> Void
    let onToggleWantToGo: () -> Void
    let onClose: () -> Void
    /// 同じ場所の列で別の店を選んだとき（カードをその店に切り替える。地図の選択は変えない）
    var onSelectSameSpot: (CafeWithDistance) -> Void = { _ in }
    /// 行った店の保存メニューで選んだ操作
    var onSaveAction: (SaveAction) -> Void = { _ in }

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dogProfile) private var dog

    private var cafe: Cafe { item.cafe }
    private var walking: WalkingTime.Summary { WalkingTime.summary(meters: item.distanceMeters) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if hasSameSpot { sameSpotRow }

                if dynamicTypeSize.isAccessibilitySize {
                    // 大きな文字では写真と閉じるボタンの行の下に、店名・タグ・条件を全幅で並べる（店名を省略しない）
                    HStack(alignment: .top) {
                        CafeThumbnailView(cafe: cafe, size: 56, allowsNetwork: true)
                        Spacer(minLength: 0)
                        closeButton
                    }
                    cardInfo
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        CafeThumbnailView(cafe: cafe, size: 72, allowsNetwork: true)
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
            containerHeight: containerHeight, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            hasSameSpotRow: hasSameSpot
        ))
        .sheetChrome()
        .accessibilityElement(children: .contain)
    }

    private var hasSameSpot: Bool { sameSpot.count > 1 }

    /// 同じ場所の店を切り替える列（見出し＋横スクロールのチップ）。チップの先頭はピンと同じ形・色
    private var sameSpotRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("同じ場所に\(sameSpot.count)店")
                .font(.caption.bold())
                .foregroundStyle(Color(.secondaryLabel))
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sameSpot) { other in
                        sameSpotChip(other)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func sameSpotChip(_ other: CafeWithDistance) -> some View {
        let isCurrent = other.cafe.id == item.cafe.id
        let category = MapPinCategory.category(for: other.cafe)
        // 色だけでなく形でも分類が分かるよう、ピンと同じ形・色の小さな画像を使う（原則I）
        let pin = MapPinRenderer.image(for: MapPinStyle(category: category, isFavorite: false, isDimmed: false))
        return Button {
            onSelectSameSpot(other)
        } label: {
            HStack(spacing: 6) {
                Image(uiImage: pin)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text(other.cafe.name)
                    .font(.subheadline.weight(isCurrent ? .bold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(isCurrent ? Color.brand : Color(.label))
            .padding(.horizontal, 12)
            .frame(maxWidth: 240, minHeight: 44)
            .background(isCurrent ? Color.brand.opacity(0.12) : Color(.secondarySystemBackground), in: Capsule())
            .overlay(Capsule().stroke(isCurrent ? Color.brand : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(other.cafe.name)、\(category.legendTitle)、同じ場所の店に切り替える"))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
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

    /// 店名・答え1行・条件の要点・営業と徒歩の目安
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
            // 幅が足りないと見た目では補足が省略される。VoiceOver は補足込みで読む
            AnswerLineView(cafe: cafe)
                .accessibilityLabel(Text(verbatim: CafePresentation.answerLine(for: cafe, dog: dog).spoken))
            if let condition = CafePresentation.conditionSummary(for: cafe) {
                Text(condition)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(isLarge ? nil : 2)
            }
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
    /// 行った店は「行った」の表示にし、押すとメニュー（行きたいに戻す／保存から外す）を出す
    /// （タップ1回で行った記録を消さない。詳細の保存ボタンと同じ選択肢）。
    @ViewBuilder
    private var savedButton: some View {
        if savedStatus == .visited {
            // 行った店: タップ1回で行った記録が消えないよう、詳細と同じ選択肢をメニューで出す
            let state = SaveStateButton.make(status: .visited, visitedDate: nil)
            Menu {
                ForEach(state.menuActions, id: \.self) { action in
                    Button(role: action.isDestructive ? .destructive : nil) {
                        onSaveAction(action)
                    } label: {
                        Label(action.menuTitle(from: .visited), systemImage: action.systemImage)
                    }
                }
            } label: {
                CafeDetailActionLabel(title: String(localized: "行った"), systemImage: "checkmark.circle.fill")
            }
            .menuOrder(.fixed)
            .accessibilityLabel(Text(state.accessibilityLabel))
        } else {
            let isWantToGo = savedStatus == .wantToGo
            Button(action: onToggleWantToGo) {
                CafeDetailActionLabel(
                    title: String(localized: "行きたい"),
                    systemImage: isWantToGo ? "pawprint.fill" : "pawprint"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isWantToGo ? "行きたいから外す" : "行きたいに入れる"))
        }
    }

    private var walkingText: String {
        if let detail = walking.detail { return "\(walking.headline)・\(detail)" }
        return walking.headline
    }
}
