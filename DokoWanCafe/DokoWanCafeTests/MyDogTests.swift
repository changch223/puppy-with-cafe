import XCTest
@testable import DokoWanCafe

/// うちの子（再設計 段階3）: データのデコード・設定の保存と初回表示の一回性・チップの絞り込み・見出し・タグ。
@MainActor
final class MyDogTests: XCTestCase {
    // MARK: - デコード（凍結フィクスチャ cafes_mydog.json）

    private func loadFixtureCafes() throws -> [Cafe] {
        let bundle = Bundle(for: MyDogTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "cafes_mydog", withExtension: "json"))
        let file = try SupabaseGateway.decoder.decode(CafeDataFile.self, from: Data(contentsOf: url))
        return file.cafes.map(\.cafe)
    }

    func test_新キーがDogAmenitiesにデコードされる() throws {
        let amenities = try XCTUnwrap(loadFixtureCafes()[0].dogAmenities)
        XCTAssertEqual(amenities.sizeMaxIndoor, .medium)
        XCTAssertEqual(amenities.sizeMaxTerrace, .large)
        XCTAssertEqual(amenities.indoorStyle, [.floor, .carrier])
        // 既存のキーも従来どおり
        XCTAssertEqual(amenities.indoor, true)
        XCTAssertEqual(amenities.terrace, true)
        XCTAssertEqual(amenities.dogMenu, false)
        XCTAssertNil(amenities.largeDogs)
    }

    func test_未知の値は無視してデコード全体は落とさない() throws {
        let cafes = try loadFixtureCafes()
        XCTAssertEqual(cafes.count, 3, "未知の値があっても店は読み込まれる")
        let amenities = try XCTUnwrap(cafes[1].dogAmenities)
        XCTAssertNil(amenities.sizeMaxIndoor, "未知の大きさは無視")
        XCTAssertNil(amenities.sizeMaxTerrace, "型違いの値も無視")
        XCTAssertEqual(amenities.indoorStyle, [.hold], "未知の過ごし方だけ落とす")
        XCTAssertEqual(amenities.indoor, true)
    }

    func test_新キーが無い店はnilのまま() throws {
        let amenities = try XCTUnwrap(loadFixtureCafes()[2].dogAmenities)
        XCTAssertNil(amenities.sizeMaxIndoor)
        XCTAssertNil(amenities.sizeMaxTerrace)
        XCTAssertNil(amenities.indoorStyle)
        XCTAssertEqual(amenities.dogMenu, true)
    }

    func test_既存の凍結フィクスチャも従来どおり読める() throws {
        let bundle = Bundle(for: MyDogTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "cafes", withExtension: "json"))
        let file = try SupabaseGateway.decoder.decode(CafeDataFile.self, from: Data(contentsOf: url))
        XCTAssertEqual(file.cafes.count, 7)
        XCTAssertTrue(file.cafes.allSatisfy { $0.cafe.dogAmenities?.sizeMaxIndoor == nil })
    }

    func test_DogAmenitiesはエンコードして読み戻せる() throws {
        let original = DogAmenities(
            indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil,
            sizeMaxIndoor: .small, sizeMaxTerrace: .large, indoorStyle: [.hold]
        )
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(DogAmenities.self, from: data), original)
    }

    // MARK: - 設定の保存と初回表示の一回性

    private func makeDefaults() -> UserDefaults {
        let suiteName = "MyDogTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func test_初期状態は未設定で初回の2問は未表示() {
        let store = DogProfileStore(defaults: makeDefaults())
        XCTAssertNil(store.profile)
        XCTAssertFalse(store.hasShownOnboarding)
    }

    func test_設定は保存され別インスタンスから読める() {
        let defaults = makeDefaults()
        DogProfileStore(defaults: defaults).save(DogProfile(size: .medium, styles: [.floor, .hold]))
        let reloaded = DogProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.profile, DogProfile(size: .medium, styles: [.floor, .hold]))
    }

    func test_設定を変更すると上書きされる() {
        let defaults = makeDefaults()
        let store = DogProfileStore(defaults: defaults)
        store.save(DogProfile(size: .small))
        store.save(DogProfile(size: .large, styles: [.carrier]))
        XCTAssertEqual(DogProfileStore(defaults: defaults).profile, DogProfile(size: .large, styles: [.carrier]))
    }

    func test_異なるsuiteは互いに影響しない() {
        DogProfileStore(defaults: makeDefaults()).save(DogProfile(size: .small))
        XCTAssertNil(DogProfileStore(defaults: makeDefaults()).profile)
    }

    func test_読めない保存データは未設定として扱う() {
        let defaults = makeDefaults()
        defaults.set(Data("壊れたデータ".utf8), forKey: DogProfileStore.profileKey)
        XCTAssertNil(DogProfileStore(defaults: defaults).profile)
    }

    func test_初回の2問はデータを表示できてから出す() {
        let store = DogProfileStore(defaults: makeDefaults())
        XCTAssertFalse(store.shouldPresentOnboarding(dataDisplayed: false), "データ表示前は出さない")
        XCTAssertTrue(store.shouldPresentOnboarding(dataDisplayed: true))
    }

    func test_初回の2問は一度出したら二度と出さない_アプリを開き直しても() {
        let defaults = makeDefaults()
        let store = DogProfileStore(defaults: defaults)
        store.markOnboardingShown()
        // 「あとで設定する」を選んで未設定のままでも出さない
        XCTAssertNil(store.profile)
        XCTAssertFalse(store.shouldPresentOnboarding(dataDisplayed: true))
        let reopened = DogProfileStore(defaults: defaults)
        XCTAssertTrue(reopened.hasShownOnboarding)
        XCTAssertFalse(reopened.shouldPresentOnboarding(dataDisplayed: true))
    }

    func test_すでに設定済みなら初回の2問は出さない() {
        let defaults = makeDefaults()
        DogProfileStore(defaults: defaults).save(DogProfile(size: .small))
        XCTAssertFalse(DogProfileStore(defaults: defaults).shouldPresentOnboarding(dataDisplayed: true))
    }

    func test_DogProfileの表示用の並びと要約() {
        let profile = DogProfile(size: .small, styles: [.hold, .floor])
        XCTAssertEqual(profile.orderedStyles, [.floor, .hold])
        XCTAssertEqual(profile.stylesSummary, "床で待てる、抱っこ")
        XCTAssertNil(DogProfile(size: .small).stylesSummary)
        XCTAssertEqual(DogSize.small.initial, "小")
        XCTAssertEqual(DogSize.medium.initial, "中")
        XCTAssertEqual(DogSize.large.initial, "大")
        XCTAssertTrue(DogSize.small < .medium && DogSize.medium < .large)
    }

    // MARK: - チップの絞り込み・見出し・タグ

    private func makeItem(
        name: String,
        status: DogPolicyStatus = .allowed,
        amenities: DogAmenities?,
        lastVerified: Date? = Date(timeIntervalSince1970: 1_780_000_000),
        distance: Double = 100
    ) -> CafeWithDistance {
        CafeWithDistance(
            cafe: Cafe(
                id: UUID(), placeID: nil, name: name,
                latitude: 35.68, longitude: 139.76,
                address: nil, contact: nil,
                dogPolicyStatus: status, dogPolicyCondition: nil,
                lastVerified: lastVerified, representativeSourceID: nil,
                hasConflict: false, isClosed: false, area: "tokyo",
                dogAmenities: amenities
            ),
            distanceMeters: distance
        )
    }

    private var sampleItems: [CafeWithDistance] {
        [
            // 店内OK・上限なし → 小型犬は入れる、中型犬は分からない
            makeItem(name: "店内OK", amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil)),
            // 店内は中型犬まで → 大型犬は入れない
            makeItem(
                name: "中型犬まで",
                amenities: DogAmenities(indoor: true, terrace: false, largeDogs: nil, dogMenu: nil, sizeMaxIndoor: .medium)
            ),
            // 大型犬可
            makeItem(name: "大型犬可", amenities: DogAmenities(indoor: true, terrace: true, largeDogs: true, dogMenu: nil)),
            // 未確認
            makeItem(
                name: "未確認", status: .unverified,
                amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil)
            ),
            // 設備情報なし
            makeItem(name: "情報なし", amenities: nil),
        ]
    }

    func test_チップがオフなら絞り込まない() {
        let result = CafeFilter.apply(amenities: AmenityFilter(), dog: nil, to: sampleItems)
        XCTAssertEqual(result.map(\.cafe.name), ["店内OK", "中型犬まで", "大型犬可", "情報なし"])
    }

    func test_小型犬のうちの子OKは入れると明記された店だけ() {
        let result = CafeFilter.apply(amenities: AmenityFilter(), dog: DogProfile(size: .small), to: sampleItems)
        XCTAssertEqual(result.map(\.cafe.name), ["店内OK", "中型犬まで", "大型犬可"])
    }

    func test_中型犬のうちの子OKは上限内か大型犬可の店だけ() {
        let result = CafeFilter.apply(amenities: AmenityFilter(), dog: DogProfile(size: .medium), to: sampleItems)
        XCTAssertEqual(result.map(\.cafe.name), ["中型犬まで", "大型犬可"])
    }

    func test_大型犬のうちの子OKは大型犬可の店だけ() {
        let result = CafeFilter.apply(amenities: AmenityFilter(), dog: DogProfile(size: .large), to: sampleItems)
        XCTAssertEqual(result.map(\.cafe.name), ["大型犬可"])
    }

    func test_未確認を含めてもうちの子OKには出ない() {
        let result = CafeFilter.apply(
            amenities: AmenityFilter(), includeUnverified: true, dog: DogProfile(size: .small), to: sampleItems
        )
        XCTAssertFalse(result.contains { $0.cafe.name == "未確認" })
    }

    func test_うちの子OKは他のチップと一緒に効く() {
        let result = CafeFilter.apply(
            amenities: AmenityFilter(terraceOnly: true), dog: DogProfile(size: .small), to: sampleItems
        )
        XCTAssertEqual(result.map(\.cafe.name), ["大型犬可"])
    }

    func test_見出しはうちの子の大きさ入り() {
        let dog = DogProfile(size: .small)
        let plain = SheetHeadline.make(
            count: 120, amenities: AmenityFilter(), openNowOnly: false, myDog: dog,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(plain.title, "うちの子（小型犬）が入れるお店 120件")

        let open = SheetHeadline.make(
            count: 5, amenities: AmenityFilter(), openNowOnly: true, myDog: DogProfile(size: .large),
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(open.title, "今開いている、うちの子（大型犬）が入れるお店 5件")

        let amenity = SheetHeadline.make(
            count: 7, amenities: AmenityFilter(indoorOnly: true), openNowOnly: false, myDog: DogProfile(size: .medium),
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(amenity.title, "うちの子（中型犬）が入れる、店内OKのお店 7件")

        let both = SheetHeadline.make(
            count: 2, amenities: AmenityFilter(terraceOnly: true), openNowOnly: true, targetLabel: "土 12:00",
            myDog: dog, originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(both.title, "土 12:00 に開いている、うちの子（小型犬）が入れる、テラスのお店 2件")
    }

    func test_チップがオフの見出しは従来どおり() {
        let text = SheetHeadline.make(
            count: 10, amenities: AmenityFilter(), openNowOnly: false, myDog: nil,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.title, "犬OKのお店 10件")
    }

    func test_タグはうちの子OKが先頭に付く() {
        let items = sampleItems
        let fitting = CafePresentation.tags(for: items[0].cafe, dog: DogProfile(size: .small))
        XCTAssertEqual(fitting.map(\.label), ["うちの子OK", "店内OK"])
        XCTAssertEqual(fitting.first?.kind, .myDog)
        // 分からない店・入れない店には付けない
        XCTAssertEqual(CafePresentation.tags(for: items[0].cafe, dog: DogProfile(size: .medium)).map(\.label), ["店内OK"])
        XCTAssertEqual(CafePresentation.tags(for: items[1].cafe, dog: DogProfile(size: .large)).map(\.label), ["店内OK"])
        // 未設定なら従来どおり
        XCTAssertEqual(CafePresentation.tags(for: items[0].cafe).map(\.label), ["店内OK"])
    }

    func test_読み上げにうちの子の判定が入る() {
        let items = sampleItems
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let ok = CafePresentation.accessibilityLabel(for: items[0], at: now, dog: DogProfile(size: .small))
        XCTAssertTrue(ok.contains("うちの子OK"))
        let ng = CafePresentation.accessibilityLabel(for: items[1], at: now, dog: DogProfile(size: .large))
        XCTAssertTrue(ng.contains("うちの子は不可（店内は中型犬まで・テラスは不可）"))
        let none = CafePresentation.accessibilityLabel(for: items[0], at: now)
        XCTAssertFalse(none.contains("うちの子"))
    }

    func test_地図ピンの読み上げにうちの子の判定が入る() {
        let items = sampleItems
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let labels = MapViewModel.spokenLabels(
            for: items, savedPlaces: SavedPlaces(), at: now, isTargetTime: false, clock: now,
            dog: DogProfile(size: .large)
        )
        XCTAssertTrue(labels[items[2].cafe.id]?.contains("うちの子OK") == true)
        XCTAssertTrue(labels[items[1].cafe.id]?.contains("うちの子は不可") == true)
        let without = MapViewModel.spokenLabels(
            for: items, savedPlaces: SavedPlaces(), at: now, isTargetTime: false, clock: now
        )
        XCTAssertFalse(without[items[2].cafe.id]?.contains("うちの子") == true)
    }

    // MARK: - ViewModel（チップの状態）

    private struct MockRepository: CafeRepository {
        let cafes: [Cafe]
        func nearbyCafes(latitude: Double, longitude: Double, radiusMeters: Int, onlyDogOK: Bool) async throws -> [CafeWithDistance] {
            cafes.map { CafeWithDistance(cafe: $0, distanceMeters: 100) }
        }
        func cafeDetail(id: UUID) async throws -> CafeDetail {
            guard let cafe = cafes.first(where: { $0.id == id }) else { throw SupabaseError.emptyResponse }
            return CafeDetail(cafe: cafe, sources: [])
        }
        func allCafes() async throws -> [Cafe] { cafes }
    }

    private func makeViewModel() async -> CafeListViewModel {
        let cafes = sampleItems.map(\.cafe)
        let viewModel = CafeListViewModel(
            repository: MockRepository(cafes: cafes),
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json"),
            savedStore: SavedPlacesStore(defaults: makeDefaults())
        )
        viewModel.origin = .manual(ManualArea(id: "t", name: "テスト", latitude: 35.68, longitude: 139.76))
        await viewModel.refresh()
        return viewModel
    }

    func test_チップをオンにすると入れる店だけになりクリアで戻る() async {
        let viewModel = await makeViewModel()
        XCTAssertEqual(viewModel.displayedResults.count, 4)

        viewModel.dogProfile = DogProfile(size: .medium)
        XCTAssertEqual(viewModel.displayedResults.count, 4, "設定しただけでは絞り込まない")

        viewModel.myDogOnly = true
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name).sorted(), ["中型犬まで", "大型犬可"])
        XCTAssertTrue(viewModel.hasActiveChips)
        XCTAssertEqual(viewModel.activeFilterCount, 1)

        viewModel.resetFilters()
        XCTAssertFalse(viewModel.myDogOnly)
        XCTAssertEqual(viewModel.displayedResults.count, 4)
    }

    func test_うちの子を変えると絞り込みも変わる() async {
        let viewModel = await makeViewModel()
        viewModel.dogProfile = DogProfile(size: .small)
        viewModel.myDogOnly = true
        XCTAssertEqual(viewModel.displayedResults.count, 3)
        viewModel.dogProfile = DogProfile(size: .large)
        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["大型犬可"])
    }

    func test_未設定ではチップはオンにならない() async {
        let viewModel = await makeViewModel()
        viewModel.dogProfile = DogProfile(size: .small)
        viewModel.myDogOnly = true
        viewModel.dogProfile = nil
        XCTAssertFalse(viewModel.myDogOnly)
        XCTAssertNil(viewModel.myDogFilterDog)
        XCTAssertEqual(viewModel.displayedResults.count, 4)
    }
}
