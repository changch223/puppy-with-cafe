import SwiftUI

/// 下部引き出し一覧シートの3段階の高さ（再設計 段階1a: 見出しだけ／半分／ほぼ全画面）。
/// 高さ計算・最近傍段の判定は UI 非依存の純ロジックとして分離し、XCTest で検証する（憲章 原則IV）。
enum CafeSheetDetent: CaseIterable, Equatable {
    /// グラバー＋見出し＋1行目が少し見える程度の最小段
    case peek
    /// 地図領域の約45%
    case medium
    /// 検索バーと条件チップの下までのほぼ全画面
    case large

    /// peekの基本の高さ（文字が大きいときは見出しに合わせて伸びる。`peekHeight(headerBlockHeight:)`）
    static let peekHeight: CGFloat = 96
    /// peekで1行目が少し見える分の高さ
    static let peekRowHint: CGFloat = 24
    /// medium の地図領域に対する割合
    static let mediumRatio: CGFloat = 0.45
    /// 店のカード表示中の高さの割合・下限（medium より少し低い固定の高さ）
    static let cardRatio: CGFloat = 0.40
    static let cardMinHeight: CGFloat = 300

    /// 「見出しだけ」の段の高さ。グラバー＋見出し（Dynamic Type で伸びる）の実測の高さ＋1行目の覗き分。
    /// 基本の高さより小さくならない。
    static func peekHeight(headerBlockHeight: CGFloat) -> CGFloat {
        max(peekHeight, headerBlockHeight + peekRowHint)
    }

    /// VoiceOver で読む今の段の名前
    var accessibilityName: String {
        switch self {
        case .peek: return String(localized: "見出しだけ")
        case .medium: return String(localized: "半分")
        case .large: return String(localized: "ほぼ全画面")
        }
    }

    /// 地図表示領域（コンテナ）の高さに対する各段の実際の高さ。
    /// - Parameters:
    ///   - topReserved: 上に残す高さ（検索バー＋条件チップ＋バナーなど）。large はここまでを空ける。
    ///   - peekHeight: 「見出しだけ」の段の高さ（既定は基本の高さ。半分より高くはならない）
    func height(
        containerHeight: CGFloat,
        topReserved: CGFloat = 0,
        peekHeight: CGFloat = CafeSheetDetent.peekHeight
    ) -> CGFloat {
        switch self {
        case .peek:
            return min(peekHeight, containerHeight * Self.mediumRatio)
        case .medium:
            return containerHeight * Self.mediumRatio
        case .large:
            let mediumHeight = containerHeight * Self.mediumRatio
            return max(containerHeight - topReserved, mediumHeight)
        }
    }

    /// 店のカードを出しているときのシートの高さ（段とは別の固定の高さ。小さな画面では上限を設ける）
    static func cardHeight(containerHeight: CGFloat) -> CGFloat {
        min(max(containerHeight * cardRatio, cardMinHeight), containerHeight * 0.8)
    }

    /// ドラッグ終了時点の高さから最も近い段を求める純関数。
    static func nearest(
        toHeight height: CGFloat,
        containerHeight: CGFloat,
        topReserved: CGFloat = 0,
        peekHeight: CGFloat = CafeSheetDetent.peekHeight
    ) -> CafeSheetDetent {
        allCases.min { lhs, rhs in
            abs(lhs.height(containerHeight: containerHeight, topReserved: topReserved, peekHeight: peekHeight) - height)
                < abs(rhs.height(containerHeight: containerHeight, topReserved: topReserved, peekHeight: peekHeight) - height)
        } ?? .peek
    }

    /// 見出しタップで次の段へ進む純関数（見出しだけ→半分→ほぼ全画面→見出しだけ）。
    func toggled() -> CafeSheetDetent {
        switch self {
        case .peek: return .medium
        case .medium: return .large
        case .large: return .peek
        }
    }
}

/// 下部から引き出せるカフェ一覧のカスタムシート。
/// system の `.sheet` は使わない（タブバーを覆わず、単一の `NavigationStack` を保って行タップの詳細遷移と両立させるため）。
/// 中身は `CafeListViewModel.displayedResults` をそのまま流用し、地図・一覧で表示結果を乖離させない（FR-003）。
struct CafeBottomSheet: View {
    /// 地図表示領域（親のZStack）の高さ
    let containerHeight: CGFloat
    /// 検索バー・条件チップなど、シートを大きく開いても隠さない上部の高さ
    let topReserved: CGFloat
    @Binding var detent: CafeSheetDetent
    let headline: SheetHeadline.Text
    @Binding var sortOrder: CafeSortOrder
    let items: [CafeWithDistance]
    /// 保存の状態（行きたい／行った）を行に出すため
    let savedStatuses: SavedPlaces
    /// 営業の判定に使う時刻（対象時刻があればその時刻）
    let now: Date
    /// `now` が「いつ行く？」で決めた対象時刻か（営業の行の言い方が変わる）
    let isTargetTime: Bool
    /// 今の時刻（「情報が古い可能性」の判定。対象時刻ではなく今で判定する）
    let clock: Date
    /// フィルタ起因の0件か（true の時のみシート内に「条件に合うお店がありません」を出す）
    let isEmptyDueToFilter: Bool
    /// 「未確認の店も見る（N件）」の N（今の条件のまま未確認の店を足した件数）
    let unverifiedCandidateCount: Int
    @Binding var includeUnverified: Bool
    let onResetFilters: () -> Void

    /// ドラッグ中の追従用オフセット（離すと `withAnimation` でスプリングスナップしつつ0に戻す）
    @State private var dragTranslation: CGFloat = 0
    /// グラバー＋見出しの実測の高さ（文字が大きいときも見出しが切れないよう「見出しだけ」の段を伸ばす）
    @State private var headerBlockHeight: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var peekHeight: CGFloat { CafeSheetDetent.peekHeight(headerBlockHeight: headerBlockHeight) }

    private func height(of detent: CafeSheetDetent) -> CGFloat {
        detent.height(containerHeight: containerHeight, topReserved: topReserved, peekHeight: peekHeight)
    }

    private var baseHeight: CGFloat { height(of: detent) }

    private var currentHeight: CGFloat {
        let proposed = baseHeight - dragTranslation
        return min(max(proposed, height(of: .peek)), height(of: .large))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                grabber
                header
            }
            .background(
                GeometryReader { inner in
                    Color.clear.preference(key: SheetHeaderHeightKey.self, value: inner.size.height)
                }
            )
            .onPreferenceChange(SheetHeaderHeightKey.self) { headerBlockHeight = $0 }
            Divider()
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentHeight, alignment: .top)
        .sheetChrome()
    }

    // MARK: - 見出し

    /// グラバー（ドラッグ・タップで段を切り替える領域）
    private var grabber: some View {
        Capsule()
            .fill(Color(.tertiaryLabel))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
            .modifier(HandleGestures(onTap: toggleDetent, drag: dragGesture))
            .accessibilityHidden(true)
    }

    private var header: some View {
        // 大きな文字サイズでは並び替えを見出しの下に回し、見出しの幅を確保する
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(headline.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(headline.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .modifier(HandleGestures(onTap: toggleDetent, drag: dragGesture))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(Text("一覧の高さ: \(detent.accessibilityName)"))
            .accessibilityHint(Text("タップまたはドラッグして一覧の高さを切り替えられます"))

            sortMenu
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private var sortMenu: some View {
        Menu {
            Picker(String(localized: "並び替え"), selection: $sortOrder) {
                Text("近い順").tag(CafeSortOrder.distance)
                Text("確認日が新しい順").tag(CafeSortOrder.recentlyVerified)
            }
        } label: {
            HStack(spacing: 2) {
                Text(sortOrder == .distance ? "近い順" : "確認日順")
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
            }
            .font(.footnote.bold())
            .foregroundStyle(Color.brand)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.brand.opacity(0.12), in: Capsule())
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("並び替え"))
        .accessibilityValue(Text(sortOrder == .distance ? "近い順" : "確認日が新しい順"))
    }

    private func toggleDetent() {
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86)) {
            detent = detent.toggled()
        }
    }

    private var dragGesture: some Gesture {
        // タップとの取りこぼしを避けるため、指が数pt動いただけではドラッグ扱いにしない
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let proposedHeight = baseHeight - value.translation.height
                let nextDetent = CafeSheetDetent.nearest(
                    toHeight: proposedHeight, containerHeight: containerHeight,
                    topReserved: topReserved, peekHeight: peekHeight
                )
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86)) {
                    detent = nextDetent
                    dragTranslation = 0
                }
            }
    }

    // MARK: - 中身

    @ViewBuilder
    private var content: some View {
        if isEmptyDueToFilter {
            emptyStateView
        } else {
            List {
                ForEach(items) { item in
                    NavigationLink(value: item.cafe) {
                        CafeRowView(
                            item: item,
                            savedStatus: savedStatuses.status(of: item.cafe.id),
                            now: now,
                            isTargetTime: isTargetTime,
                            clock: clock
                        )
                    }
                }
                if showsUnverifiedRow {
                    unverifiedRow
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    /// 一覧の最後の「未確認の店も見る（N件）」。オンのときは隠すための行にする。
    private var showsUnverifiedRow: Bool {
        includeUnverified || unverifiedCandidateCount > 0
    }

    private var unverifiedRow: some View {
        Button {
            includeUnverified.toggle()
        } label: {
            HStack {
                Image(systemName: includeUnverified ? "eye.slash" : "questionmark.circle")
                Text(includeUnverified
                    ? String(localized: "未確認の店を隠す")
                    : String(localized: "未確認の店も見る（\(unverifiedCandidateCount)件）"))
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(Color.brand)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    /// フィルタ起因の0件
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("条件に合うお店がありません")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button {
                onResetFilters()
            } label: {
                Label(String(localized: "条件をクリア"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(BrandProminentButtonStyle())
            .fixedSize()
            if showsUnverifiedRow {
                unverifiedRow
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// グラバー＋見出しの高さを親へ伝える
private struct SheetHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// グラバー・見出しのタップ（次の段へ）とドラッグ（段の切り替え）
private struct HandleGestures<Drag: Gesture>: ViewModifier {
    let onTap: () -> Void
    let drag: Drag

    func body(content: Content) -> some View {
        content
            .gesture(drag)
            .onTapGesture(perform: onTap)
    }
}

extension View {
    /// 一覧シート・店のカードに共通の見た目（角丸の面＋影）
    func sheetChrome() -> some View {
        clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
    }
}
