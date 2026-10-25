import SwiftUI

/// 検索画面（再設計 段階1a。旧 AreaPickerView を置き換える全画面）。
/// 入力中: お店（店名の部分一致）と「『入力語』の周りで探す」（場所検索）。
/// 入力前: 現在地の周り・よく探されるエリア・最近の検索。
struct CafeSearchView: View {
    /// 読み込み済みの全店（閉店は検索側で除く）
    let allCafes: [Cafe]
    @ObservedObject var recentSearchStore: RecentSearchStore
    let onSelectOrigin: (SearchOrigin) -> Void
    let onSelectCafe: (Cafe) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var popularAreas: [PopularAreaRanking.Entry] = []
    /// 実行中の場所検索。キャンセルや画面を閉じたときに取り消し、検索地点・最近の検索を変えない。
    @State private var placeSearchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool
    // GeocodingService はキャッシュ等の共有状態を持たないため画面ごとに生成する
    private let geocodingService = GeocodingService()

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cafeMatches: [Cafe] {
        CafeNameSearch.results(query: query, in: allCafes)
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
            popularAreas = PopularAreaRanking.ranked(areas: ManualArea.tokyoPresets, cafes: allCafes)
        }
        .onDisappear { placeSearchTask?.cancel() }
    }

    // MARK: - 検索欄

    private var searchField: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "店名・駅・エリアで検索"), text: $query)
                    .focused($isFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { startPlaceSearch() }
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

            Button(String(localized: "キャンセル")) {
                placeSearchTask?.cancel()
                onCancel()
            }
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

        if !popularAreas.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(popularAreas, id: \.area.id) { entry in
                            Button {
                                select(name: entry.area.name, latitude: entry.area.latitude, longitude: entry.area.longitude)
                            } label: {
                                Text(entry.area.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.primary)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("\(entry.area.name)、\(entry.count)件"))
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } header: {
                Text("よく探されるエリア")
            }
        }

        if !recentSearchStore.entries.isEmpty {
            Section {
                ForEach(recentSearchStore.entries) { entry in
                    Button {
                        select(name: entry.name, latitude: entry.latitude, longitude: entry.longitude)
                    } label: {
                        Label(entry.name, systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(Color.primary)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
            } header: {
                Text("最近の検索")
            }
        }
    }

    // MARK: - 入力中

    @ViewBuilder
    private var typingSections: some View {
        let matches = cafeMatches
        if !matches.isEmpty {
            Section {
                ForEach(matches) { cafe in
                    Button {
                        onSelectCafe(cafe)
                    } label: {
                        CafeSearchRow(cafe: cafe)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("お店")
            }
        }

        Section {
            Button {
                startPlaceSearch()
            } label: {
                Label("「\(trimmedQuery)」の周りで探す", systemImage: "mappin.and.ellipse")
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: 44, alignment: .leading)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("場所")
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

/// 検索候補のお店の行: 名前・エリア（sub_area）・タグ
private struct CafeSearchRow: View {
    let cafe: Cafe

    var body: some View {
        HStack(spacing: 12) {
            CafeThumbnailView(cafe: cafe, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(cafe.name)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                if let subArea = cafe.subArea, !subArea.isEmpty {
                    Text(subArea)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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
        var parts = [cafe.name]
        if let subArea = cafe.subArea, !subArea.isEmpty { parts.append(subArea) }
        parts.append(contentsOf: CafePresentation.tags(for: cafe).map(\.label))
        return parts.joined(separator: "、")
    }
}
