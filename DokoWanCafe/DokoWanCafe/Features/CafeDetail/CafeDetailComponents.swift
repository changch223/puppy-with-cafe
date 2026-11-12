import SwiftUI
import UIKit

// 店詳細の再設計（段階1b）で使う部品。

// MARK: - 色

extension Color {
    /// ライト/ダークで色を切り替える（文字色に使う濃い色をライトで確保するため）
    fileprivate static func cafeDetailAdaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static let cafeDetailGreen = cafeDetailAdaptive(
        light: UIColor(red: 0.05, green: 0.48, blue: 0.22, alpha: 1), dark: .systemGreen)
    static let cafeDetailTeal = cafeDetailAdaptive(
        light: UIColor(red: 0.00, green: 0.45, blue: 0.50, alpha: 1), dark: .systemTeal)
    static let cafeDetailOrange = cafeDetailAdaptive(
        light: UIColor(red: 0.74, green: 0.36, blue: 0.00, alpha: 1), dark: .systemOrange)
    static let cafeDetailBlue = cafeDetailAdaptive(
        light: UIColor(red: 0.00, green: 0.34, blue: 0.84, alpha: 1), dark: .systemBlue)
    static let cafeDetailRed = cafeDetailAdaptive(
        light: UIColor(red: 0.76, green: 0.12, blue: 0.12, alpha: 1), dark: .systemRed)
}

// MARK: - 共通

/// SafariView(sheet) 提示用の識別可能なURLラッパー（アプリ内ブラウザ表示を `.sheet(item:)` で一元管理する）。
struct CafeDetailSafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// 詳細画面のカード（背景付きのまとまり）。
struct CafeDetailCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 「見出し（小）＋値」の縦並び1項目。大きな文字でも切れないよう常に縦に積む。
struct CafeDetailInfoRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            value
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 折り返して並べる簡易レイアウト（添え書きチップ用）。
struct CafeDetailFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// 可否ステータスの小チップ（根拠のシートの参考記事カード用）。
struct CafeDetailStatusChip: View {
    let status: DogPolicyStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
            .accessibilityLabel(Text("この記事の犬同伴の判定: \(status.displayName)"))
    }

    private var color: Color {
        switch status {
        case .allowed: return .cafeDetailGreen
        case .conditional: return .cafeDetailOrange
        case .notAllowed: return .cafeDetailRed
        case .unverified: return .secondary
        }
    }
}

// MARK: - 写真の帯

/// 画面最上部の帯。画像が取れる店は写真（高さ200）、ない店は店の場所の小さな地図（高さ120。`CafeDetailMapBand`）。
/// 写真の取得中は無地の帯にして、頭文字や地図が一瞬出てから切り替わる点滅をなくす。
struct CafeDetailHeroBand: View {
    let cafe: Cafe
    /// 取得の結果（帯に出した写真の取得元URL。出さなかったら nil）。「写真・雰囲気」で同じ画像を繰り返さないために使う。
    let onResolve: (URL?) -> Void

    private enum Phase {
        /// 写真の候補があり、取得中
        case pending
        case photo(UIImage, sourceLabel: String?)
        /// 写真なし（候補がない・取得できない・小さすぎる）→ 地図
        case none
    }

    @State private var phase: Phase

    static let photoHeight: CGFloat = 200
    static let bandHeight: CGFloat = 120

    init(cafe: Cafe, onResolve: @escaping (URL?) -> Void) {
        self.cafe = cafe
        self.onResolve = onResolve
        _phase = State(initialValue: PhotoSourceResolver.previewSourceURL(for: cafe) != nil ? .pending : .none)
    }

    private var hasPhoto: Bool {
        if case .photo = phase { return true }
        return false
    }

    var body: some View {
        Group {
            switch phase {
            case .pending:
                Color(.secondarySystemBackground)
                    .frame(height: Self.bandHeight)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            case .none:
                CafeDetailMapBand(cafe: cafe)
            case .photo(let image, let sourceLabel):
                Color.clear
                    .frame(height: Self.photoHeight)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    // 取得元の表示は切り抜きの外側に重ねる（画像の大きさに引きずられて下端で切れないように）
                    .overlay(alignment: .bottomLeading) {
                        if let sourceLabel {
                            Text("取得元: \(sourceLabel)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.45), in: Capsule())
                                .foregroundStyle(.white)
                                .padding(10)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(cafe.name)の写真"))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasPhoto)
        .task(id: cafe.id) { await loadPhoto() }
    }

    /// 既存の写真プレビュー（PhotoSourceResolver + LinkPreviewService）で画像が取れたときだけ写真にする。
    private func loadPhoto() async {
        guard let url = PhotoSourceResolver.previewSourceURL(for: cafe) else {
            phase = .none
            onResolve(nil)
            return
        }
        let preview = await LinkPreviewService.shared.preview(for: url)
        guard let image = preview?.image, CafeDetailBand.isUsablePhoto(size: image.size) else {
            phase = .none
            onResolve(nil)
            return
        }
        let label = cafe.links?.first(where: { $0.resolvedURL == url })?.type.displayName
        phase = .photo(image, sourceLabel: label)
        onResolve(url)
    }
}

// MARK: - 答えのカード

struct CafeDetailAnswerCard: View {
    let answer: CafeDetailAnswer
    let evidence: CafeDetailEvidence
    /// 最終確認から1年以上たっている（FR-010）
    let isStale: Bool
    let onTapEvidence: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: symbol)
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(answer.headline)
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(tint)

                if let condition = answer.conditionLine {
                    Text(condition)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let sizeLimit = answer.sizeLimitLine {
                    Text(sizeLimit)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !answer.notes.isEmpty {
                    CafeDetailFlowLayout {
                        ForEach(answer.notes, id: \.self) { note in
                            Text(note)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(tint.opacity(0.15)))
                                .foregroundStyle(tint)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Divider()

            Button(action: onTapEvidence) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(
                            evidence.text,
                            systemImage: evidence.textIsWarning ? "exclamationmark.triangle.fill" : "checkmark.seal"
                        )
                        .font(evidence.textIsWarning ? .caption.bold() : .caption)
                        .foregroundStyle(evidence.textIsWarning ? Color.cafeDetailOrange : Color.secondary)
                        if evidence.hasConflict {
                            Label(String(localized: "出典に食い違いあり"), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(Color.cafeDetailOrange)
                        }
                        if isStale {
                            Label(String(localized: "最終確認から1年以上たっています"), systemImage: "clock.badge.exclamationmark")
                                .font(.caption)
                                .foregroundStyle(Color.cafeDetailOrange)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(evidenceAccessibilityLabel))
            .accessibilityHint(Text("タップして根拠の詳細を開きます"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                tint.opacity(0.10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.35), lineWidth: 1))
    }

    private var evidenceAccessibilityLabel: String {
        var parts = [String(localized: "根拠: \(evidence.text)")]
        if evidence.hasConflict { parts.append(String(localized: "出典に食い違いあり")) }
        if isStale { parts.append(String(localized: "最終確認から1年以上たっています")) }
        return parts.joined(separator: "。")
    }

    private var symbol: String {
        switch answer.kind {
        case .indoor, .terrace: return "checkmark.circle.fill"
        case .conditional: return "exclamationmark.circle.fill"
        case .seatUnknown: return "info.circle.fill"
        case .notAllowed: return "xmark.circle.fill"
        case .unverified: return "questionmark.circle.fill"
        }
    }

    private var tint: Color {
        switch answer.kind {
        case .indoor: return .cafeDetailGreen
        case .terrace: return .cafeDetailTeal
        case .conditional: return .cafeDetailOrange
        case .seatUnknown: return .cafeDetailBlue
        case .notAllowed: return .cafeDetailRed
        case .unverified: return .secondary
        }
    }
}

// MARK: - 要点（分かっていることだけ）

struct CafeDetailHighlightTiles: View {
    let highlights: [CafeDetailHighlight]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 横に並べる最大の列数（タイルが1〜2個でも1枚の幅は3列のときと同じ＝間延びしない）
    private static let columns = 3

    /// 大きな文字では横3列だと時刻などが途中で折れて意味が欠けるため、縦に積む
    private var isStacked: Bool { dynamicTypeSize >= .xxxLarge }

    var body: some View {
        if !highlights.isEmpty {
            if isStacked {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(highlights, id: \.title) { tile($0) }
                }
            } else {
                // 等幅で左から並べる。空いた列は透明の枠で埋めて、残りのタイルの幅を揃える
                HStack(alignment: .top, spacing: 8) {
                    ForEach(highlights.prefix(Self.columns), id: \.title) { tile($0) }
                    ForEach(0..<max(0, Self.columns - highlights.count), id: \.self) { _ in
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 1)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func tile(_ highlight: CafeDetailHighlight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(highlight.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(highlight.value)
                .font(.subheadline.bold())
                .foregroundStyle(color(for: highlight.tone))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(highlight.title): \(highlight.value)"))
    }

    private func color(for tone: CafeDetailHighlight.Tone) -> Color {
        switch tone {
        case .good: return .cafeDetailGreen
        case .caution: return .cafeDetailOrange
        case .neutral: return .primary
        case .unknown: return .secondary
        }
    }
}

// MARK: - まだ分かっていないこと

/// タイルの下の1か所のまとめ。橙系の文字だが警告アイコンは付けない（欠けている情報を「注意」とまでは言わない）。
struct CafeDetailUnknownsLine: View {
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("まだ分かっていないこと")
                    .font(.footnote.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(items.joined(separator: "・"))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("来店前にお店へご確認ください")
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(Color.cafeDetailOrange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cafeDetailOrange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - 画面下の固定バー

/// 画面下に固定する操作のバー: 経路（主）・電話（あれば）・保存の状態ボタン。
/// 最大の文字サイズでも縦積みにせず（画面を占めてしまうため）、アイコン＋短いラベルの横並びを保つ。
struct CafeDetailBottomBar: View {
    let hasPhone: Bool
    let saved: SaveStateButton
    let onRoute: () -> Void
    let onCall: () -> Void
    let onSaveAction: (SaveAction) -> Void

    static let buttonHeight: CGFloat = 48
    /// 外側（バーの打ち止め前）の文字サイズ。大きいときは電話をアイコンだけにして幅を空ける
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onRoute) {
                barLabel(String(localized: "経路"), systemImage: "arrow.triangle.turn.up.right.diamond.fill", flexible: true)
                    .foregroundStyle(Color.onBrand)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("経路案内を開く"))

            // 電話がある店のみ。無い店は他のボタンが広がる。
            if hasPhone {
                Button(action: onCall) {
                    barLabel(String(localized: "電話"), systemImage: "phone.fill", showsTitle: !dynamicTypeSize.isAccessibilitySize)
                        .foregroundStyle(Color.accentColor)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("電話をかける"))
            }

            saveButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // 最大の文字サイズでは横並びを保ったまま、これ以上大きくしない
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    /// `flexible`: 経路ボタンは余った幅を取る。電話・保存は文字の幅に合わせて、ラベルが隠れないようにする。
    /// 大きな文字では、どのボタンも縮めて1行に収める（縦に積まない）。
    private func barLabel(
        _ title: String, systemImage: String, flexible: Bool = false, showsTitle: Bool = true
    ) -> some View {
        let large = dynamicTypeSize.isAccessibilitySize
        return HStack(spacing: 6) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            if showsTitle {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(large ? 0.5 : 1)
                    .fixedSize(horizontal: !flexible && !large, vertical: false)
            }
        }
        .font(.subheadline.bold())
        .padding(.horizontal, large ? 10 : 14)
        .frame(maxWidth: flexible ? .infinity : nil, minHeight: Self.buttonHeight)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private var savedLabel: some View {
        barLabel(saved.title, systemImage: saved.systemImage)
            .foregroundStyle(saved.status == nil ? Color.accentColor : Color.cafeDetailOrange)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    /// タップ1回の動きがある状態は primaryAction、行ったのときはタップでメニューを開く（誤って記録を消さない）
    @ViewBuilder
    private var saveButton: some View {
        if let tap = saved.tapAction {
            Menu {
                menuItems
            } label: {
                savedLabel
            } primaryAction: {
                onSaveAction(tap)
            }
            .accessibilityLabel(Text(saved.accessibilityLabel))
        } else {
            Menu {
                menuItems
            } label: {
                savedLabel
            }
            .accessibilityLabel(Text(saved.accessibilityLabel))
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        ForEach(saved.menuActions, id: \.self) { action in
            Button(role: action.isDestructive ? .destructive : nil) {
                onSaveAction(action)
            } label: {
                Label(action.menuTitle(from: saved.status), systemImage: action.systemImage)
            }
        }
    }
}

// MARK: - 操作

/// 操作ボタン1つ分の見た目（アイコン＋短い名前）。主ボタンは塗りつぶし。
struct CafeDetailActionLabel: View {
    let title: String
    let systemImage: String
    var prominent = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // 大きな文字では全幅の横並び（アイコン＋ラベル）にして、ラベルが切れないようにする
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 4))
        layout {
            Image(systemName: systemImage)
                .font(.title3)
            Text(title)
                .font(.caption.bold())
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.7)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(prominent ? Color.white : Color.accentColor)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(prominent ? Color.accentColor : Color(.secondarySystemGroupedBackground))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// スクロール位置の計測用（店名がナビゲーションバーの下に隠れたらバーに店名を出す）
struct CafeDetailTitleOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

// MARK: - 根拠のシート

/// 答えのカードの根拠行をタップして開くシート。参考記事・食い違いの説明・代表表示の決め方・引用の注記を出す。
struct CafeDetailEvidenceSheet: View {
    @ObservedObject var viewModel: CafeDetailViewModel
    let evidence: CafeDetailEvidence
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var safariItem: CafeDetailSafariItem?

    /// OGP代表画像を取得しにいく件数の上限（先頭何件目まで）。これ以降はテキストカードのまま。
    private static let articlePreviewFetchLimit = 5

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // 「出典の記載が食い違っています」のときは、確認済みを示す印ではなく警告の印にする
                    Label(
                        evidence.text,
                        systemImage: evidence.textIsWarning ? "exclamationmark.triangle.fill" : "checkmark.seal"
                    )
                    .font(.subheadline)
                    .foregroundStyle(evidence.textIsWarning ? Color.cafeDetailOrange : Color.primary)
                    if viewModel.isUnverified {
                        warningBox(
                            text: String(localized: "この情報は未確認です。参考記事・確認日のある確定情報ではありません。ご来店前に店舗へ直接ご確認ください。"),
                            systemImage: "questionmark.circle",
                            color: .secondary
                        )
                    }
                    if viewModel.isStale && !viewModel.isUnverified {
                        warningBox(
                            text: String(localized: "この情報は最終確認から1年以上経過しています。最新でない可能性があります。"),
                            systemImage: "clock.badge.exclamationmark",
                            color: .cafeDetailOrange
                        )
                    }
                    if viewModel.hasConflict {
                        warningBox(
                            text: String(localized: "参考記事によって犬同伴可否の情報が食い違っています。各記事の内容と確認日をご確認ください。"),
                            systemImage: "exclamationmark.triangle.fill",
                            color: .cafeDetailOrange
                        )
                    }
                } header: {
                    Text("この判定の根拠")
                } footer: {
                    Text("代表表示は「確認日が新しい参考記事 → 由来の信頼順」で決定しています。確定できない場合は「未確認」になります。")
                }

                Section {
                    if viewModel.sources.isEmpty {
                        phaseRow
                    } else {
                        ForEach(Array(viewModel.sources.enumerated()), id: \.element.id) { index, source in
                            ArticleCardView(
                                source: source,
                                isRepresentative: source.id == viewModel.representativeSource?.id,
                                fetchesPreview: index < Self.articlePreviewFetchLimit,
                                onOpenURL: openSourceURL
                            )
                        }
                        phaseRow
                    }
                } header: {
                    Text("参考記事")
                } footer: {
                    Text("参考記事の代表画像・要約は各記事からの引用であり、詳細は元記事をご確認ください。")
                }
            }
            .navigationTitle(String(localized: "確認の根拠"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
            .sheet(item: $safariItem) { item in
                SafariView(url: item.url)
            }
        }
    }

    /// 参考記事の読み込み中・失敗の表示（失敗時は再試行できる）
    @ViewBuilder
    private var phaseRow: some View {
        switch viewModel.phase {
        case .loading:
            HStack {
                ProgressView()
                Text("参考記事を読み込み中…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("参考記事を取得できませんでした: \(message)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(String(localized: "再試行")) {
                    Task { await viewModel.load() }
                }
                .font(.footnote)
            }
        case .loaded:
            if viewModel.sources.isEmpty {
                Text("この店に紐づく参考記事はありません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// http(s) はアプリ内ブラウザ、instagram/x は外部アプリ（ユニバーサルリンクでアプリが開く方がUX良）。
    private func openSourceURL(_ url: URL) {
        if let host = url.host?.lowercased(),
           host.contains("instagram.com") || host.contains("x.com") || host.contains("twitter.com") {
            openURL(url)
        } else {
            safariItem = CafeDetailSafariItem(url: url)
        }
    }

    private func warningBox(text: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .font(.footnote)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }
}
