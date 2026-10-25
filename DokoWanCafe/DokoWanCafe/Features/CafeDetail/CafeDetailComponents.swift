import SwiftUI
import UIKit

// 店詳細の再設計（段階1b）で使う部品。1a の共通部品とは独立させるため、ここで完結させる。

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

/// 可否ステータスの小チップ（参考記事カード用。1a の共通バッジには依存しない）。
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

/// 画面最上部の帯。画像が取れる店は写真（高さ200）、ない店は店IDから決まる色の帯（高さ120）に頭文字。
struct CafeDetailHeroBand: View {
    let cafe: Cafe
    /// 取得の結果（帯に出した写真の取得元URL。出さなかったら nil）。「写真・雰囲気」で同じ画像を繰り返さないために使う。
    let onResolve: (URL?) -> Void

    @State private var photo: UIImage?
    @State private var photoSourceLabel: String?

    static let photoHeight: CGFloat = 200
    static let bandHeight: CGFloat = 120

    var body: some View {
        Color.clear
            .frame(height: photo != nil ? Self.photoHeight : Self.bandHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholderBand
                }
            }
            .clipped()
            // 取得元の表示は切り抜きの外側に重ねる（画像の大きさに引きずられて下端で切れないように）
            .overlay(alignment: .bottomLeading) {
                if photo != nil, let photoSourceLabel {
                    Text("取得元: \(photoSourceLabel)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: photo != nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(cafe.name)の写真"))
            // 写真がない帯（色と頭文字だけ）は装飾なので VoiceOver から隠す
            .accessibilityHidden(photo == nil)
            .task(id: cafe.id) { await loadPhoto() }
    }

    private var placeholderBand: some View {
        let hue = CafeDetailBand.hue(for: cafe.id)
        let initial = CafeDetailBand.initial(of: cafe.name)
        return ZStack {
            LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.38, brightness: 0.58),
                    Color(hue: hue, saturation: 0.30, brightness: 0.48),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if initial.isEmpty {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text(initial)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    /// 既存の写真プレビュー（PhotoSourceResolver + LinkPreviewService）で画像が取れたときだけ写真にする。
    private func loadPhoto() async {
        guard let url = PhotoSourceResolver.previewSourceURL(for: cafe) else {
            onResolve(nil)
            return
        }
        let preview = await LinkPreviewService.shared.preview(for: url)
        guard let image = preview?.image, CafeDetailBand.isUsablePhoto(size: image.size) else {
            onResolve(nil)
            return
        }
        photoSourceLabel = cafe.links?.first(where: { $0.resolvedURL == url })?.type.displayName
        photo = image
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

// MARK: - 3つの要点

struct CafeDetailHighlightTiles: View {
    let highlights: [CafeDetailHighlight]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 大きな文字では横3列だと時刻などが途中で折れて意味が欠けるため、縦に積む
    private var layout: AnyLayout {
        dynamicTypeSize >= .xxxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
    }

    var body: some View {
        layout {
            ForEach(highlights, id: \.title) { highlight in
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
        }
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
                    Label(evidence.text, systemImage: "checkmark.seal")
                        .font(.subheadline)
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
