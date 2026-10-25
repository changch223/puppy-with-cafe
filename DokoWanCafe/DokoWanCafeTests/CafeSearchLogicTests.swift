import XCTest
@testable import DokoWanCafe

/// 検索画面の純ロジック（店名検索の正規化と一致・よく探されるエリアの並べ替え・最近の検索）のユニットテスト
final class CafeSearchLogicTests: XCTestCase {
    private func makeCafe(name: String, latitude: Double = 35.68, longitude: Double = 139.76, isClosed: Bool = false) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: name,
            latitude: latitude, longitude: longitude,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: isClosed, area: "tokyo"
        )
    }

    // MARK: - 正規化

    func test_全角半角と大文字小文字を同一視する() {
        XCTAssertEqual(CafeNameSearch.normalize("ＣＡＦＥ"), CafeNameSearch.normalize("cafe"))
        XCTAssertEqual(CafeNameSearch.normalize("Cafe"), "cafe")
        XCTAssertEqual(CafeNameSearch.normalize("ｶﾌｪ"), CafeNameSearch.normalize("カフェ"))
    }

    func test_ひらがなとカタカナを同一視する() {
        XCTAssertEqual(CafeNameSearch.normalize("かふぇ"), CafeNameSearch.normalize("カフェ"))
        // 濁点つきでも濁点が落ちない
        XCTAssertNotEqual(CafeNameSearch.normalize("がっこう"), CafeNameSearch.normalize("かっこう"))
    }

    func test_ラテン文字のアクセント記号は無視するが濁点は落とさない() {
        XCTAssertEqual(CafeNameSearch.normalize("Café"), "cafe")
        XCTAssertEqual(CafeNameSearch.normalize("bébé"), "bebe")
        XCTAssertEqual(CafeNameSearch.normalize("Crème Brûlée"), "cremebrulee")
        // 分解形（e + 結合アクセント）も同じ
        XCTAssertEqual(CafeNameSearch.normalize("Cafe\u{0301}"), "cafe")
        // かなの濁点・半濁点は別の文字
        XCTAssertNotEqual(CafeNameSearch.normalize("ぱん"), CafeNameSearch.normalize("はん"))
        XCTAssertNotEqual(CafeNameSearch.normalize("ガッコウ"), CafeNameSearch.normalize("カッコウ"))
    }

    func test_アクセント付きの店名にアクセントなしの入力で一致する() {
        let cafes = [makeCafe(name: "Café de Bébé"), makeCafe(name: "ベベ")]
        XCTAssertEqual(CafeNameSearch.results(query: "cafe", in: cafes).map(\.name), ["Café de Bébé"])
        XCTAssertEqual(CafeNameSearch.results(query: "bebe", in: cafes).map(\.name), ["Café de Bébé"])
        XCTAssertEqual(CafeNameSearch.results(query: "Café", in: cafes).map(\.name), ["Café de Bébé"])
    }

    func test_空白は無視する() {
        XCTAssertEqual(CafeNameSearch.normalize(" ブルー　ボトル "), "ブルーボトル")
    }

    // MARK: - 一致

    func test_店名の部分一致で見つかる() {
        let cafes = [makeCafe(name: "ブルーボトルコーヒー 渋谷"), makeCafe(name: "ドッグカフェ ハチ"), makeCafe(name: "Cafe Blue")]
        XCTAssertEqual(CafeNameSearch.results(query: "ぶるー", in: cafes).map(\.name), ["ブルーボトルコーヒー 渋谷"])
        XCTAssertEqual(CafeNameSearch.results(query: "ＢＬＵＥ", in: cafes).map(\.name), ["Cafe Blue"])
        XCTAssertEqual(CafeNameSearch.results(query: "ＣＡＦＥ", in: cafes).map(\.name), ["Cafe Blue"])
    }

    func test_前方一致を先に並べる() {
        let cafes = [makeCafe(name: "渋谷ブルー"), makeCafe(name: "ブルー渋谷")]
        XCTAssertEqual(CafeNameSearch.results(query: "ブルー", in: cafes).map(\.name), ["ブルー渋谷", "渋谷ブルー"])
    }

    func test_閉店の店は出さず空の入力は何も返さない() {
        let cafes = [makeCafe(name: "閉店カフェ", isClosed: true), makeCafe(name: "営業カフェ")]
        XCTAssertEqual(CafeNameSearch.results(query: "カフェ", in: cafes).map(\.name), ["営業カフェ"])
        XCTAssertTrue(CafeNameSearch.results(query: "   ", in: cafes).isEmpty)
    }

    func test_候補は最大20件() {
        let cafes = (0..<50).map { makeCafe(name: "カフェ\($0)") }
        XCTAssertEqual(CafeNameSearch.results(query: "カフェ", in: cafes).count, 20)
        XCTAssertEqual(CafeNameSearch.results(query: "カフェ", in: cafes, limit: 3).count, 3)
    }

    // MARK: - よく探されるエリア

    func test_掲載店が多い順に並べる() {
        let shibuya = ManualArea(id: "shibuya", name: "渋谷", latitude: 35.6580, longitude: 139.7016)
        let shinjuku = ManualArea(id: "shinjuku", name: "新宿", latitude: 35.6896, longitude: 139.7006)
        let tachikawa = ManualArea(id: "tachikawa", name: "立川", latitude: 35.6977, longitude: 139.4137)
        var cafes = (0..<3).map { _ in makeCafe(name: "渋谷の店", latitude: 35.6585, longitude: 139.7020) }
        cafes += (0..<5).map { _ in makeCafe(name: "新宿の店", latitude: 35.6900, longitude: 139.7010) }
        cafes.append(makeCafe(name: "閉店", latitude: 35.6900, longitude: 139.7010, isClosed: true))

        let ranked = PopularAreaRanking.ranked(areas: [shibuya, shinjuku, tachikawa], cafes: cafes)
        XCTAssertEqual(ranked.map(\.area.name), ["新宿", "渋谷", "立川"])
        XCTAssertEqual(ranked.map(\.count), [5, 3, 0])
    }

    func test_未確認の店は数えない() {
        // 読み上げる件数を、地図・一覧に既定で出る店の数と一致させる
        let area = ManualArea(id: "a", name: "A", latitude: 35.6580, longitude: 139.7016)
        var unverified = makeCafe(name: "未確認", latitude: 35.6585, longitude: 139.7020)
        unverified.dogPolicyStatus = .unverified
        let shown = makeCafe(name: "表示される", latitude: 35.6585, longitude: 139.7020)
        XCTAssertEqual(PopularAreaRanking.ranked(areas: [area], cafes: [unverified, shown]).first?.count, 1)
    }

    func test_同数なら渡された順を保つ() {
        let a = ManualArea(id: "a", name: "A", latitude: 35.60, longitude: 139.60)
        let b = ManualArea(id: "b", name: "B", latitude: 35.70, longitude: 139.70)
        let ranked = PopularAreaRanking.ranked(areas: [a, b], cafes: [])
        XCTAssertEqual(ranked.map(\.area.name), ["A", "B"])
    }

    func test_半径1500m外の店は数えない() {
        let area = ManualArea(id: "a", name: "A", latitude: 35.6580, longitude: 139.7016)
        // 北へ約2km
        let far = makeCafe(name: "遠い", latitude: 35.6760, longitude: 139.7016)
        XCTAssertEqual(PopularAreaRanking.ranked(areas: [area], cafes: [far]).first?.count, 0)
    }

    // MARK: - 最近の検索

    private func entry(_ name: String) -> RecentSearch {
        RecentSearch(name: name, latitude: 35.0, longitude: 139.0)
    }

    func test_新しい検索が先頭に入る() {
        let list = RecentSearchLogic.adding(entry("新宿"), to: [entry("渋谷")])
        XCTAssertEqual(list.map(\.name), ["新宿", "渋谷"])
    }

    func test_同じ名前は重複せず先頭へ移る() {
        let list = RecentSearchLogic.adding(entry("渋谷"), to: [entry("新宿"), entry("渋谷"), entry("池袋")])
        XCTAssertEqual(list.map(\.name), ["渋谷", "新宿", "池袋"])
    }

    func test_直近5件までで古いものから捨てる() {
        var list: [RecentSearch] = []
        for name in ["1", "2", "3", "4", "5", "6"] {
            list = RecentSearchLogic.adding(entry(name), to: list)
        }
        XCTAssertEqual(list.map(\.name), ["6", "5", "4", "3", "2"])
    }

    func test_保存形式の往復と壊れたデータ() {
        let list = [entry("渋谷"), entry("新宿")]
        XCTAssertEqual(RecentSearchLogic.decode(RecentSearchLogic.encode(list)), list)
        XCTAssertEqual(RecentSearchLogic.decode(Data("not json".utf8)), [])
        XCTAssertEqual(RecentSearchLogic.decode(nil), [])
    }

    @MainActor
    func test_ストアは端末内に保存して再起動後も復元する() {
        let suiteName = "RecentSearchStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        let store = RecentSearchStore(defaults: defaults)
        XCTAssertTrue(store.entries.isEmpty)
        store.add(name: "渋谷", latitude: 35.658, longitude: 139.7016)
        store.add(name: "新宿", latitude: 35.6896, longitude: 139.7006)

        let restored = RecentSearchStore(defaults: defaults)
        XCTAssertEqual(restored.entries.map(\.name), ["新宿", "渋谷"])
        XCTAssertEqual(restored.entries.first?.origin, .searched(name: "新宿", latitude: 35.6896, longitude: 139.7006))
    }
}
