import SwiftUI
import UIKit

/// カフェ詳細画面（再設計 段階1b: 答えを先に）。
/// 上から 写真の帯 → 店名 → 答えのカード → 3つの要点 → 操作 → 条件・マナー → 営業時間 → 写真・雰囲気
/// → わんちゃん向け情報 → 公式情報・SNS → 店舗情報 → 誤り報告。
/// 可否・条件・出典・最終確認日を提示し（US2）、矛盾と AI 推測を明示区別する（US4）。
struct CafeDetailView: View {
    @StateObject private var viewModel: CafeDetailViewModel
    private let dependencies: AppDependencies
    @Environment(\.openURL) private var openURL
    @State private var showReport = false
    @State private var showEvidence = false
    @State private var safariItem: CafeDetailSafariItem?
    // 経路チューザー（S1）: 「経路」タップ時にAppleマップ/Googleマップを選ばせる
    @State private var showRouteChooser = false
    // 写真・雰囲気セクションの表示チェーン現在地（IG埋め込み失敗→OGP写真カード失敗→地図案内、の順に遷移）
    @State private var photoTier: PhotoTier?
    @State private var instagramEmbedHeight: CGFloat = OGPPhotoCardView.cardHeight
    // 保存（行きたい／行った・端末ローカル）。地図・一覧・保存タブと同一インスタンスを共有する。
    @ObservedObject private var savedStore: SavedPlacesStore
    // 写真の帯の取得状況。OGP 画像を帯に出した店では「写真・雰囲気」で同じ画像を繰り返さない。
    @State private var heroPhoto: HeroPhoto
    // 店名が画面上から隠れたらナビゲーションバーに店名を出す
    @State private var showsNavigationTitle = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum HeroPhoto: Equatable {
        case pending
        case photo(URL)
        case none
    }

    private static let scrollSpace = "cafeDetailScroll"

    init(cafe: Cafe, dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: CafeDetailViewModel(cafe: cafe, repository: dependencies.repository)
        )
        let tier = Self.initialPhotoTier(for: cafe)
        _photoTier = State(initialValue: tier)
        _heroPhoto = State(
            initialValue: PhotoSourceResolver.previewSourceURL(for: cafe) != nil
                ? .pending : .none
        )
        _savedStore = ObservedObject(wrappedValue: dependencies.savedStore)
    }

    private var cafe: Cafe { viewModel.cafe }

    var body: some View {
        // 「今日」の判定・曜日表で同じ時刻を使う
        let now = Date()
        GeometryReader { outer in
        ScrollView {
            VStack(spacing: 0) {
                CafeDetailHeroBand(
                    cafe: cafe,
                    onResolve: { url in heroPhoto = url.map { .photo($0) } ?? .none }
                )

                VStack(spacing: 16) {
                    titleRow

                    CafeDetailMyDogLine(cafe: cafe)

                    CafeDetailAnswerCard(
                        answer: CafeDetailAnswer.make(cafe: cafe),
                        evidence: CafeDetailEvidence.make(
                            sourceType: viewModel.representativeSource?.type,
                            lastVerified: cafe.lastVerified,
                            hasConflict: viewModel.hasConflict
                        ),
                        isStale: viewModel.isStale && CafeDetailAnswer.isConfirmed(cafe),
                        onTapEvidence: { showEvidence = true }
                    )

                    CafeDetailHighlightTiles(highlights: CafeDetailHighlights.all(cafe: cafe, at: now))

                    actionRow

                    visitedButton

                    if hasConditionInfo {
                        conditionCard
                    }

                    if hasHoursInfo {
                        hoursCard(now: now)
                    }

                    photoCard

                    if let amenities = cafe.dogAmenities {
                        amenitiesCard(amenities, confirmed: CafeDetailAnswer.isConfirmed(cafe))
                    }

                    if cafe.links?.isEmpty == false || cafe.operatorNote != nil {
                        linksCard
                    }

                    infoCard

                    // 報告フォーム未設定のときは「準備中」画面を見せず、セクションごと出さない（App Store 審査対応）
                    if AppEnvironment.isReportFormConfigured() {
                        reportCard
                    }
                }
                .padding(16)
            }
        }
        .coordinateSpace(name: Self.scrollSpace)
        .onPreferenceChange(CafeDetailTitleOffsetKey.self) { titleBottom in
            showsNavigationTitle = titleBottom < outer.safeAreaInsets.top
        }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(showsNavigationTitle ? cafe.name : "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .sheet(isPresented: $showReport) {
            ReportView(cafe: cafe)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEvidence) {
            CafeDetailEvidenceSheet(
                viewModel: viewModel,
                evidence: CafeDetailEvidence.make(
                    sourceType: viewModel.representativeSource?.type,
                    lastVerified: cafe.lastVerified,
                    hasConflict: viewModel.hasConflict
                )
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
        }
    }

    private var hasConditionInfo: Bool {
        cafe.dogPolicyCondition != nil || cafe.dogSizeLimit != nil || cafe.dogNote != nil
    }

    private var hasHoursInfo: Bool {
        cafe.hours?.hasAnyDay == true || cafe.hoursText != nil || cafe.holidayNote != nil
    }

    private var telURL: URL? {
        guard let phone = cafe.phone else { return nil }
        return URL(string: "tel://" + phone.filter { $0.isNumber || $0 == "+" })
    }

    // MARK: - 店名・エリア・保存

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cafe.name)
                    .font(.title.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subArea = cafe.subArea {
                    Label(subArea, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            favoriteToggleButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: CafeDetailTitleOffsetKey.self,
                    value: geometry.frame(in: .named(Self.scrollSpace)).maxY
                )
            }
        )
    }

    /// 「行きたい」トグル。ON=塗り肉球。
    private var favoriteToggleButton: some View {
        let isWantToGo = savedStore.isWantToGo(cafe.id)
        return Button {
            savedStore.toggleWantToGo(cafe.id)
        } label: {
            Image(systemName: isWantToGo ? "pawprint.fill" : "pawprint")
                .font(.title2)
                .foregroundStyle(isWantToGo ? Color.cafeDetailOrange : Color.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isWantToGo ? "行きたいから外す" : "行きたいに入れる"))
    }

    // MARK: - 操作（経路・電話・行きたい・共有）

    private var actionRow: some View {
        let isWantToGo = savedStore.isWantToGo(cafe.id)
        // 大きな文字ではボタンを縦に積み、ラベルが途中で切れないようにする
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button {
                showRouteChooser = true
            } label: {
                CafeDetailActionLabel(
                    title: String(localized: "経路"),
                    systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                    prominent: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("経路案内を開く"))
            .confirmationDialog(
                String(localized: "経路を開くアプリを選択"),
                isPresented: $showRouteChooser,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Apple マップ")) {
                    RouteLauncher.open(cafe: cafe, using: .apple)
                }
                Button(String(localized: "Google マップ")) {
                    RouteLauncher.open(cafe: cafe, using: .google)
                }
                Button(String(localized: "キャンセル"), role: .cancel) {}
            }

            // 電話がある店のみ。無い店は他のボタンが広がる。
            if let telURL {
                Button {
                    openURL(telURL)
                } label: {
                    CafeDetailActionLabel(title: String(localized: "電話"), systemImage: "phone.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("電話をかける"))
            }

            Button {
                savedStore.toggleWantToGo(cafe.id)
            } label: {
                CafeDetailActionLabel(
                    title: isWantToGo ? String(localized: "行きたい ✓") : String(localized: "行きたい"),
                    systemImage: isWantToGo ? "pawprint.fill" : "pawprint"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isWantToGo ? "行きたいから外す" : "行きたいに入れる"))

            ShareLink(item: CafeDetailShare.message(for: cafe)) {
                CafeDetailActionLabel(title: String(localized: "共有"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("この店を共有"))
        }
    }

    /// 「行った」ボタン（操作の下の小さなボタン）。押すと行きたいから外して行ったに入れ、「行った ✓ 10/25」と表示する。
    /// もう一度押すと外せる。
    private var visitedButton: some View {
        let visitedDate = savedStore.visitedDate(of: cafe.id)
        let isVisited = visitedDate != nil
        let title = visitedDate.map { String(localized: "行った ✓ \(TargetTime.monthDayText($0))") }
            ?? String(localized: "行った")
        return Button {
            savedStore.toggleVisited(cafe.id)
        } label: {
            Label(title, systemImage: isVisited ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.subheadline.bold())
                .foregroundStyle(isVisited ? Color.onBrand : Color.brand)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Capsule().fill(isVisited ? Color.brand : Color.brand.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Text(visitedDate.map { "行った、\(TargetTime.monthDayText($0))。タップで外す" } ?? "行ったに記録する"))
    }

    // MARK: - 来店時の条件・マナー

    private var conditionCard: some View {
        CafeDetailCard(title: String(localized: "来店時の条件・マナー")) {
            if let condition = cafe.dogPolicyCondition {
                Label(condition, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.cafeDetailOrange)
            }
            // サイズ制限（002/FR-107。例: 小型・中型のみ、抱っこ・カート推奨）
            if let sizeLimit = cafe.dogSizeLimit {
                CafeDetailInfoRow(label: String(localized: "サイズ")) {
                    Text(sizeLimit)
                }
            }
            if let note = cafe.dogNote {
                Label(note, systemImage: "pawprint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 営業時間

    private func hoursCard(now: Date) -> some View {
        CafeDetailCard(title: String(localized: "営業時間")) {
            if let text = cafe.hoursText {
                Text(text)
                    .font(.callout)
            }
            if let hours = cafe.hours, hours.hasAnyDay {
                VStack(spacing: 0) {
                    ForEach(CafeDetailHoursTable.rows(hours: hours, at: now), id: \.weekday) { row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.weekday.displayName)
                                .frame(minWidth: 24, alignment: .leading)
                            if row.isToday {
                                Text("今日")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                    .foregroundStyle(Color.accentColor)
                            }
                            Spacer(minLength: 8)
                            Text(row.text)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                        }
                        .font(row.isToday ? .callout.bold() : .callout)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(row.isToday ? Color.accentColor.opacity(0.08) : Color.clear)
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            if let holidayNote = cafe.holidayNote {
                CafeDetailInfoRow(label: String(localized: "定休日")) {
                    Text(holidayNote)
                }
            }
            hoursConfirmationCaption
        }
    }

    /// 営業時間の確認日・免責（ヘッダーから移設）。二次情報から推定された鮮度を利用者に伝え続ける。
    private var hoursConfirmationCaption: some View {
        Group {
            if let verified = cafe.infoVerified {
                Text("基本情報の確認日: \(verified.formatted(date: .abbreviated, time: .omitted))。最新の営業情報は公式でご確認ください。")
            } else {
                Text("最新の営業情報は公式でご確認ください。")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - 写真・雰囲気（IG投稿埋め込み→OGP写真カード→地図案内の3段フォールバック）

    /// 表示チェーンの現在の段。IG埋め込み・OGP画像取得の失敗時に次段へ遷移する。
    private enum PhotoTier {
        case instagramEmbed(html: String)
        case ogpCard(url: URL, sourceLabel: String, linkType: CafeLinkType)
        case mapsFallback(url: URL)
    }

    /// 初期表示段を決定する: IG代表投稿URLが有効ならそれを優先し、無ければフォールバック段から選ぶ。
    private static func initialPhotoTier(for cafe: Cafe) -> PhotoTier? {
        if let postURL = cafe.instagramPostURL,
           let html = PhotoSourceResolver.instagramEmbedHTML(postURL: postURL) {
            return .instagramEmbed(html: html)
        }
        return fallbackPhotoTier(for: cafe)
    }

    /// IG埋め込み失敗時のフォールバック先（OGP写真カード優先、候補が無ければ地図案内）
    private static func fallbackPhotoTier(for cafe: Cafe) -> PhotoTier? {
        if let url = PhotoSourceResolver.previewSourceURL(for: cafe) {
            let link = cafe.links?.first(where: { $0.resolvedURL == url })
            let label = link?.type.displayName ?? String(localized: "リンク")
            return .ogpCard(url: url, sourceLabel: label, linkType: link?.type ?? .other)
        }
        return mapsOnlyTier(for: cafe)
    }

    /// OGP写真カード取得失敗時のフォールバック先（地図案内のみ）
    private static func mapsOnlyTier(for cafe: Cafe) -> PhotoTier? {
        PhotoSourceResolver.mapsPhotoSearchURL(name: cafe.name, address: cafe.address).map { .mapsFallback(url: $0) }
    }

    /// 実際に出す段。写真の帯が OGP 画像を出した店では、同じ画像の OGP カードは繰り返さず地図案内にする。
    /// 帯の取得が終わるまでは OGP カードを出さない（出してから消えるとレイアウトが跳ねるため）。
    private var displayedPhotoTier: PhotoTier? {
        guard let photoTier else { return nil }
        if case .ogpCard(let url, _, _) = photoTier {
            switch heroPhoto {
            case .pending: return nil
            case .photo(let heroURL) where heroURL == url: return Self.mapsOnlyTier(for: cafe)
            default: break
            }
        }
        return photoTier
    }

    @ViewBuilder
    private var photoCard: some View {
        if let tier = displayedPhotoTier {
            CafeDetailCard(title: String(localized: "写真・雰囲気")) {
                photoContent(for: tier)
            }
        }
    }

    @ViewBuilder
    private func photoContent(for tier: PhotoTier) -> some View {
        switch tier {
        case .instagramEmbed(let html):
            InstagramPostEmbedView(html: html, height: $instagramEmbedHeight) {
                photoTier = Self.fallbackPhotoTier(for: cafe)
            }
            .frame(height: instagramEmbedHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        case .ogpCard(let url, let sourceLabel, let linkType):
            OGPPhotoCardView(url: url, sourceLabel: sourceLabel) {
                // instagram は外部で開く（リンク一覧と同じ原則）。website/tabelog はアプリ内ブラウザのまま。
                if linkType == .instagram {
                    openURL(url)
                } else {
                    safariItem = CafeDetailSafariItem(url: url)
                }
            } onFail: {
                photoTier = Self.mapsOnlyTier(for: cafe)
            }
        case .mapsFallback(let url):
            MapsPhotoFallbackCardView {
                safariItem = CafeDetailSafariItem(url: url)
            }
        }
    }

    // MARK: - わんちゃん向け情報（状態を言葉で: 「店内 ✓ 可」「犬メニュー ? 情報なし」）

    private func amenitiesCard(_ amenities: DogAmenities, confirmed: Bool) -> some View {
        // 大きな文字では「項目名」と「状態」を縦に積み、状態の言葉が欠けないようにする
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return CafeDetailCard(title: String(localized: "わんちゃん向け情報")) {
            VStack(spacing: 0) {
                let rows = CafeDetailAmenities.rows(amenities, confirmed: confirmed)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    rowLayout {
                        Text(row.label)
                            .font(.body)
                        if !dynamicTypeSize.isAccessibilitySize {
                            Spacer(minLength: 8)
                        }
                        Label {
                            Text(row.valueText)
                                .font(.body.bold())
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: symbol(for: row.state))
                        }
                        .foregroundStyle(color(for: row.state))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(row.label): \(row.valueText)"))
                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func symbol(for state: CafeDetailAmenityRow.State) -> String {
        switch state {
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .unknown, .unconfirmed: return "questionmark.circle"
        }
    }

    private func color(for state: CafeDetailAmenityRow.State) -> Color {
        switch state {
        case .yes: return .cafeDetailGreen
        case .no: return .cafeDetailRed
        case .unknown, .unconfirmed: return .secondary
        }
    }

    // MARK: - 公式情報・SNS（002/FR-103/106）

    private var linksCard: some View {
        CafeDetailCard(title: String(localized: "公式情報・SNS")) {
            if let links = cafe.links, !links.isEmpty {
                ForEach(links) { link in
                    if let url = link.resolvedURL {
                        switch link.type {
                        case .website, .tabelog, .other:
                            // アプリ内ブラウザで開く（閉じて即アプリへ復帰できるUX）
                            Button {
                                safariItem = CafeDetailSafariItem(url: url)
                            } label: {
                                linkLabel(link)
                            }
                        default:
                            // instagram/x/google_map は従来通り外部（ユニバーサルリンクでアプリが開く方がUX良）
                            Link(destination: url) {
                                linkLabel(link)
                            }
                        }
                    }
                }
            }
            if let note = cafe.operatorNote {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                        Text("運営メモ（\(note.sourceDisplayName)より・\(note.verifiedAt.formatted(date: .abbreviated, time: .omitted))確認）")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Color.cafeDetailTeal)
                    Text(note.text)
                        .font(.footnote)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.teal.opacity(0.10)))
                .accessibilityElement(children: .combine)

                Text("運営メモは公式SNS等で運営が確認した内容の転記であり、公式の一次情報そのものではありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func linkLabel(_ link: CafeLink) -> some View {
        HStack {
            Label(link.type.displayName, systemImage: link.type.systemImage)
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - 店舗情報（US5/FR-014/T050）

    private var infoCard: some View {
        CafeDetailCard(title: String(localized: "店舗情報")) {
            // 店舗紹介（002/FR-107）。ヘッダーから移設。
            if let description = cafe.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let address = cafe.address {
                CafeDetailInfoRow(label: String(localized: "住所")) {
                    Text(address)
                }
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = address
                    } label: {
                        Label(String(localized: "住所をコピー"), systemImage: "doc.on.doc")
                    }
                }
                .accessibilityHint(Text("長押しでコピーできます"))
            }
            // 電話（タップで発信, 002/FR-106）
            if let phone = cafe.phone, let telURL {
                Link(destination: telURL) {
                    CafeDetailInfoRow(label: String(localized: "電話")) {
                        Text(phone)
                            .foregroundStyle(.tint)
                    }
                }
                .accessibilityLabel(Text("電話をかける: \(phone)"))
            }
            // 予約情報（002/FR-101）
            if let reservation = cafe.reservation {
                CafeDetailInfoRow(label: String(localized: "予約")) {
                    Text(reservation)
                }
            }
            if let contact = cafe.contact {
                if let url = URL(string: contact), url.scheme?.hasPrefix("http") == true {
                    // アプリ内ブラウザで開く
                    Button {
                        safariItem = CafeDetailSafariItem(url: url)
                    } label: {
                        CafeDetailInfoRow(label: String(localized: "連絡先・サイト")) {
                            Text(contact)
                                .foregroundStyle(.tint)
                        }
                    }
                } else {
                    CafeDetailInfoRow(label: String(localized: "連絡先")) {
                        Text(contact)
                    }
                }
            }
        }
    }

    // MARK: - 情報の誤りを報告（US3/T038）

    private var reportCard: some View {
        CafeDetailCard {
            Button {
                showReport = true
            } label: {
                Label(String(localized: "情報の誤りを報告"), systemImage: "exclamationmark.bubble")
            }
            Text("誤り報告は審査（v1: 運営確認）を通過してから反映されます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// 参考記事1件の記事カード（S1: 出典→参考記事の記事カード化）。
/// クリックせずに写真＋要点が分かるよう、OGP代表画像（`LinkPreviewService` で端末側取得。
/// 画像の転載・再ホストはしない）＋記事タイトル＋運営要約（claimed情報・確認日・採用根拠バッジ）を
/// インライン表示する。OGP取得に失敗/対象外の場合はアイコン＋タイトルのテキストカードにフォールバックする。
struct ArticleCardView: View {
    let source: Source
    let isRepresentative: Bool
    /// OGP画像取得を試みるか（先頭何件までに絞るパフォーマンス上限, 設計書S1）
    let fetchesPreview: Bool
    let onOpenURL: (URL) -> Void

    @State private var image: UIImage?
    @State private var previewTitle: String?
    @State private var isLoading: Bool

    private static let thumbnailSize: CGFloat = 64

    init(source: Source, isRepresentative: Bool, fetchesPreview: Bool, onOpenURL: @escaping (URL) -> Void) {
        self.source = source
        self.isRepresentative = isRepresentative
        self.fetchesPreview = fetchesPreview
        self.onOpenURL = onOpenURL
        _isLoading = State(initialValue: fetchesPreview && source.referenceURL != nil)
    }

    /// 記事タイトル（OGPタイトル or 出典種別名, 設計書S1）
    private var title: String { previewTitle ?? source.type.displayName }

    var body: some View {
        Button {
            if let url = source.referenceURL {
                onOpenURL(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if isRepresentative {
                            Text("採用根拠")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                                .foregroundStyle(.blue)
                        }
                    }
                    HStack(spacing: 6) {
                        ProvenanceChip(provenance: source.provenance)
                        CafeDetailStatusChip(status: source.claimedStatus)
                    }
                    HStack(spacing: 4) {
                        Text(source.type.displayName)
                        if let verifiedAt = source.verifiedAt {
                            Text("・確認日: \(verifiedAt.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(source.referenceURL == nil)
        .accessibilityElement(children: .combine)
        .task(id: source.id) {
            guard fetchesPreview, let url = source.referenceURL else {
                isLoading = false
                return
            }
            let preview = await LinkPreviewService.shared.preview(for: url)
            isLoading = false
            image = preview?.image
            previewTitle = preview?.title
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: Self.icon(for: source.type))
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// 出典種別ごとのフォールバックアイコン（`CafeLinkType.systemImage` と対応を揃える）
    private static func icon(for type: SourceType) -> String {
        switch type {
        case .officialHP: return "globe"
        case .sns: return "at"
        case .googleMap: return "map"
        case .tabelog: return "fork.knife"
        case .blog: return "text.bubble"
        case .other: return "link"
        }
    }
}

/// 由来（provenance）チップ。AI推測は紫＋アイコンで確定情報と区別（FR-012）。
struct ProvenanceChip: View {
    let provenance: Provenance

    var body: some View {
        HStack(spacing: 3) {
            if provenance.isAIInferred {
                Image(systemName: "sparkles")
                    .font(.caption2)
            }
            Text(provenance.displayName)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
        .accessibilityLabel(Text(
            provenance.isAIInferred
                ? "由来: AI推測（未確定の情報）"
                : "由来: \(provenance.displayName)"
        ))
    }

    private var color: Color {
        provenance.isAIInferred ? .purple : .teal
    }
}

/// OGP写真カード（写真プレビュー機能・表示チェーン2段目）。
/// リンク先ページの画像を `LinkPreviewService`（`LPMetadataProvider`）で端末側が直接取得して表示する
/// （画像の転載・再ホストはしない）。取得中はプレースホルダを表示し、取得失敗（画像なし含む）時は
/// `onFail` を呼んで、呼び出し側が「地図で写真を見る」カードへフォールバックする。タップで取得元URLを開く。
struct OGPPhotoCardView: View {
    let url: URL
    let sourceLabel: String
    let onTap: () -> Void
    let onFail: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = true

    /// 写真・雰囲気セクションの各カード共通の高さ
    static let cardHeight: CGFloat = 190

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .overlay {
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }

                if image != nil {
                    Text("取得元: \(sourceLabel)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.cardHeight, maxHeight: Self.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(sourceLabel)の写真"))
        .accessibilityHint(Text("タップして\(sourceLabel)を開きます"))
        .task(id: url) {
            let preview = await LinkPreviewService.shared.preview(for: url)
            isLoading = false
            if let fetchedImage = preview?.image {
                image = fetchedImage
            } else {
                onFail()
            }
        }
    }
}

/// 「地図で写真を見る」フォールバックカード（写真プレビュー機能・表示チェーン3段目）。
/// IG投稿埋め込み・OGP写真カードのいずれも使えない場合に、店名・住所からのGoogleマップ検索結果へ案内する。
struct MapsPhotoFallbackCardView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("地図で写真を見る")
                    .font(.subheadline.bold())
                Text("Googleマップで周辺の写真を確認できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: OGPPhotoCardView.cardHeight, maxHeight: OGPPhotoCardView.cardHeight)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }
}
