import Combine
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

    /// テストごとに専用の UserDefaults suite を注入し、他テスト・実データと隔離する（SavedPlacesStoreTests と同様の方針）。
    private func makeSavedStore(now: @escaping () -> Date = { Date() }) -> SavedPlacesStore {
        let suiteName = "CafeListViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return SavedPlacesStore(defaults: defaults, now: now)
    }

    private func makeViewModel(cafes: [Cafe], savedStore: SavedPlacesStore? = nil) -> CafeListViewModel {
        CafeListViewModel(
            repository: DistanceFilteringMockRepository(cafes: cafes),
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: savedStore ?? makeSavedStore()
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

    // MARK: - amenityFilter / includeUnverified / openNowOnly / sortOrder（UI/UXブラッシュアップ設計書4）

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

    func test_wantToGoCafesは対象エリア外を検索中でも保存済みお気に入りを返す() async {
        // お気に入り画面は現在の検索エリアに依存しない（QA #1 の回帰防止）。
        let favoriteCafe = makeCafe(name: "保存済みカフェ", latitude: 35.6897, longitude: 139.7007)
        let otherCafe = makeCafe(name: "非お気に入り", latitude: 35.6898, longitude: 139.7008)
        let savedStore = makeSavedStore()
        savedStore.toggleWantToGo(favoriteCafe.id)

        let viewModel = makeViewModel(cafes: [favoriteCafe, otherCafe], savedStore: savedStore)
        // 対象エリア外（大阪付近）を手動検索 → allResults は空・phase は outOfArea になる
        viewModel.origin = .manual(ManualArea(id: "osaka", name: "大阪", latitude: 34.7, longitude: 135.5))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.phase, .outOfArea)
        XCTAssertTrue(viewModel.allResults.isEmpty)
        // それでもお気に入りは全ロード済みカフェから解決され、保存済みの店が出る
        XCTAssertEqual(viewModel.wantToGoCafes.map(\.cafe.name), ["保存済みカフェ"])
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

    func test_resetFiltersでamenityFilterとincludeUnverifiedとopenNowOnlyが初期化される() {
        let viewModel = makeViewModel(cafes: [])
        viewModel.amenityFilter = AmenityFilter(indoorOnly: true, terraceOnly: true, dogMenuOnly: true)
        viewModel.includeUnverified = true
        viewModel.openNowOnly = true

        viewModel.resetFilters()

        XCTAssertEqual(viewModel.amenityFilter, AmenityFilter())
        XCTAssertFalse(viewModel.includeUnverified)
        XCTAssertFalse(viewModel.openNowOnly)
    }

    func test_activeFilterCountは適用中のトグル数() {
        let viewModel = makeViewModel(cafes: [])
        XCTAssertEqual(viewModel.activeFilterCount, 0)

        viewModel.amenityFilter.indoorOnly = true
        viewModel.includeUnverified = true
        XCTAssertEqual(viewModel.activeFilterCount, 2)

        viewModel.openNowOnly = true
        XCTAssertEqual(viewModel.activeFilterCount, 3)
    }

    func test_hasActiveChipsは営業中か犬向け条件がオンのときだけtrue() {
        let viewModel = makeViewModel(cafes: [])
        XCTAssertFalse(viewModel.hasActiveChips)

        // 未確認の表示はチップではないので「クリア」チップの対象外
        viewModel.includeUnverified = true
        XCTAssertFalse(viewModel.hasActiveChips)

        viewModel.openNowOnly = true
        XCTAssertTrue(viewModel.hasActiveChips)

        viewModel.openNowOnly = false
        viewModel.amenityFilter.dogMenuOnly = true
        XCTAssertTrue(viewModel.hasActiveChips)
    }

    // MARK: - 営業中チップ・未確認の行（再設計 段階1a）

    private func hours(mon: [TimeRange]) -> OpeningHours {
        OpeningHours(mon: mon, tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
    }

    /// 2026-07-06（月曜）の東京時間
    private func mondayTokyo(hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: hour))!
    }

    func test_営業中チップは注入した時刻で営業中の店だけを通し時間が不明の店は通さない() async {
        var open = makeCafe(name: "昼の店", latitude: 35.6897, longitude: 139.7007)
        open.hours = hours(mon: [TimeRange(open: "09:00", close: "18:00")])
        var evening = makeCafe(name: "夜の店", latitude: 35.6898, longitude: 139.7008)
        evening.hours = hours(mon: [TimeRange(open: "19:00", close: "23:00")])
        let unknown = makeCafe(name: "時間不明の店", latitude: 35.6899, longitude: 139.7009)

        var currentTime = mondayTokyo(hour: 12)
        let viewModel = CafeListViewModel(
            repository: DistanceFilteringMockRepository(cafes: [open, evening, unknown]),
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: makeSavedStore(),
            now: { currentTime }
        )
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertEqual(viewModel.displayedResults.count, 3)

        viewModel.openNowOnly = true
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["昼の店"])
        XCTAssertEqual(viewModel.clock, mondayTokyo(hour: 12), "表示（行・ピン・カード）も絞り込みと同じ時刻を使う")

        // 時間が進んだら tick() で絞り込みと表示の時刻が一緒に更新される
        currentTime = mondayTokyo(hour: 20)
        viewModel.tick()
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["夜の店"])
        XCTAssertEqual(viewModel.clock, mondayTokyo(hour: 20))
    }

    // MARK: - いつ行く？（再設計 段階2: 対象時刻）

    /// 2026-07-06（月曜）12:00 を「今」として、昼の店・夜の店・時間不明の店を読み込んだ VM
    private func makeTargetTimeViewModel(
        extra: [Cafe] = [], currentTime: Date? = nil
    ) async -> CafeListViewModel {
        var day = makeCafe(name: "昼の店", latitude: 35.6897, longitude: 139.7007)
        day.hours = hours(mon: [TimeRange(open: "09:00", close: "18:00")])
        var evening = makeCafe(name: "夜の店", latitude: 35.6898, longitude: 139.7008)
        evening.hours = hours(mon: [TimeRange(open: "19:00", close: "23:00")])
        let unknown = makeCafe(name: "時間不明の店", latitude: 35.6899, longitude: 139.7009)
        let time = currentTime ?? mondayTokyo(hour: 12)
        let viewModel = CafeListViewModel(
            repository: DistanceFilteringMockRepository(cafes: [day, evening, unknown] + extra),
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: makeSavedStore(),
            now: { time }
        )
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()
        return viewModel
    }

    func test_対象時刻を決めるとその時刻に営業中の店だけを通し表示の時刻も対象時刻になる() async {
        let viewModel = await makeTargetTimeViewModel()
        XCTAssertFalse(viewModel.isTargetTime)
        XCTAssertEqual(viewModel.referenceTime, mondayTokyo(hour: 12), "対象時刻がなければ今")

        viewModel.applyTargetTime(mondayTokyo(hour: 20))

        XCTAssertTrue(viewModel.isTargetTime)
        XCTAssertTrue(viewModel.openNowOnly, "決めたら「その時間に営業」もオンになる")
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["夜の店"])
        XCTAssertEqual(viewModel.referenceTime, mondayTokyo(hour: 20))
        XCTAssertEqual(viewModel.clock, mondayTokyo(hour: 12), "今の時計は変えない")
        XCTAssertTrue(viewModel.hasActiveChips)
    }

    func test_対象時刻の件数は今の他の条件を含めて数える() async {
        var indoorEvening = makeCafe(
            name: "店内OKの夜の店", latitude: 35.6900, longitude: 139.7010,
            dogAmenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil)
        )
        indoorEvening.hours = hours(mon: [TimeRange(open: "19:00", close: "23:00")])
        let viewModel = await makeTargetTimeViewModel(extra: [indoorEvening])
        let evening = mondayTokyo(hour: 20)

        XCTAssertEqual(viewModel.openCount(at: evening), 2, "夜の店と店内OKの夜の店")
        XCTAssertEqual(viewModel.openCount(at: nil), 1, "nil は今（昼の店）")

        viewModel.amenityFilter.indoorOnly = true
        XCTAssertEqual(viewModel.openCount(at: evening), 1, "店内OKの条件を含めて数える")
        XCTAssertEqual(viewModel.openCount(at: mondayTokyo(hour: 3)), 0)
    }

    func test_日跨ぎの深夜帯は前日の枠が対象時刻まで続いていれば通す() async {
        var late = makeCafe(name: "深夜の店", latitude: 35.6900, longitude: 139.7010)
        late.hours = OpeningHours(
            mon: [TimeRange(open: "17:00", close: "02:00")],
            tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil
        )
        let viewModel = await makeTargetTimeViewModel(extra: [late])

        let tuesday1am = mondayTokyo(hour: 25)
        XCTAssertEqual(viewModel.openCount(at: tuesday1am), 1, "月曜17:00-02:00の店は火曜1:00も営業中")
        XCTAssertEqual(viewModel.openCount(at: mondayTokyo(hour: 27)), 0, "火曜3:00は閉まっている")
    }

    func test_clearTargetTimeは対象時刻とセットの営業中もオフに戻す() async {
        let viewModel = await makeTargetTimeViewModel()
        viewModel.applyTargetTime(mondayTokyo(hour: 20))

        viewModel.clearTargetTime()

        XCTAssertFalse(viewModel.isTargetTime)
        XCTAssertFalse(viewModel.openNowOnly)
        XCTAssertEqual(viewModel.displayedResults.count, 3)
    }

    func test_いつ行く？のリセットは適用前から利用者がオンにしていた営業中を消さない() async {
        let viewModel = await makeTargetTimeViewModel()
        viewModel.openNowOnly = true

        viewModel.applyTargetTime(mondayTokyo(hour: 20))
        viewModel.clearTargetTime()

        XCTAssertFalse(viewModel.isTargetTime)
        XCTAssertTrue(viewModel.openNowOnly, "適用の前に利用者が自分でオンにしていた営業中は残す")
    }

    func test_今のまま適用した営業中もリセットで戻せる() async {
        let viewModel = await makeTargetTimeViewModel()
        XCTAssertFalse(viewModel.openNowOnly)

        viewModel.applyTargetTime(nil)
        XCTAssertTrue(viewModel.openNowOnly)
        XCTAssertFalse(viewModel.isTargetTime)

        viewModel.clearTargetTime()
        XCTAssertFalse(viewModel.openNowOnly, "対象時刻が今のままでも、適用でオンにした営業中は戻る")
        XCTAssertEqual(viewModel.displayedResults.count, 3)
    }

    func test_適用後に利用者が営業中を切り替えたらリセットでは触らない() async {
        let viewModel = await makeTargetTimeViewModel()
        viewModel.applyTargetTime(mondayTokyo(hour: 20))
        viewModel.openNowOnly = false  // 利用者がチップを自分でオフにした

        viewModel.clearTargetTime()
        XCTAssertFalse(viewModel.openNowOnly)

        viewModel.applyTargetTime(mondayTokyo(hour: 20))
        viewModel.openNowOnly = false
        viewModel.openNowOnly = true  // 自分でオフ→オンにした
        viewModel.clearTargetTime()
        XCTAssertTrue(viewModel.openNowOnly, "自分で切り替えた営業中はリセットで消さない")
    }

    func test_applyTargetTimeにnilを渡すと今に開いている店だけを表示する() async {
        let viewModel = await makeTargetTimeViewModel()
        viewModel.applyTargetTime(mondayTokyo(hour: 20))

        viewModel.applyTargetTime(nil)

        XCTAssertFalse(viewModel.isTargetTime)
        XCTAssertTrue(viewModel.openNowOnly)
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["昼の店"])
    }

    func test_resetFiltersは対象時刻も今に戻す() async {
        let viewModel = await makeTargetTimeViewModel()
        viewModel.applyTargetTime(mondayTokyo(hour: 20))

        viewModel.resetFilters()

        XCTAssertFalse(viewModel.isTargetTime)
        XCTAssertFalse(viewModel.openNowOnly)
        XCTAssertFalse(viewModel.hasActiveChips)
    }

    func test_displayedResultsは入力が変わったときだけ計算し直す() async {
        let cafe = makeCafe(name: "店", latitude: 35.6897, longitude: 139.7007)
        let viewModel = makeViewModel(cafes: [cafe])
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        let revision = viewModel.displayRevision
        // 読むだけでは計算し直さない（描画ごとに何度も呼ばれても同じ）
        _ = viewModel.displayedResults
        _ = viewModel.displayedResults
        _ = viewModel.unverifiedCandidateCount
        XCTAssertEqual(viewModel.displayRevision, revision)

        viewModel.openNowOnly = true
        XCTAssertEqual(viewModel.displayRevision, revision + 1)
        viewModel.sortOrder = .recentlyVerified
        XCTAssertEqual(viewModel.displayRevision, revision + 2)
    }

    func test_未確認の件数は今の条件で未確認だけを足したときの数() async {
        let verified = makeCafe(
            name: "確認済み", latitude: 35.6897, longitude: 139.7007,
            dogAmenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil)
        )
        let unverifiedIndoor = makeCafe(
            name: "未確認・店内OK", latitude: 35.6898, longitude: 139.7008, dogPolicyStatus: .unverified,
            dogAmenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil)
        )
        let unverifiedOther = makeCafe(
            name: "未確認・不明", latitude: 35.6899, longitude: 139.7009, dogPolicyStatus: .unverified
        )
        let viewModel = makeViewModel(cafes: [verified, unverifiedIndoor, unverifiedOther])
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertEqual(viewModel.unverifiedCandidateCount, 2)

        viewModel.amenityFilter.indoorOnly = true
        XCTAssertEqual(viewModel.unverifiedCandidateCount, 1, "条件に合う未確認だけを数える")

        // オンのときも同じ数（「未確認の店を隠す」の行を出す判断に使う）
        viewModel.includeUnverified = true
        XCTAssertEqual(viewModel.unverifiedCandidateCount, 1)
        XCTAssertEqual(viewModel.displayedResults.count, 2)
    }

    // MARK: - wantToGoCafes / visitedCafes（保存タブ, S4設計書・再設計 段階2）

    func test_wantToGoCafesは犬向け条件や未確認フィルタを無視して追加が新しい順に返す() async {
        let favoriteUnverified = makeCafe(
            name: "未確認だが行きたい", latitude: 35.70, longitude: 139.80,
            dogPolicyStatus: .unverified
        )
        let favoriteNear = makeCafe(name: "近い行きたい", latitude: 35.6897, longitude: 139.7007)
        let notFavorite = makeCafe(name: "行きたいでない", latitude: 35.6898, longitude: 139.7008)
        var storeTime = mondayTokyo(hour: 9)
        let savedStore = makeSavedStore(now: { storeTime })
        savedStore.toggleWantToGo(favoriteNear.id)
        storeTime = mondayTokyo(hour: 10)
        savedStore.toggleWantToGo(favoriteUnverified.id)

        let viewModel = makeViewModel(
            cafes: [favoriteUnverified, favoriteNear, notFavorite],
            savedStore: savedStore
        )
        viewModel.origin = .manual(makeOrigin())
        // displayedResults向けの絞り込みを掛けても wantToGoCafes には影響しないことを確認（設計書S4: フィルタ無視）
        viewModel.amenityFilter.indoorOnly = true
        await viewModel.refresh()

        XCTAssertTrue(
            viewModel.displayedResults.isEmpty,
            "前提: amenityFilter.indoorOnlyによりdisplayedResultsは0件（いずれもindoor情報なし・未確認）"
        )
        XCTAssertEqual(
            viewModel.wantToGoCafes.map(\.cafe.name),
            ["未確認だが行きたい", "近い行きたい"],
            "追加が新しい順・amenity/未確認フィルタを無視して両方が含まれる"
        )
    }

    func test_行ったに移すとwantToGoCafesから外れvisitedCafesに入る() async {
        let first = makeCafe(name: "先に行った店", latitude: 35.6897, longitude: 139.7007)
        let second = makeCafe(name: "後で行った店", latitude: 35.6898, longitude: 139.7008)
        var storeTime = mondayTokyo(hour: 9)
        let savedStore = makeSavedStore(now: { storeTime })
        savedStore.toggleWantToGo(first.id)
        savedStore.toggleWantToGo(second.id)
        savedStore.toggleVisited(first.id)
        storeTime = mondayTokyo(hour: 12)
        savedStore.toggleVisited(second.id)

        let viewModel = makeViewModel(cafes: [first, second], savedStore: savedStore)
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertTrue(viewModel.wantToGoCafes.isEmpty)
        XCTAssertEqual(viewModel.visitedCafes.map(\.cafe.name), ["後で行った店", "先に行った店"], "行った日が新しい順")
    }

    func test_wantToGoCafesはお気に入りが空なら空配列() async {
        let cafe = makeCafe(name: "カフェ", latitude: 35.6897, longitude: 139.7007)
        let viewModel = makeViewModel(cafes: [cafe])
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        XCTAssertTrue(viewModel.wantToGoCafes.isEmpty)
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

    // MARK: - オフラインキャッシュ（距離は保存せず表示時に計算）

    private struct FailingRepository: CafeRepository {
        let cafes: [Cafe]
        func nearbyCafes(
            latitude: Double, longitude: Double, radiusMeters: Int, onlyDogOK: Bool
        ) async throws -> [CafeWithDistance] {
            throw URLError(.notConnectedToInternet)
        }
        func cafeDetail(id: UUID) async throws -> CafeDetail { throw SupabaseError.emptyResponse }
        func allCafes() async throws -> [Cafe] { cafes }
    }

    func test_取得失敗時はキャッシュの店データから距離を再計算して表示する() async {
        let origin = makeOrigin()
        let far = makeCafe(name: "遠い", latitude: 35.70, longitude: 139.80)
        let near = makeCafe(name: "近い", latitude: 35.6897, longitude: 139.7007)
        let cacheStore = CacheStore(filename: "test-cache-\(UUID().uuidString).json")
        addTeardownBlock { cacheStore.clear() }
        // キャッシュには店データのみ（距離なし）。順序はわざと遠い順
        cacheStore.save([far, near])

        let viewModel = CafeListViewModel(
            repository: FailingRepository(cafes: [far, near]),
            locationService: LocationService(),
            cacheStore: cacheStore,
            savedStore: makeSavedStore()
        )
        viewModel.origin = .manual(origin)
        await viewModel.refresh()

        guard case .offline = viewModel.phase else {
            return XCTFail("通信失敗＋キャッシュありはオフライン表示のはず: \(viewModel.phase)")
        }
        XCTAssertEqual(viewModel.allResults.map(\.cafe.name), ["近い", "遠い"], "距離を再計算して昇順")
        let expected = DistanceCalculator.distanceMeters(
            fromLatitude: origin.latitude, fromLongitude: origin.longitude,
            toLatitude: near.latitude, toLongitude: near.longitude
        )
        XCTAssertEqual(viewModel.allResults[0].distanceMeters, expected, accuracy: 0.001)
    }

    func test_取得成功時のキャッシュに距離は保存されない() async throws {
        let cafe = makeCafe(name: "近い", latitude: 35.6897, longitude: 139.7007)
        let cacheStore = CacheStore(filename: "test-cache-\(UUID().uuidString).json")
        addTeardownBlock { cacheStore.clear() }
        let viewModel = CafeListViewModel(
            repository: DistanceFilteringMockRepository(cafes: [cafe]),
            locationService: LocationService(),
            cacheStore: cacheStore,
            savedStore: makeSavedStore()
        )
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        let raw = try String(contentsOf: cacheStore.fileURL, encoding: .utf8)
        XCTAssertFalse(raw.contains("distance"))
        XCTAssertEqual(cacheStore.load()?.cafes, [cafe])
    }

    // MARK: - stale-while-revalidate（起動直後はローカルで表示 → 裏の取得完了で再表示）

    /// リモート取得を手動で開閉できるモック（取得前=cafes、取得後=remoteCafes に差し替わる）
    private actor RemoteMockRepository: CafeRepository {
        private var cafes: [Cafe]
        private let remoteCafes: [Cafe]
        private var gateClosed: Bool
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private(set) var refreshFlags: [Bool] = []

        init(cafes: [Cafe], remoteCafes: [Cafe], gateClosed: Bool = true) {
            self.cafes = cafes
            self.remoteCafes = remoteCafes
            self.gateClosed = gateClosed
        }

        func openGate() {
            gateClosed = false
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }

        func nearbyCafes(
            latitude: Double, longitude: Double, radiusMeters: Int, onlyDogOK: Bool
        ) async throws -> [CafeWithDistance] {
            cafes.map { cafe in
                CafeWithDistance(
                    cafe: cafe,
                    distanceMeters: DistanceCalculator.distanceMeters(
                        fromLatitude: latitude, fromLongitude: longitude,
                        toLatitude: cafe.latitude, toLongitude: cafe.longitude
                    )
                )
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }
        }

        func cafeDetail(id: UUID) async throws -> CafeDetail {
            throw SupabaseError.emptyResponse
        }

        func allCafes() async throws -> [Cafe] { cafes }

        func refreshRemote(force: Bool) async -> Bool {
            refreshFlags.append(force)
            if gateClosed {
                await withCheckedContinuation { waiters.append($0) }
            }
            let changed = cafes != remoteCafes
            cafes = remoteCafes
            return changed
        }
    }

    private func waitUntil(_ condition: @escaping () async -> Bool, timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("条件が時間内に満たされなかった")
    }

    func test_起動時はリモート取得を待たずローカルで表示し取得完了で再表示する() async {
        let old = makeCafe(name: "古い店", latitude: 35.6897, longitude: 139.7007)
        let new = makeCafe(name: "新しい店", latitude: 35.6898, longitude: 139.7008)
        let repository = RemoteMockRepository(cafes: [old], remoteCafes: [old, new])
        let viewModel = CafeListViewModel(
            repository: repository,
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: makeSavedStore()
        )
        viewModel.origin = .manual(makeOrigin())
        viewModel.includeUnverified = true
        viewModel.sortOrder = .distance

        var phases: [CafeListViewModel.Phase] = []
        let cancellable = viewModel.$phase.sink { phases.append($0) }
        defer { cancellable.cancel() }

        let task = Task { await viewModel.refreshThenRevalidate() }
        // リモート取得は未完了（ゲート閉）だが、ローカルのデータで表示が確定している
        await waitUntil { await repository.refreshFlags.count == 1 }
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["古い店"])
        let centerBefore = viewModel.searchCenter
        let loadingCountBefore = phases.filter { $0 == .loading }.count

        await repository.openGate()
        await task.value

        XCTAssertEqual(Set(viewModel.displayedResults.map(\.cafe.name)), ["古い店", "新しい店"])
        XCTAssertEqual(viewModel.allLoadedCafes.count, 2, "お気に入り解決用の全件も更新される")
        XCTAssertEqual(phases.filter { $0 == .loading }.count, loadingCountBefore, "再表示で読み込み中表示に戻さない")
        XCTAssertEqual(viewModel.searchCenter?.latitude, centerBefore?.latitude)
        XCTAssertEqual(viewModel.searchCenter?.longitude, centerBefore?.longitude)
        XCTAssertTrue(viewModel.includeUnverified, "絞り込み条件は保たれる")
        let flags = await repository.refreshFlags
        XCTAssertEqual(flags, [false], "起動時の裏取得は force:false")
    }

    func test_裏の取得で変更がなければ再表示しない() async {
        let cafe = makeCafe(name: "店", latitude: 35.6897, longitude: 139.7007)
        let repository = RemoteMockRepository(cafes: [cafe], remoteCafes: [cafe], gateClosed: false)
        let viewModel = CafeListViewModel(
            repository: repository,
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: makeSavedStore()
        )
        viewModel.origin = .manual(makeOrigin())

        await viewModel.refresh()
        var changeCount = 0
        let cancellable = viewModel.$allResults.dropFirst().sink { _ in changeCount += 1 }
        defer { cancellable.cancel() }
        await viewModel.revalidateInBackground()

        XCTAssertEqual(changeCount, 0, "変更なし(false)なら表示を作り直さない")
        XCTAssertEqual(viewModel.phase, .loaded)
    }

    func test_裏の取得は同時に2本走らない() async {
        let old = makeCafe(name: "古い店", latitude: 35.6897, longitude: 139.7007)
        let new = makeCafe(name: "新しい店", latitude: 35.6898, longitude: 139.7008)
        let repository = RemoteMockRepository(cafes: [old], remoteCafes: [old, new])
        let viewModel = CafeListViewModel(
            repository: repository,
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: makeSavedStore()
        )
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()

        let first = Task { await viewModel.revalidateInBackground() }
        await waitUntil { await repository.refreshFlags.count == 1 }
        let second = Task { await viewModel.revalidateInBackground() }
        await second.value  // 実行中なので即座に戻る
        let flagsWhileRunning = await repository.refreshFlags
        XCTAssertEqual(flagsWhileRunning.count, 1)

        await repository.openGate()
        await first.value
        XCTAssertEqual(viewModel.displayedResults.count, 2)
    }

    func test_再読み込みはforceで取得を待ってから再表示する() async {
        let old = makeCafe(name: "古い店", latitude: 35.6897, longitude: 139.7007)
        let new = makeCafe(name: "新しい店", latitude: 35.6898, longitude: 139.7008)
        let repository = RemoteMockRepository(cafes: [old], remoteCafes: [old, new])
        let viewModel = CafeListViewModel(
            repository: repository,
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: makeSavedStore()
        )
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()
        XCTAssertEqual(viewModel.displayedResults.count, 1)

        let task = Task { await viewModel.reloadFromRemote() }
        await waitUntil { await repository.refreshFlags.count == 1 }
        XCTAssertEqual(viewModel.phase, .loading, "取得を待っている間は読み込み中")
        XCTAssertEqual(viewModel.displayedResults.count, 1, "取得が終わるまで新データは出ない")

        await repository.openGate()
        await task.value

        let flags = await repository.refreshFlags
        XCTAssertEqual(flags, [true], "再読み込みは force:true")
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertEqual(Set(viewModel.displayedResults.map(\.cafe.name)), ["古い店", "新しい店"])
    }

    func test_再読み込みでデータが変わったらお気に入り解決用の全件も取り直す() async {
        let old = makeCafe(name: "古い店", latitude: 35.6897, longitude: 139.7007)
        let new = makeCafe(name: "新しい店", latitude: 35.6898, longitude: 139.7008)
        let repository = RemoteMockRepository(cafes: [old], remoteCafes: [old, new])
        let viewModel = CafeListViewModel(
            repository: repository,
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: makeSavedStore()
        )
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()
        XCTAssertEqual(viewModel.allLoadedCafes.map(\.name), ["古い店"])

        await repository.openGate()
        await viewModel.reloadFromRemote()

        XCTAssertEqual(Set(viewModel.allLoadedCafes.map(\.name)), ["古い店", "新しい店"], "再読み込み後は全件も最新")
        XCTAssertEqual(viewModel.displayedResults.count, 2)
    }

    /// 最初の nearbyCafes だけ開放まで待たせ、2回目以降は即返すモック（起点変更の割り込み再現用）
    private actor FirstCallGatedRepository: CafeRepository {
        let cafes: [Cafe]
        private var gateClosed = true
        private var waiter: CheckedContinuation<Void, Never>?
        private(set) var callCount = 0

        init(cafes: [Cafe]) { self.cafes = cafes }

        func openGate() {
            gateClosed = false
            waiter?.resume()
            waiter = nil
        }

        func nearbyCafes(
            latitude: Double, longitude: Double, radiusMeters: Int, onlyDogOK: Bool
        ) async throws -> [CafeWithDistance] {
            callCount += 1
            if callCount == 1 {
                await withCheckedContinuation { waiter = $0 }
            }
            return cafes.map { cafe in
                CafeWithDistance(
                    cafe: cafe,
                    distanceMeters: DistanceCalculator.distanceMeters(
                        fromLatitude: latitude, fromLongitude: longitude,
                        toLatitude: cafe.latitude, toLongitude: cafe.longitude
                    )
                )
            }
        }

        func cafeDetail(id: UUID) async throws -> CafeDetail { throw SupabaseError.emptyResponse }
        func allCafes() async throws -> [Cafe] { cafes }
    }

    func test_取得中に起点が変わったら古い起点の結果で上書きしない() async {
        let cafe = makeCafe(name: "店", latitude: 35.6897, longitude: 139.7007)
        let repository = FirstCallGatedRepository(cafes: [cafe])
        let viewModel = CafeListViewModel(
            repository: repository,
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: makeSavedStore()
        )
        let areaA = makeOrigin()  // 新宿
        let areaB = ManualArea(id: "test-tokyo", name: "テスト:東京", latitude: 35.6812, longitude: 139.7671)

        viewModel.origin = .manual(areaA)
        let first = Task { await viewModel.refresh() }
        await waitUntil { await repository.callCount == 1 }  // A の取得が止まっている

        viewModel.origin = .manual(areaB)
        await viewModel.refresh()  // B の取得は先に完了する
        await repository.openGate()  // 遅れて A の取得が返る
        await first.value

        XCTAssertEqual(viewModel.searchCenter?.latitude, areaB.latitude)
        let expectedFromB = DistanceCalculator.distanceMeters(
            fromLatitude: areaB.latitude, fromLongitude: areaB.longitude,
            toLatitude: cafe.latitude, toLongitude: cafe.longitude
        )
        XCTAssertEqual(viewModel.allResults.first?.distanceMeters ?? -1, expectedFromB, accuracy: 0.001,
                       "古い起点(A)の距離で上書きされない")
        XCTAssertEqual(viewModel.phase, .loaded)
    }

    /// 取得は常に失敗し、裏の更新確認は「変更あり」を返すモック
    private struct FailingChangedRepository: CafeRepository {
        let cafes: [Cafe]
        func nearbyCafes(
            latitude: Double, longitude: Double, radiusMeters: Int, onlyDogOK: Bool
        ) async throws -> [CafeWithDistance] {
            throw URLError(.notConnectedToInternet)
        }
        func cafeDetail(id: UUID) async throws -> CafeDetail { throw SupabaseError.emptyResponse }
        func allCafes() async throws -> [Cafe] { cafes }
        func refreshRemote(force: Bool) async -> Bool { true }
    }

    func test_error状態は裏の取得でloadedに上書きされない() async {
        let cafe = makeCafe(name: "店", latitude: 35.6897, longitude: 139.7007)
        let viewModel = CafeListViewModel(
            repository: FailingChangedRepository(cafes: [cafe]),
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),  // キャッシュなし
            savedStore: makeSavedStore()
        )
        viewModel.origin = .manual(makeOrigin())
        await viewModel.refresh()
        guard case .error = viewModel.phase else {
            return XCTFail("取得失敗＋キャッシュなしはエラーのはず: \(viewModel.phase)")
        }

        await viewModel.revalidateInBackground()

        guard case .error = viewModel.phase else {
            return XCTFail("裏の取得による再表示で .error を上書きしない: \(viewModel.phase)")
        }
        XCTAssertEqual(viewModel.allLoadedCafes.map(\.name), ["店"], "全件の更新だけは行う")
    }
}
