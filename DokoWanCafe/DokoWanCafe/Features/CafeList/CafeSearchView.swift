import CoreLocation
import SwiftUI

/// 検索画面（再設計 段階1a。旧 AreaPickerView を置き換える全画面。さがす体験 第2弾で候補を4つに分けた）。
/// 入力中: 条件（テラスなど）・エリア・お店（店名の部分一致）・ほかの場所（地図で探す）。端末の中だけで計算し、打っている途中は外へ何も送らない。
/// 入力前: 現在地の周り・近くのエリア・最近（場所と見たお店）・行きたい。
struct CafeSearchView: View {
    /// 読み込み済みの全店（閉店は検索側で除く）
    let allCafes: [Cafe]
    @ObservedObject var recentSearchStore: RecentSearchStore
    /// 行きたいの店の id（打つ前の「行きたい」と、候補の並びに使う）
    let wantToGoIDs: Set<UUID>
    /// 今の起点（条件の行のサブ行に「◯◯の周り」と出す）
    let origin: SearchOrigin
    /// 今の起点の座標（距離と近い順に使う。まだ無ければ nil）
    let originCoordinate: CLLocationCoordinate2D?
    /// 営業の判定に使う時刻（今、または「いつ行く？」の対象時刻）
    let referenceTime: Date
    let isTargetTime: Bool
    let onSelectOrigin: (SearchOrigin) -> Void
    /// 条件の提案を押した（フィルタをオンにして画面を閉じる。起点は変えない）
    let onApplyConditions: ([SearchCondition]) -> Void
    let onSelectCafe: (Cafe) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var isSearching = false
    @State private var errorMessage: String?
    /// エリアの索引（`sub_area` とプリセットから。画面を開いたときに一度だけ作る）
    @State private var areaIndex: [SearchArea] = []
    /// 正規化した掲載店の名前（店名そのものを打ったときは条件を出さない）
    @State private var shopNames: Set<String> = []
    /// 実行中の場所検索。キャンセルや画面を閉じたときに取り消し、検索地点・最近の検索を変えない。
    @State private var placeSearchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dogProfile) private var dog
    // GeocodingService はキャッシュ等の共有状態を持たないため画面ごとに生成する
    private let geocodingService = GeocodingService()

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasMyDog: Bool { dog != nil }

    private var areaMatches: [SearchArea] {
        SearchSuggestion.areas(matching: query, in: areaIndex)
    }

    private func rebuildIndex() {
        areaIndex = SearchSuggestion.buildIndex(cafes: allCafes, presets: ManualArea.tokyoPresets)
        // 読みも含める（「◯◯ テラス」のように読みを全部打ったときも、店を探しているとみなして条件を出さない）
        shopNames = Set(allCafes.filter { !$0.isClosed }.flatMap { cafe in
            [cafe.name, cafe.nameReading].compactMap { $0 }.filter { !$0.isEmpty }.map(CafeNameSearch.normalize)
        })
    }

    private var conditionMatches: [SearchCondition] {
        SearchSuggestion.conditions(for: query, hasMyDog: hasMyDog, shopNames: shopNames)
    }

    private var comboMatch: SearchCombo? {
        SearchSuggestion.combo(for: query, areas: areaIndex, hasMyDog: hasMyDog)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            List {
                if trimmedQuery.isEmpty {
                    idleSections
                } else {
                    typingSections
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemBackground))
        .onAppear {
            isFocused = true
            rebuildIndex()
            // 閉店・削除で見えなくなった「見たお店」は、上限の枠をふさがないよう消す。
            // データをまだ読み込めていない（空の）ときは、全部消してしまわないよう何もしない
            if !allCafes.isEmpty {
                recentSearchStore.removeCafes(notIn: Set(allCafes.filter { !$0.isClosed }.map(\.id)))
            }
        }
        // 画面を開いている間に裏でデータが更新されたら、索引も作り直す
        .onChange(of: allCafes) { _, _ in rebuildIndex() }
        .onDisappear { placeSearchTask?.cancel() }
    }

    // MARK: - 検索欄

    private var searchField: some View {
        // 大きな文字では「キャンセル」が縦に折れて読めなくなるため、入力欄の上に右寄せで出す
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            if dynamicTypeSize.isAccessibilitySize { cancelButton }
            fieldBox
            if !dynamicTypeSize.isAccessibilitySize { cancelButton }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var cancelButton: some View {
        Button(String(localized: "キャンセル")) {
            placeSearchTask?.cancel()
            onCancel()
        }
        .lineLimit(1)
        .fixedSize()
        .frame(minHeight: 44)
    }

    private var fieldBox: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(String(localized: "店名・駅・エリア・テラスなど"), text: $query)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { submit() }
                .onChange(of: query) { _, _ in errorMessage = nil }
            if isSearching {
                ProgressView()
            } else if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 44)
                }
                .accessibilityLabel(Text("入力を消す"))
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 入力前

    @ViewBuilder
    private var idleSections: some View {
        Section {
            Button {
                onSelectOrigin(.currentLocation)
            } label: {
                Label(String(localized: "現在地の周りで探す"), systemImage: "location.fill")
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }

        let nearbyAreas = SearchSuggestion.nearbyAreas(in: areaIndex, origin: originCoordinate)
        if !nearbyAreas.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(nearbyAreas) { area in
                            Button {
                                select(area)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(area.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.primary)
                                    Text(verbatim: "\(area.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(Capsule().fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("\(area.name)、掲載\(area.count)店"))
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } header: {
                Text("近くのエリア")
            }
        }

        // 見たお店は、データに残っている営業中の店だけを出す
        let recents = recentSearchStore.entries.filter { entry in
            guard let id = entry.cafeID else { return true }
            return allCafes.contains { $0.id == id && !$0.isClosed }
        }
        if !recents.isEmpty {
            Section {
                ForEach(recents) { entry in
                    recentRow(entry)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                recentSearchStore.remove(entry)
                            } label: {
                                Label(String(localized: "削除"), systemImage: "trash")
                            }
                        }
                }
            } header: {
                recentHeader
            }
        }

        let wantToGo = SearchSuggestion.wantToGoShops(in: allCafes, wantToGoIDs: wantToGoIDs, origin: originCoordinate)
        if !wantToGo.isEmpty {
            Section {
                ForEach(wantToGo) { cafe in
                    shopButton(cafe)
                }
            } header: {
                Text("行きたい")
            }
        }
    }

    /// 「最近」の見出しと、右の「すべて消す」。大きな文字では縦に積む
    private var recentHeader: some View {
        let clearAll = Button(String(localized: "すべて消す")) {
            recentSearchStore.removeAll()
        }
        .font(.subheadline)
        .textCase(nil)
        .frame(minHeight: 44)
        return ViewThatFits(in: .horizontal) {
            HStack {
                Text("最近")
                Spacer(minLength: 8)
                clearAll.lineLimit(1).fixedSize()
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("最近")
                clearAll
            }
        }
    }

    @ViewBuilder
    private func recentRow(_ entry: RecentSearch) -> some View {
        if let id = entry.cafeID, let cafe = allCafes.first(where: { $0.id == id }) {
            // 見たお店: 名前・「見たお店 · エリア」・タグ
            let parts = [String(localized: "見たお店")] + [areaName(of: cafe)].compactMap { $0 }
            Button {
                openCafe(cafe)
            } label: {
                CafeSearchRow(cafe: cafe, subtitle: parts.joined(separator: " · "), spokenParts: parts)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                select(name: entry.name, latitude: entry.latitude, longitude: entry.longitude)
            } label: {
                Label(entry.name, systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(Color.primary)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
    }

    private func areaName(of cafe: Cafe) -> String? {
        guard let name = cafe.subArea?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        return name
    }

    // MARK: - 入力中

    @ViewBuilder
    private var typingSections: some View {
        let combo = comboMatch
        let conditions = conditionMatches
        let areas = areaMatches
        let shops = SearchSuggestion.shops(
            matching: query, in: allCafes, wantToGoIDs: wantToGoIDs, origin: originCoordinate
        )

        // (a) 条件
        if combo != nil || !conditions.isEmpty {
            Section {
                if let combo {
                    SuggestionRow(
                        systemImage: "line.3.horizontal.decrease.circle.fill",
                        title: combo.title(isTargetTime: isTargetTime),
                        subtitle: String(localized: "起点を\(combo.area.name)に変えて、地図の条件チップもオンにします"),
                        spokenText: String(localized: "\(combo.title(isTargetTime: isTargetTime))。起点を変えて、地図のチップをオンにします")
                    ) {
                        selectCombo(combo)
                    }
                }
                ForEach(conditions, id: \.self) { condition in
                    SuggestionRow(
                        systemImage: "line.3.horizontal.decrease.circle",
                        title: condition.title(isTargetTime: isTargetTime),
                        subtitle: condition.subtitle(originName: origin.displayName, isTargetTime: isTargetTime),
                        spokenText: condition.spokenText(isTargetTime: isTargetTime)
                    ) {
                        onApplyConditions([condition])
                    }
                }
            } header: {
                Text("条件")
            }
        }

        // (b) エリア
        if !areas.isEmpty {
            Section {
                ForEach(areas) { area in
                    SuggestionRow(
                        systemImage: "mappin.circle",
                        title: String(localized: "\(area.name)の周り"),
                        subtitle: String(localized: "掲載 \(area.count)店"),
                        spokenText: String(localized: "\(area.name)の周り、掲載\(area.count)店")
                    ) {
                        select(area)
                    }
                }
            } header: {
                Text("エリア")
            }
        }

        // (c) お店
        if !shops.isEmpty {
            Section {
                ForEach(shops) { cafe in
                    shopButton(cafe)
                }
            } header: {
                Text("お店")
            }
        }

        // 見つからないとき: どれにも当たらなければ、先頭に案内を出す（押せない行。下の「ほかの場所」へ進める）
        if SearchSuggestion.hasNoMatch(query: query, hasCombo: combo != nil, conditions: conditions, areas: areas, shops: shops) {
            Section {
                NoShopNoticeRow(query: trimmedQuery)
            }
        }

        // (d) ほかの場所
        Section {
            SuggestionRow(
                systemImage: "magnifyingglass",
                title: String(localized: "地図で「\(trimmedQuery)」を探す"),
                subtitle: String(localized: "駅名・住所を Apple のマップで探します"),
                spokenText: String(localized: "地図で「\(trimmedQuery)」を探す。駅名・住所を Apple のマップで探します")
            ) {
                startPlaceSearch()
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("ほかの場所")
        }
    }

    /// 候補・行きたいのお店の行。押すと検索画面を閉じて地図の上のカードを開く
    private func shopButton(_ cafe: Cafe) -> some View {
        let subtitle = SearchShopSubtitle.make(
            cafe: cafe, origin: originCoordinate, at: referenceTime, isTargetTime: isTargetTime
        )
        return Button {
            openCafe(cafe)
        } label: {
            CafeSearchRow(cafe: cafe, subtitle: subtitle.text, spokenParts: subtitle.spokenParts)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 選ぶ

    /// 検索画面からお店を開く。最近に「見たお店」として残してから、カード（または詳細）を開く
    private func openCafe(_ cafe: Cafe) {
        recentSearchStore.addViewedCafe(cafe)
        onSelectCafe(cafe)
    }

    private func select(_ area: SearchArea) {
        select(name: area.name, latitude: area.latitude, longitude: area.longitude)
    }

    /// 組み合わせ: 起点をそのエリアに変え（最近の検索に残す）、フィルタもオンにする
    private func selectCombo(_ combo: SearchCombo) {
        onApplyConditions(combo.conditions)
        select(combo.area)
    }

    /// キーボードの「検索」: 組み合わせ → エリアの候補の先頭 → 条件だけが当たるなら条件をオン → 無ければ地図で探す
    /// （「テラス」で検索を押して、どこかの「〇〇テラス」へ起点が飛ばないように）
    private func submit() {
        if let combo = comboMatch {
            selectCombo(combo)
        } else if let area = areaMatches.first {
            select(area)
        } else if !conditionMatches.isEmpty {
            onApplyConditions(conditionMatches)
        } else {
            startPlaceSearch()
        }
    }

    // MARK: - 場所の検索

    private func select(name: String, latitude: Double, longitude: Double) {
        recentSearchStore.add(name: name, latitude: latitude, longitude: longitude)
        onSelectOrigin(.searched(name: name, latitude: latitude, longitude: longitude))
    }

    private func startPlaceSearch() {
        guard !isSearching else { return }
        placeSearchTask = Task { await searchPlace() }
    }

    /// 入力語を `GeocodingService` で場所として引き、成功したら検索地点をそこへ変えて地図に戻る。
    /// Appleへ送信されるのは入力した検索クエリの文字列のみで、GPS現在地は送らない（憲章 原則III）。
    private func searchPlace() async {
        guard !isSearching, let normalized = GeocodingService.PureLogic.normalizedQuery(query) else { return }
        errorMessage = nil
        isSearching = true
        defer { isSearching = false }

        let found = await geocodingService.search(normalized)
        // 検索の途中でキャンセルされたら、検索地点も最近の検索も変えず、何も出さない
        guard !Task.isCancelled else { return }
        guard let result = found else {
            errorMessage = String(localized: "場所が見つかりませんでした。駅名や地名で試してください")
            return
        }
        select(name: result.name, latitude: result.coordinate.latitude, longitude: result.coordinate.longitude)
    }
}

/// 検索候補のお店の行: 名前・2行目（エリア · 距離 · 営業など）・タグ・写真（キャッシュのみ）
private struct CafeSearchRow: View {
    let cafe: Cafe
    /// 2行目の文字（無ければ出さない）
    let subtitle: String?
    /// VoiceOver で店名に続けて読む部分（エリア・距離・営業など）
    let spokenParts: [String]
    @Environment(\.dogProfile) private var dog

    var body: some View {
        HStack(spacing: 12) {
            CafeThumbnailView(cafe: cafe, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(cafe.name)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                CafeTagsView(cafe: cafe)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        var parts = [cafe.name] + spokenParts
        parts.append(contentsOf: CafePresentation.tags(for: cafe, dog: dog).map(\.label))
        return parts.joined(separator: "、")
    }
}

/// 入力がお店・エリア・条件のどれにも当たらないときの案内（押せない行）。大きな文字では折り返して全文を出す。
private struct NoShopNoticeRow: View {
    let query: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("「\(query)」という名前の掲載店はありません")
                    .font(.subheadline.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("駅名やエリア名でも探せます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 条件・エリア・ほかの場所の提案の行: アイコン・タイトル・サブ行。大きな文字では折り返して全文を出す。
private struct SuggestionRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let spokenText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(Color.brand)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenText))
        .accessibilityAddTraits(.isButton)
    }
}
