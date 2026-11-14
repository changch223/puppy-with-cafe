import SwiftUI

/// ピンで開いた店のカードを、左右にめくれるようにした列。めくる順は一覧（`items`）の並びそのもの（近い順など・同じ絞り込み）。
/// 端では止まる（輪にしない）。隣のカードの端が少し見える。全カードを一度に作らず（LazyHStack）、
/// 写真を取りに行くのはいま選んでいるカードだけ（めくる途中の先の店まで通信しない）。
/// 選んでいる店（`selected`）が外から変わったとき（ピン・同じ場所の列・検索）は、その店のカードへ動く。
struct PlaceCardPager: View {
    let items: [CafeWithDistance]
    let selected: CafeWithDistance
    let savedPlaces: SavedPlaces
    let now: Date
    let isTargetTime: Bool
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    /// 店ごとの「同じ場所」の組（その店を含む。2店以上のときだけカードに列を出す）
    let sameSpot: (CafeWithDistance) -> [CafeWithDistance]
    /// めくって別の店のカードに替わった／同じ場所の列で別の店を選んだ
    let onSelect: (CafeWithDistance) -> Void
    let onShowDetail: (Cafe) -> Void
    let onOpenRoute: (Cafe) -> Void
    let onToggleWantToGo: (UUID) -> Void
    let onClose: () -> Void
    let onSaveAction: (SaveAction, UUID) -> Void

    @State private var position: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 隣のカードの端が見えるよう、カードの幅は画面より狭くする（左右の余白12＋隣の端）
    private static let sideMargin: CGFloat = 12
    private static let cardSpacing: CGFloat = 8
    private static let peekWidth: CGFloat = 20
    /// めくって止まったとみなすまでの待ち時間（0.18秒）
    private static let settleDelay: UInt64 = 180_000_000

    init(
        items: [CafeWithDistance], selected: CafeWithDistance, savedPlaces: SavedPlaces, now: Date, isTargetTime: Bool,
        containerWidth: CGFloat, containerHeight: CGFloat,
        sameSpot: @escaping (CafeWithDistance) -> [CafeWithDistance],
        onSelect: @escaping (CafeWithDistance) -> Void,
        onShowDetail: @escaping (Cafe) -> Void, onOpenRoute: @escaping (Cafe) -> Void,
        onToggleWantToGo: @escaping (UUID) -> Void, onClose: @escaping () -> Void,
        onSaveAction: @escaping (SaveAction, UUID) -> Void
    ) {
        self.items = items
        self.selected = selected
        self.savedPlaces = savedPlaces
        self.now = now
        self.isTargetTime = isTargetTime
        self.containerWidth = containerWidth
        self.containerHeight = containerHeight
        self.sameSpot = sameSpot
        self.onSelect = onSelect
        self.onShowDetail = onShowDetail
        self.onOpenRoute = onOpenRoute
        self.onToggleWantToGo = onToggleWantToGo
        self.onClose = onClose
        self.onSaveAction = onSaveAction
        _position = State(initialValue: selected.id)
    }

    private var cardWidth: CGFloat {
        max(containerWidth - Self.sideMargin - Self.cardSpacing - Self.peekWidth, 200)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .bottom, spacing: Self.cardSpacing) {
                ForEach(items) { item in
                    card(for: item)
                        .frame(width: cardWidth)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, Self.sideMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .leading)
        .scrollClipDisabled()
        // めくって止まった先の店を選ぶ（地図のピンが選ばれ、見える範囲の外なら地図が動く）
        // 止まるのを少し待ってから選ぶ。めくっている途中や、遠い店へ自動で動く途中に通り過ぎる店を選ばない（地図も動かさない）
        .task(id: position) {
            guard let newID = position, newID != selected.id else { return }
            try? await Task.sleep(nanoseconds: Self.settleDelay)
            guard !Task.isCancelled, position == newID,
                  let item = items.first(where: { $0.cafe.id == newID }) else { return }
            onSelect(item)
        }
        // 外から選ぶ店が変わった（ピン・同じ場所の列・検索）ときは、その店のカードへ動く
        .onChange(of: selected.id) { _, newID in
            guard position != newID else { return }
            move(to: newID)
        }
    }

    private func card(for item: CafeWithDistance) -> some View {
        let isCurrent = item.cafe.id == selected.id
        return PlaceCardView(
            item: item,
            savedStatus: savedPlaces.status(of: item.cafe.id),
            now: now,
            isTargetTime: isTargetTime,
            // 「同じ場所」の列は選んでいるカードだけに出す（隣のカードだけ背が高くなって、上の現在地ボタンに重ならないように）
            sameSpot: isCurrent ? sameSpot(item) : [],
            containerHeight: containerHeight,
            onShowDetail: { onShowDetail(item.cafe) },
            onOpenRoute: { onOpenRoute(item.cafe) },
            onToggleWantToGo: { onToggleWantToGo(item.cafe.id) },
            onClose: onClose,
            onSelectSameSpot: onSelect,
            onSaveAction: { onSaveAction($0, item.cafe.id) },
            position: isCurrent ? CardPaging.position(of: item.cafe.id, in: items) : nil,
            onPage: page,
            allowsNetwork: isCurrent
        )
    }

    private func move(to id: UUID) {
        if reduceMotion {
            position = id
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { position = id }
        }
    }

    /// VoiceOver の「次の店」「前の店」。移動したあと、店名と何店目かを読み上げる
    private func page(_ direction: CardPaging.Direction) {
        guard let target = CardPaging.neighbor(of: selected.id, direction: direction, in: items) else { return }
        move(to: target.cafe.id)
        guard let place = CardPaging.position(of: target.cafe.id, in: items) else { return }
        AccessibilityNotification.Announcement(
            String(localized: "\(target.cafe.name)、\(place.number)店目")
        ).post()
    }
}
