import SwiftUI
import UIKit

/// SafariView(sheet) 提示用の識別可能なURLラッパー（写真・雰囲気機能: OGP写真カード・地図案内・
/// 出典URL・公式リンク等のアプリ内ブラウザ表示を `.sheet(item:)` で一元管理する）。
private struct SafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// カフェ詳細画面（T032/T035/T046/T047/T048/T050）。
/// 可否・条件・出典・最終確認日を提示し（US2）、矛盾と AI 推測を明示区別する（US4）。
struct CafeDetailView: View {
    @StateObject private var viewModel: CafeDetailViewModel
    private let dependencies: AppDependencies
    @Environment(\.openURL) private var openURL
    @State private var showReport = false
    @State private var safariItem: SafariItem?
    // 経路チューザー（S1）: 「経路案内」タップ時にAppleマップ/Googleマップを選ばせる
    @State private var showRouteChooser = false
    // 写真・雰囲気セクションの表示チェーン現在地（IG埋め込み失敗→OGP写真カード失敗→地図案内、の順に遷移）
    @State private var photoTier: PhotoTier?
    @State private var instagramEmbedHeight: CGFloat = OGPPhotoCardView.cardHeight
    // お気に入り（端末ローカル）。地図・一覧と同一インスタンスを共有する（UI/UXブラッシュアップ設計書1c/3）。
    @ObservedObject private var favoritesStore: FavoritesStore

    init(cafe: Cafe, dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: CafeDetailViewModel(cafe: cafe, repository: dependencies.repository)
        )
        _photoTier = State(initialValue: Self.initialPhotoTier(for: cafe))
        _favoritesStore = ObservedObject(wrappedValue: dependencies.favoritesStore)
    }

    var body: some View {
        List {
            headerSection

            if viewModel.cafe.dogAmenities != nil {
                amenitiesSection
            }

            if hasConditionInfo {
                conditionSection
            }

            if viewModel.cafe.hours?.hasAnyDay == true || viewModel.cafe.hoursText != nil {
                hoursSection
            }

            photoSection

            if viewModel.cafe.links?.isEmpty == false || viewModel.cafe.operatorNote != nil {
                linksSection
            }

            if viewModel.hasConflict {
                conflictSection
            }

            if !viewModel.sources.isEmpty {
                sourcesSection
            }

            infoSection

            actionSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.cafe.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .safeAreaInset(edge: .bottom) {
            ctaBar
        }
        .sheet(isPresented: $showReport) {
            ReportView(cafe: viewModel.cafe)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
        }
    }

    /// 「来店時の条件・マナー」セクションを出すか（条件文・サイズ制限・運営メモのいずれかがある時, P1-2）
    private var hasConditionInfo: Bool {
        viewModel.cafe.dogPolicyCondition != nil
            || viewModel.cafe.dogSizeLimit != nil
            || viewModel.cafe.dogNote != nil
    }

    /// 犬目線ピン分類（一覧・地図と共通の判定, UI/UXブラッシュアップ設計書1a）
    private var mapPinCategory: MapPinCategory { MapPinCategory.category(for: viewModel.cafe) }

    // MARK: - 可否・鮮度（US2）

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.cafe.name)
                            .font(.title3.bold())
                        if let subArea = viewModel.cafe.subArea {
                            Label(subArea, systemImage: "mappin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    favoriteToggleButton
                    VStack(alignment: .trailing, spacing: 6) {
                        // 犬目線チップを先に見せる（「条件付き」単独より「テラスOK」等が先に見えること, P1-3）
                        MapPinCategoryBadge(category: mapPinCategory)
                        StatusBadge(status: viewModel.cafe.dogPolicyStatus)
                    }
                }

                // 運営確認日チップ（P0-3: footnoteの文字列表示からCapsuleチップへ格上げ）。
                // status==unverified の場合は「運営確認」と矛盾するため出さない
                // （未確認であることは下の warningBox が担う, QA指摘）。
                if let lastVerified = viewModel.cafe.lastVerified,
                   viewModel.cafe.dogPolicyStatus != .unverified {
                    verifiedDateChip(lastVerified)
                }

                // 店舗紹介（002/FR-107）
                if let description = viewModel.cafe.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 条件付きの1行要約（詳細は「来店時の条件・マナー」セクションへ, P1-2）
                if viewModel.cafe.dogPolicyStatus == .conditional,
                   viewModel.cafe.dogPolicyCondition != nil {
                    Label(
                        String(localized: "来店に条件があります（詳細は下記「来店時の条件・マナー」）"),
                        systemImage: "info.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }

                // 未確認情報の明示区別（FR-009/T035）
                if viewModel.isUnverified {
                    warningBox(
                        text: String(localized: "この情報は未確認です。参考記事・確認日のある確定情報ではありません。ご来店前に店舗へ直接ご確認ください。"),
                        systemImage: "questionmark.circle",
                        color: .gray
                    )
                }

                // 古い情報の警告（FR-010/T033）
                if viewModel.isStale && !viewModel.isUnverified {
                    warningBox(
                        text: String(localized: "この情報は最終確認から1年以上経過しています。最新でない可能性があります。"),
                        systemImage: "clock.badge.exclamationmark",
                        color: .orange
                    )
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    /// お気に入りトグル（肉球, P1-1/P2-4）。ON=塗り肉球。
    private var favoriteToggleButton: some View {
        let isFavorite = favoritesStore.contains(viewModel.cafe.id)
        return Button {
            favoritesStore.toggle(viewModel.cafe.id)
        } label: {
            Image(systemName: isFavorite ? "pawprint.fill" : "pawprint")
                .font(.title3)
                .foregroundStyle(isFavorite ? Color.orange : Color.secondary)
        }
        .accessibilityLabel(Text(isFavorite ? "お気に入りから外す" : "お気に入りに追加"))
    }

    /// 運営確認日のCapsuleチップ（P0-3）。未確認/1年超は既存の警告色を反映する。
    private func verifiedDateChip(_ date: Date) -> some View {
        Label {
            Text("運営確認 \(date.formatted(date: .abbreviated, time: .omitted))")
        } icon: {
            Image(systemName: "checkmark.seal.fill")
        }
        .font(.footnote.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(verifiedDateChipColor.opacity(0.15)))
        .foregroundStyle(verifiedDateChipColor)
    }

    private var verifiedDateChipColor: Color {
        if viewModel.isUnverified { return .gray }
        if viewModel.isStale { return .orange }
        return .blue
    }

    // MARK: - 来店時の条件・マナー（P1-2: dogPolicyCondition/dogSizeLimit/dogNoteを集約）

    private var conditionSection: some View {
        Section {
            if let condition = viewModel.cafe.dogPolicyCondition {
                Label(condition, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            // サイズ制限（002/FR-107。例: 小型・中型のみ、抱っこ・カート推奨）
            if let sizeLimit = viewModel.cafe.dogSizeLimit {
                LabeledContent {
                    Text(sizeLimit)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("サイズ")
                }
                .font(.footnote)
            }
            if let note = viewModel.cafe.dogNote {
                Label(note, systemImage: "pawprint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("来店時の条件・マナー")
        }
    }

    // MARK: - CTA固定バー（P0-1: 経路案内・電話, safeAreaInset）

    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Button {
                    showRouteChooser = true
                } label: {
                    Label(String(localized: "経路案内"), systemImage: "arrow.triangle.turn.up.right.diamond")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .confirmationDialog(
                    String(localized: "経路を開くアプリを選択"),
                    isPresented: $showRouteChooser,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "Apple マップ")) {
                        RouteLauncher.open(cafe: viewModel.cafe, using: .apple)
                    }
                    Button(String(localized: "Google マップ")) {
                        RouteLauncher.open(cafe: viewModel.cafe, using: .google)
                    }
                    Button(String(localized: "キャンセル"), role: .cancel) {}
                }

                // 電話がある店のみ併記。無い店は経路案内が全幅になる（P0-1）。
                if let phone = viewModel.cafe.phone,
                   let telURL = URL(string: "tel://" + phone.filter { $0.isNumber || $0 == "+" }) {
                    Button {
                        openURL(telURL)
                    } label: {
                        Label(String(localized: "電話"), systemImage: "phone.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    // MARK: - 写真・雰囲気（写真プレビュー機能: IG投稿埋め込み→OGP写真カード→地図案内の3段フォールバック）

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

    private var photoSection: some View {
        Group {
            if let photoTier {
                Section {
                    photoCard(for: photoTier)
                        .padding(.vertical, 4)
                } header: {
                    Text("写真・雰囲気")
                }
            }
        }
    }

    @ViewBuilder
    private func photoCard(for tier: PhotoTier) -> some View {
        switch tier {
        case .instagramEmbed(let html):
            InstagramPostEmbedView(html: html, height: $instagramEmbedHeight) {
                photoTier = Self.fallbackPhotoTier(for: viewModel.cafe)
            }
            .frame(height: instagramEmbedHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        case .ogpCard(let url, let sourceLabel, let linkType):
            OGPPhotoCardView(url: url, sourceLabel: sourceLabel) {
                // instagram は外部で開く（リンク一覧と同じ原則）。website/tabelog はアプリ内ブラウザのまま。
                if linkType == .instagram {
                    openURL(url)
                } else {
                    safariItem = SafariItem(url: url)
                }
            } onFail: {
                photoTier = Self.mapsOnlyTier(for: viewModel.cafe)
            }
        case .mapsFallback(let url):
            MapsPhotoFallbackCardView {
                safariItem = SafariItem(url: url)
            }
        }
    }

    // MARK: - 犬向け設備（002/FR-101/104, T108）

    private var amenitiesSection: some View {
        Section {
            if let amenities = viewModel.cafe.dogAmenities {
                HStack(spacing: 8) {
                    AmenityBadge(label: String(localized: "店内OK"), value: amenities.indoor)
                    AmenityBadge(label: String(localized: "テラスOK"), value: amenities.terrace)
                    AmenityBadge(label: String(localized: "大型犬OK"), value: amenities.largeDogs)
                    AmenityBadge(label: String(localized: "犬メニュー"), value: amenities.dogMenu)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("わんちゃん向け情報")
        }
    }

    // MARK: - 営業時間（002/FR-102, T109）

    private var hoursSection: some View {
        Section {
            if let hours = viewModel.cafe.hours, hours.hasAnyDay {
                OpenStateBadge(state: OpeningHoursEvaluator.state(hours: hours))
                    .font(.subheadline)
                ForEach(Weekday.allCases, id: \.rawValue) { day in
                    if let ranges = hours.ranges(for: day) {
                        LabeledContent {
                            Text(hoursText(for: ranges))
                                .font(.callout.monospacedDigit())
                        } label: {
                            Text(day.displayName)
                        }
                    }
                }
            }
            if let text = viewModel.cafe.hoursText {
                Text(text)
                    .font(.callout)
            }
            // 定休日メモ（002/FR-107。例: 不定休・展示入替で休館あり）
            if let holidayNote = viewModel.cafe.holidayNote {
                LabeledContent {
                    Text(holidayNote)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("定休日")
                }
                .font(.callout)
            }
        } header: {
            Text("営業時間")
        } footer: {
            if let verified = viewModel.cafe.infoVerified {
                Text("基本情報の確認日: \(verified.formatted(date: .abbreviated, time: .omitted))。最新の営業情報は公式でご確認ください。")
            } else {
                Text("最新の営業情報は公式でご確認ください。")
            }
        }
    }

    private func hoursText(for ranges: [TimeRange]) -> String {
        if ranges.isEmpty { return String(localized: "定休日") }
        return ranges.map { "\($0.open)〜\($0.close)" }.joined(separator: ", ")
    }

    // MARK: - 矛盾提示（US4/FR-011/T046）

    private var conflictSection: some View {
        Section {
            warningBox(
                text: String(localized: "参考記事によって犬同伴可否の情報が食い違っています。各記事の内容と確認日をご確認ください。"),
                systemImage: "exclamationmark.triangle.fill",
                color: .yellow
            )
            ForEach(viewModel.sources) { source in
                SourceRow(
                    source: source,
                    isRepresentative: source.id == viewModel.representativeSource?.id,
                    onOpenURL: { url in safariItem = SafariItem(url: url) }
                )
            }
        } header: {
            Text("参考記事間の食い違い")
        } footer: {
            Text("代表表示は「確認日が新しい参考記事 → 由来の信頼順」で決定しています。確定できない場合は「未確認」になります。")
        }
    }

    // MARK: - 参考記事（US2/FR-008/T032, S1: 出典→参考記事の記事カード化）

    /// OGP代表画像を取得しにいく件数の上限（先頭何件目まで, 設計書S1）。
    /// これ以降はテキストカード（アイコン＋タイトル）のまま、ネットワーク取得を試みない。
    private static let articlePreviewFetchLimit = 5

    private var sourcesSection: some View {
        Section {
            if viewModel.hasConflict {
                // 矛盾セクションで既に全出典を表示済み
                EmptyView()
            } else {
                ForEach(Array(viewModel.sources.enumerated()), id: \.element.id) { index, source in
                    ArticleCardView(
                        source: source,
                        isRepresentative: source.id == viewModel.representativeSource?.id,
                        fetchesPreview: index < Self.articlePreviewFetchLimit,
                        onOpenURL: openSourceURL
                    )
                }
            }
        } header: {
            if !viewModel.hasConflict {
                Text("参考記事")
            }
        } footer: {
            if !viewModel.hasConflict {
                Text("参考記事の代表画像・要約は各記事からの引用であり、詳細は元記事をご確認ください。")
            }
        }
    }

    /// 参考記事リンクの開き方（写真・雰囲気機能のリンク開示ルールを踏襲）:
    /// http(s)はアプリ内ブラウザ、instagram/xは外部アプリ（ユニバーサルリンクでアプリが開く方がUX良）。
    private func openSourceURL(_ url: URL) {
        if let host = url.host?.lowercased(),
           host.contains("instagram.com") || host.contains("x.com") || host.contains("twitter.com") {
            openURL(url)
        } else {
            safariItem = SafariItem(url: url)
        }
    }

    // MARK: - 店舗情報（US5/FR-014/T050）

    private var infoSection: some View {
        Section("店舗情報") {
            if let address = viewModel.cafe.address {
                LabeledContent {
                    Text(address)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("住所")
                }
            }
            // 電話（タップで発信, 002/FR-106）
            if let phone = viewModel.cafe.phone,
               let telURL = URL(string: "tel://" + phone.filter { $0.isNumber || $0 == "+" }) {
                Link(destination: telURL) {
                    LabeledContent {
                        Text(phone)
                            .foregroundStyle(.tint)
                    } label: {
                        Label(String(localized: "電話"), systemImage: "phone")
                            .labelStyle(.titleOnly)
                    }
                }
                .accessibilityLabel(Text("電話をかける: \(phone)"))
            }
            // 予約情報（002/FR-101）
            if let reservation = viewModel.cafe.reservation {
                LabeledContent {
                    Text(reservation)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("予約")
                }
            }
            if let contact = viewModel.cafe.contact {
                if let url = URL(string: contact), url.scheme?.hasPrefix("http") == true {
                    // アプリ内ブラウザで開く（写真・雰囲気機能）
                    Button {
                        safariItem = SafariItem(url: url)
                    } label: {
                        LabeledContent(String(localized: "連絡先・サイト"), value: contact)
                    }
                    .foregroundStyle(.tint)
                } else {
                    LabeledContent(String(localized: "連絡先"), value: contact)
                }
            }
            if case .loading = viewModel.phase {
                HStack {
                    ProgressView()
                    Text("参考記事を読み込み中…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if case .error(let message) = viewModel.phase {
                VStack(alignment: .leading, spacing: 8) {
                    Text("参考記事を取得できませんでした: \(message)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "再試行")) {
                        Task { await viewModel.load() }
                    }
                    .font(.footnote)
                }
            }
        }
    }

    // MARK: - 公式リンク・運営メモ（002/FR-103/106, T110）

    private var linksSection: some View {
        Section {
            if let links = viewModel.cafe.links, !links.isEmpty {
                ForEach(links) { link in
                    if let url = link.resolvedURL {
                        switch link.type {
                        case .website, .tabelog, .other:
                            // アプリ内ブラウザで開く（写真・雰囲気機能: 閉じて即アプリへ復帰できるUX）
                            Button {
                                safariItem = SafariItem(url: url)
                            } label: {
                                Label(link.type.displayName, systemImage: link.type.systemImage)
                            }
                            .foregroundStyle(.tint)
                        default:
                            // instagram/x/google_map は従来通り外部（ユニバーサルリンクでアプリが開く方がUX良）
                            Link(destination: url) {
                                Label(link.type.displayName, systemImage: link.type.systemImage)
                            }
                        }
                    }
                }
            }
            if let note = viewModel.cafe.operatorNote {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                        Text("運営メモ（\(note.sourceDisplayName)より・\(note.verifiedAt.formatted(date: .abbreviated, time: .omitted))確認）")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.teal)
                    Text(note.text)
                        .font(.footnote)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.teal.opacity(0.10)))
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("公式情報・SNS")
        } footer: {
            if viewModel.cafe.operatorNote != nil {
                Text("運営メモは公式SNS等で運営が確認した内容の転記であり、公式の一次情報そのものではありません。")
            }
        }
    }

    // MARK: - アクション（US5/T049, US3/T038。経路案内はCTA固定バーへ移動, P0-1）

    private var actionSection: some View {
        Section {
            Button {
                showReport = true
            } label: {
                Label(String(localized: "情報の誤りを報告"), systemImage: "exclamationmark.bubble")
            }
        } footer: {
            Text("誤り報告は審査（v1: 運営確認）を通過してから反映されます。")
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
        .foregroundStyle(color == .yellow ? Color.primary : color)
        .accessibilityElement(children: .combine)
    }
}

/// 出典1件の行: 種別・主張する可否・確認日・由来（provenance）を提示。
/// AI推測は明示ラベルで確定情報と視覚的に区別する（FR-012/T047）。
struct SourceRow: View {
    let source: Source
    let isRepresentative: Bool
    /// 出典URLのアプリ内ブラウザ起動（写真・雰囲気機能: SafariView sheet を呼び出し側が一元管理する）
    let onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(source.type.displayName)
                    .font(.subheadline.bold())
                if isRepresentative {
                    Text("採用根拠")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                        .foregroundStyle(.blue)
                }
                Spacer()
                StatusBadge(status: source.claimedStatus)
            }
            HStack(spacing: 8) {
                ProvenanceChip(provenance: source.provenance)
                if let verifiedAt = source.verifiedAt {
                    Text("確認日: \(verifiedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let url = source.referenceURL {
                Button {
                    onOpenURL(url)
                } label: {
                    Text(url.absoluteString)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
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
                        StatusBadge(status: source.claimedStatus)
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
