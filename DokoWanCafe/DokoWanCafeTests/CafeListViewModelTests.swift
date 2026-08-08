import XCTest
@testable import DokoWanCafe

/// CafeListViewModel のユニットテスト。
/// データ層（StaticCafeRepository）は全カフェをローカル保持しており取得コストが実質ゼロのため、
/// CafeListViewModel は「半径3km/10km」のような人為的な足切りをせず、実質無制限の安全半径
/// （fetchSafetyRadiusMeters）でリポジトリへ問い合わせる（地図UX設計・spec.md SC-005 参照）。
@MainActor
final class CafeListViewModelTests: XCTestCase {
    /// 距離に応じて実際にフィルタする、実リポジトリ同等の振る舞いのモック
    /// （渡された radiusMeters を正しく尊重することで、呼び出し側の半径指定を検証できる）。
    private struct DistanceFilteringMockRepository: CafeRepository {
        let cafes: [Cafe]

        func nearbyCafes(
            latitude: Double, longitude: Double, radiusMeters: Int, onlyDogOK: Bool
        ) async throws -> [CafeWithDistance] {
            var results: [CafeWithDistance] = []
            for cafe in cafes where !cafe.isClosed {
                if onlyDogOK && cafe.dogPolicyStatus != .allowed && cafe.dogPolicyStatus != .conditional {
                    continue
                }
                let distance = DistanceCalculator.distanceMeters(
                    fromLatitude: latitude, fromLongitude: longitude,
                    toLatitude: cafe.latitude, toLongitude: cafe.longitude
                )
                if distance <= Double(radiusMeters) {
                    results.append(CafeWithDistance(cafe: cafe, distanceMeters: distance))
                }
            }
            results.sort { $0.distanceMeters < $1.distanceMeters }
            return results
        }

        func cafeDetail(id: UUID) async throws -> CafeDetail {
            guard let cafe = cafes.first(where: { $0.id == id }) else { throw SupabaseError.emptyResponse }
            return CafeDetail(cafe: cafe, sources: [])
        }

        func allCafes() async throws -> [Cafe] {
            cafes.filter { !$0.isClosed }
        }
    }

    private func makeCafe(
        name: String,
        latitude: Double,
        longitude: Double,
        dogPolicyStatus: DogPolicyStatus = .allowed,
        dogAmenities: DogAmenities? = nil,
        lastVerified: Date? = nil
    ) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: name,
            latitude: latitude, longitude: longitude,
            address: nil, contact: nil,
            dogPolicyStatus: dogPolicyStatus, dogPolicyCondition: nil,
            lastVerified: lastVerified, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo",
            dogAmenities: dogAmenities
        )
    }

    /// テストごとに専用の UserDefaults suite を注入し、他テスト・実データと隔離する（FavoritesStoreTests と同様の方針）。
    private func makeFavoritesStore() -> FavoritesStore {
        let suiteName = "CafeListViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return FavoritesStore(defaults: defaults)
    }

    private func makeViewModel(cafes: [Cafe], favoritesStore: FavoritesStore? = nil) -> CafeListViewModel {
        CafeListViewModel(
            repository: DistanceFilteringMockRepository(cafes: cafes),
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            favoritesStore: favoritesStore ?? makeFavoritesStore()
        )
    }

    func test_旧半径10kmを超える遠方カフェも取得される() async {
        // 新宿(基準点)から東西南北のどちら向きでも旧上限10kmを超える、約14.5km西の地点に1件配置
        let origin = ManualArea(id: "test-shinjuku", name: "テスト:新宿", latitude: 35.6896, longitude: 139.7006)
        let nearCafe = makeCafe(name: "近くのカフェ", latitude: 35.6900, longitude: 139.7010)
        let farCafe = makeCafe(name: "遠方カフェ(約14.5km)", latitude: 35.6528, longitude: 139.5470)

        let viewModel = makeViewModel(cafes: [nearCafe, farCafe])
        viewModel.origin = .manual(origin)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.phase, .loaded)
        let names = Set(viewModel.allResults.map(\.cafe.name))
        XCTAssertTrue(
            names.contains("遠方カフェ(約14.5km)"),
            "旧半径(既定3km/拡大10km)なら除外されていたはずの遠方カフェが、安全半径の拡大により含まれる"
        )
        XCTAssertTrue(names.contains("近くのカフェ"))
    }

    func test_displayedResultsは距離昇順() async {
        let origin = ManualArea(id: "test-shinjuku", name: "テスト:新宿", latitude: 35.6896, longitude: 139.7006)
        let far = makeCafe(name: "遠い", latitude: 35.70, longitude: 139.80)
        let near = makeCafe(name: "近い", latitude: 35.6897, longitude: 139.7007)

        let viewModel = makeViewModel(cafes: [far, near])
        viewModel.origin = .manual(origin)
        await viewModel.refresh()

        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["近い", "遠い"])
    }

    // MARK: - amenityFilter / includeUnverified / favoritesOnly / sortOrder（UI/UXブラッシュアップ設計書4）

    private func makeOrigin() -> ManualArea {
        ManualArea(id: "test-shinjuku", name: "テスト:新宿", latitude: 35.6896, longitude: 139.7006)
    }

    func test_未確認は既定でdisplayedResultsに出ないがincludeUnverifiedをtrueにすると出る() async {
        let unverified = makeCafe(
            name: "未確認カフェ", latitude: 35.6897, longitude: 139.7007,
            dogPolicyStatus: .unverified
        )
        let viewModel = makeViewModel(cafes: [unverified])
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertTrue(viewModel.displayedResults.isEmpty, "未確認は既定で非表示（原則I: 未確認を可と主張しない）")

        viewModel.includeUnverified = true
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["未確認カフェ"])
    }

    func test_amenityFilterで店内OKの店だけに絞り込める() async {
        let indoorCafe = makeCafe(
            name: "店内OKカフェ", latitude: 35.6897, longitude: 139.7007,
            dogAmenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil)
        )
        let terraceOnlyCafe = makeCafe(
            name: "テラスのみカフェ", latitude: 35.6898, longitude: 139.7008,
            dogAmenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil)
        )
        let viewModel = makeViewModel(cafes: [indoorCafe, terraceOnlyCafe])
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertEqual(viewModel.displayedResults.count, 2)

        viewModel.amenityFilter.indoorOnly = true
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["店内OKカフェ"])
    }

    func test_favoritesOnlyでお気に入りの店だけに絞り込める() async {
        let favoriteCafe = makeCafe(name: "お気に入りカフェ", latitude: 35.6897, longitude: 139.7007)
        let otherCafe = makeCafe(name: "他のカフェ", latitude: 35.6898, longitude: 139.7008)
        let favoritesStore = makeFavoritesStore()
        favoritesStore.toggle(favoriteCafe.id)

        let viewModel = makeViewModel(cafes: [favoriteCafe, otherCafe], favoritesStore: favoritesStore)
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertEqual(viewModel.displayedResults.count, 2)

        viewModel.favoritesOnly = true
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["お気に入りカフェ"])
    }

    func test_favoriteCafesは対象エリア外を検索中でも保存済みお気に入りを返す() async {
        // お気に入り画面は現在の検索エリアに依存しない（QA #1 の回帰防止）。
        let favoriteCafe = makeCafe(name: "保存済みカフェ", latitude: 35.6897, longitude: 139.7007)
        let otherCafe = makeCafe(name: "非お気に入り", latitude: 35.6898, longitude: 139.7008)
        let favoritesStore = makeFavoritesStore()
        favoritesStore.toggle(favoriteCafe.id)

        let viewModel = makeViewModel(cafes: [favoriteCafe, otherCafe], favoritesStore: favoritesStore)
        // 対象エリア外（大阪付近）を手動検索 → allResults は空・phase は outOfArea になる
        viewModel.origin = .manual(ManualArea(id: "osaka", name: "大阪", latitude: 34.7, longitude: 135.5))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.phase, .outOfArea)
        XCTAssertTrue(viewModel.allResults.isEmpty)
        // それでもお気に入りは全ロード済みカフェから解決され、保存済みの店が出る
        XCTAssertEqual(viewModel.favoriteCafes.map(\.cafe.name), ["保存済みカフェ"])
    }

    func test_sortOrderをrecentlyVerifiedにすると確認日が新しい順になる() async {
        let newer = Date(timeIntervalSince1970: 1_700_000_000)
        let older = Date(timeIntervalSince1970: 1_600_000_000)
        let newCafe = makeCafe(name: "新しい確認", latitude: 35.70, longitude: 139.80, lastVerified: newer)
        let oldCafe = makeCafe(name: "古い確認", latitude: 35.6897, longitude: 139.7007, lastVerified: older)

        let viewModel = makeViewModel(cafes: [newCafe, oldCafe])
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        // 既定（距離順）では近い「古い確認」が先
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["古い確認", "新しい確認"])

        viewModel.sortOrder = .recentlyVerified
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["新しい確認", "古い確認"])
    }

    func test_resetFiltersでamenityFilterとincludeUnverifiedとfavoritesOnlyが初期化される() {
        let viewModel = makeViewModel(cafes: [])
        viewModel.amenityFilter = AmenityFilter(indoorOnly: true, terraceOnly: true, dogMenuOnly: true)
        viewModel.includeUnverified = true
        viewModel.favoritesOnly = true

        viewModel.resetFilters()

        XCTAssertEqual(viewModel.amenityFilter, AmenityFilter())
        XCTAssertFalse(viewModel.includeUnverified)
        XCTAssertFalse(viewModel.favoritesOnly)
    }

    func test_activeFilterCountは適用中のトグル数() {
        let viewModel = makeViewModel(cafes: [])
        XCTAssertEqual(viewModel.activeFilterCount, 0)

        viewModel.amenityFilter.indoorOnly = true
        viewModel.includeUnverified = true
        XCTAssertEqual(viewModel.activeFilterCount, 2)

        viewModel.favoritesOnly = true
        XCTAssertEqual(viewModel.activeFilterCount, 3)
    }

    // MARK: - favoriteCafes（お気に入り専用画面, S4設計書）

    func test_favoriteCafesは犬向け条件や未確認フィルタを無視して距離順に返す() async {
        let favoriteUnverified = makeCafe(
            name: "未確認だがお気に入り", latitude: 35.70, longitude: 139.80,
            dogPolicyStatus: .unverified
        )
        let favoriteNear = makeCafe(name: "近いお気に入り", latitude: 35.6897, longitude: 139.7007)
        let notFavorite = makeCafe(name: "お気に入りでない", latitude: 35.6898, longitude: 139.7008)
        let favoritesStore = makeFavoritesStore()
        favoritesStore.toggle(favoriteUnverified.id)
        favoritesStore.toggle(favoriteNear.id)

        let viewModel = makeViewModel(
            cafes: [favoriteUnverified, favoriteNear, notFavorite],
            favoritesStore: favoritesStore
        )
        viewModel.origin = .manual(makeOrigin())
        // displayedResults向けの絞り込みを掛けても favoriteCafes には影響しないことを確認（設計書S4: フィルタ無視）
        viewModel.amenityFilter.indoorOnly = true
        await viewModel.refresh()

        XCTAssertTrue(
            viewModel.displayedResults.isEmpty,
            "前提: amenityFilter.indoorOnlyによりdisplayedResultsは0件（いずれもindoor情報なし・未確認）"
        )
        XCTAssertEqual(
            viewModel.favoriteCafes.map(\.cafe.name),
            ["近いお気に入り", "未確認だがお気に入り"],
            "距離昇順・amenity/未確認フィルタを無視して両方のお気に入りが含まれる"
        )
    }

    func test_favoriteCafesはお気に入りが空なら空配列() async {
        let cafe = makeCafe(name: "カフェ", latitude: 35.6897, longitude: 139.7007)
        let viewModel = makeViewModel(cafes: [cafe])
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertTrue(viewModel.favoriteCafes.isEmpty)
    }

    func test_フィルタ起因の0件はisEmptyDueToFilterがtrueになる() async {
        let cafe = makeCafe(name: "犬OKカフェ", latitude: 35.6897, longitude: 139.7007)
        let viewModel = makeViewModel(cafes: [cafe])
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertFalse(viewModel.isEmptyDueToFilter)

        // 唯一のカフェが店内OKを持たないため、店内OKで絞り込むと0件になる
        viewModel.amenityFilter.indoorOnly = true
        XCTAssertTrue(viewModel.displayedResults.isEmpty)
        XCTAssertTrue(viewModel.isEmptyDueToFilter, "取得自体は成功しているため phase は .loaded のまま、フィルタ起因の0件と判定される")
    }
}
