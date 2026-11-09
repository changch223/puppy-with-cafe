import XCTest
@testable import DokoWanCafe

/// 検索画面の純ロジック（店名検索の正規化と一致・よく探されるエリアの並べ替え・最近の検索と見たお店）のユニットテスト
final class CafeSearchLogicTests: XCTestCase {
    private func makeCafe(name: String, latitude: Double = 35.68, longitude: Double = 139.76, isClosed: Bool = false, reading: String? = nil) -> Cafe {
        var cafe = Cafe(
            id: UUID(), placeID: nil, name: name,
            latitude: latitude, longitude: longitude,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: isClosed, area: "tokyo"
        )
        cafe.nameReading = reading
        return cafe
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

    // MARK: - 表記の違い（&・カフェ・珈琲）

    func test_アンパサンドはandとして同一視する() {
        XCTAssertEqual(CafeNameSearch.normalize("&"), "and")
        XCTAssertEqual(CafeNameSearch.normalize("＆"), "and")
        XCTAssertEqual(CafeNameSearch.normalize("Cafe & Bar"), CafeNameSearch.normalize("cafe and bar"))
        XCTAssertEqual(CafeNameSearch.normalize("カフェ＆バー"), CafeNameSearch.normalize("cafe and バー"))
    }

    func test_カフェはcafeとして同一視しひらがな半角も同じ() {
        XCTAssertEqual(CafeNameSearch.normalize("カフェ"), "cafe")
        XCTAssertEqual(CafeNameSearch.normalize("かふぇ"), "cafe")
        XCTAssertEqual(CafeNameSearch.normalize("ｶﾌｪ"), "cafe")
        XCTAssertEqual(CafeNameSearch.normalize("ドッグカフェ"), "ドッグcafe")
        XCTAssertEqual(CafeNameSearch.normalize("Café"), "cafe")
    }

    func test_珈琲とコーヒーとcoffeeは同一視する() {
        XCTAssertEqual(CafeNameSearch.normalize("珈琲"), "coffee")
        XCTAssertEqual(CafeNameSearch.normalize("コーヒー"), "coffee")
        XCTAssertEqual(CafeNameSearch.normalize("こーひー"), "coffee")
        XCTAssertEqual(CafeNameSearch.normalize("Coffee"), "coffee")
        XCTAssertEqual(CafeNameSearch.normalize("ブルーボトルコーヒー"), CafeNameSearch.normalize("ブルーボトル珈琲"))
    }

    func test_表記の違いを入力にも店名にもかけて一致する() {
        let cafes = [
            makeCafe(name: "カフェ&ダイニング"), makeCafe(name: "珈琲 ハチ"),
            makeCafe(name: "コーヒースタンド"), makeCafe(name: "Coffee Roast"), makeCafe(name: "公園前"),
        ]
        XCTAssertEqual(CafeNameSearch.results(query: "cafe and", in: cafes).map(\.name), ["カフェ&ダイニング"])
        XCTAssertEqual(CafeNameSearch.results(query: "カフェ＆", in: cafes).map(\.name), ["カフェ&ダイニング"])
        XCTAssertEqual(
            CafeNameSearch.results(query: "珈琲", in: cafes).map(\.name),
            ["珈琲 ハチ", "コーヒースタンド", "Coffee Roast"]
        )
        XCTAssertEqual(
            CafeNameSearch.results(query: "coffee", in: cafes).map(\.name),
            ["珈琲 ハチ", "コーヒースタンド", "Coffee Roast"]
        )
    }

    func test_打ちかけの入力は置き換え前の表記でも当たる() {
        // 「カフ」「コーヒ」は置き換え後の「cafe」「coffee」には前方一致しないが、置き換え前の表記で当たる
        let cafes = [makeCafe(name: "カフェ ハチ"), makeCafe(name: "コーヒー屋"), makeCafe(name: "公園前")]
        XCTAssertEqual(CafeNameSearch.results(query: "カフ", in: cafes).map(\.name), ["カフェ ハチ"])
        XCTAssertEqual(CafeNameSearch.results(query: "かふ", in: cafes).map(\.name), ["カフェ ハチ"])
        XCTAssertEqual(CafeNameSearch.results(query: "コーヒ", in: cafes).map(\.name), ["コーヒー屋"])
    }

    func test_置き換えはエリア名の中点と条件の言葉に影響しない() {
        // エリア名の「・」は残る（部分に分ける処理は元の名前で行う）
        XCTAssertEqual(CafeNameSearch.normalize("表参道・青山"), "表参道・青山")
        XCTAssertEqual(SearchArea.defaultKeys(for: "表参道・青山"), ["表参道・青山", "表参道", "青山"])
        // 条件の言葉は置き換えの対象を含まないので、正規化の結果が変わらない
        for condition in SearchCondition.allCases {
            for word in condition.words {
                XCTAssertEqual(CafeNameSearch.normalize(word), CafeNameSearch.normalizeBase(word), word)
            }
        }
        // 「カフェ」と打っても条件は出ない
        XCTAssertTrue(SearchSuggestion.conditions(for: "カフェ", hasMyDog: true).isEmpty)
        XCTAssertEqual(SearchSuggestion.conditions(for: "テラス", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "大型犬", hasMyDog: false), [.largeDog])
    }

    // MARK: - 一致

    func test_店名の部分一致で見つかる() {
        let cafes = [makeCafe(name: "ブルーボトルコーヒー 渋谷"), makeCafe(name: "ドッグカフェ ハチ"), makeCafe(name: "Cafe Blue")]
        XCTAssertEqual(CafeNameSearch.results(query: "ぶるー", in: cafes).map(\.name), ["ブルーボトルコーヒー 渋谷"])
        XCTAssertEqual(CafeNameSearch.results(query: "ＢＬＵＥ", in: cafes).map(\.name), ["Cafe Blue"])
        // 「カフェ」と「cafe」を同じに扱うようになったので、「ドッグカフェ ハチ」にも当たる（前方一致の Cafe Blue が先）
        XCTAssertEqual(CafeNameSearch.results(query: "ＣＡＦＥ", in: cafes).map(\.name), ["Cafe Blue", "ドッグカフェ ハチ"])
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

    // MARK: - 店名の読み（nameReading）

    func test_読みで前方一致する() {
        let cafes = [makeCafe(name: "GOLIATH", reading: "ゴリアテ"), makeCafe(name: "IVY PLACE", reading: "アイビー プレイス")]
        XCTAssertEqual(CafeNameSearch.groupedResults(query: "ゴリ", in: cafes).prefix.map(\.name), ["GOLIATH"])
        XCTAssertEqual(CafeNameSearch.groupedResults(query: "アイビープレイス", in: cafes).prefix.map(\.name), ["IVY PLACE"])
    }

    func test_読みで途中一致する() {
        let cafes = [makeCafe(name: "FUGLEN ASAKUSA", reading: "フグレン アサクサ")]
        let grouped = CafeNameSearch.groupedResults(query: "アサクサ", in: cafes)
        XCTAssertTrue(grouped.prefix.isEmpty)
        XCTAssertEqual(grouped.other.map(\.name), ["FUGLEN ASAKUSA"])
    }

    func test_ひらがなの入力でも読みに当たる() {
        let cafes = [makeCafe(name: "GOLIATH", reading: "ゴリアテ")]
        XCTAssertEqual(CafeNameSearch.results(query: "ごりあて", in: cafes).map(\.name), ["GOLIATH"])
        XCTAssertEqual(CafeNameSearch.results(query: "りあ", in: cafes).map(\.name), ["GOLIATH"])
    }

    func test_読みが無い店は従来どおり店名だけで照合する() {
        let cafes = [makeCafe(name: "GOLIATH"), makeCafe(name: "ゴリラ珈琲")]
        // 読みの無い英字の店は、かなの入力では当たらない（推測で読みを当てない）
        XCTAssertEqual(CafeNameSearch.results(query: "ゴリ", in: cafes).map(\.name), ["ゴリラ珈琲"])
        XCTAssertEqual(CafeNameSearch.results(query: "goli", in: cafes).map(\.name), ["GOLIATH"])
    }

    func test_店名と読みの両方に当たっても重複しない() {
        let cafes = [makeCafe(name: "ゴリアテ GOLIATH", reading: "ゴリアテ")]
        let grouped = CafeNameSearch.groupedResults(query: "ゴリ", in: cafes)
        XCTAssertEqual(grouped.prefix.count, 1)
        XCTAssertTrue(grouped.other.isEmpty)
        XCTAssertEqual(CafeNameSearch.results(query: "ア", in: cafes).count, 1)
    }

    func test_店名で途中一致でも読みで前方一致なら前方一致のグループになる() {
        let cafes = [makeCafe(name: "Cafe GOLIATH", reading: "ゴリアテ"), makeCafe(name: "ゴリ ゴリ")]
        let grouped = CafeNameSearch.groupedResults(query: "ごりあ", in: cafes)
        XCTAssertEqual(grouped.prefix.map(\.name), ["Cafe GOLIATH"])
    }

    func test_閉店の店は読みで当たっても出さない() {
        let cafes = [makeCafe(name: "GOLIATH", isClosed: true, reading: "ゴリアテ")]
        XCTAssertTrue(CafeNameSearch.results(query: "ゴリアテ", in: cafes).isEmpty)
    }

    func test_JSONの読みはキーがあれば読み込みキーが無い_nullなら_nil() throws {
        let base = """
        {"id":"%@","name":"GOLIATH","latitude":35.68,"longitude":139.76,"is_closed":false,"area":"tokyo",
         "dog_policy_status":"allowed","has_conflict":false%@}
        """
        func decode(_ extra: String) throws -> Cafe {
            let json = String(format: base, UUID().uuidString, extra)
            return try JSONDecoder().decode(Cafe.self, from: Data(json.utf8))
        }
        XCTAssertEqual(try decode(#","name_reading":"ゴリアテ""#).nameReading, "ゴリアテ")
        XCTAssertNil(try decode("").nameReading)
        XCTAssertNil(try decode(#","name_reading":null"#).nameReading)
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

    func test_古い保存データ_店のid項目なし_もそのまま読める() throws {
        let legacy = Data(#"[{"name":"渋谷","latitude":35.658,"longitude":139.7016},{"name":"新宿","latitude":35.6896,"longitude":139.7006}]"#.utf8)
        let list = RecentSearchLogic.decode(legacy)
        XCTAssertEqual(list.map(\.name), ["渋谷", "新宿"])
        XCTAssertEqual(list.map(\.cafeID), [nil, nil])
        XCTAssertEqual(list.first?.origin, .searched(name: "渋谷", latitude: 35.658, longitude: 139.7016))
    }

    func test_見たお店は店のidを持って往復できる() {
        let id = UUID()
        let shop = RecentSearch(name: "ブルーボトル", latitude: 35.0, longitude: 139.0, cafeID: id)
        let list = [shop, entry("渋谷")]
        let restored = RecentSearchLogic.decode(RecentSearchLogic.encode(list))
        XCTAssertEqual(restored, list)
        XCTAssertEqual(restored.first?.cafeID, id)
        XCTAssertNil(restored.last?.cafeID)
    }

    func test_同じ名前の店と場所は互いを消さず_同じ店は重複しない() {
        let id = UUID()
        let shop = RecentSearch(name: "渋谷", latitude: 35.0, longitude: 139.0, cafeID: id)
        let both = RecentSearchLogic.adding(shop, to: [entry("渋谷")])
        XCTAssertEqual(both.count, 2)
        XCTAssertEqual(Set(both.map(\.id)).count, 2)

        let again = RecentSearchLogic.adding(shop, to: [entry("新宿"), shop])
        XCTAssertEqual(again.map(\.name), ["渋谷", "新宿"])
    }

    func test_上限は場所と見たお店を合わせて5件() {
        var list: [RecentSearch] = []
        for index in 0..<4 {
            list = RecentSearchLogic.adding(entry("場所\(index)"), to: list)
            list = RecentSearchLogic.adding(RecentSearch(name: "店\(index)", latitude: 35.0, longitude: 139.0, cafeID: UUID()), to: list)
        }
        XCTAssertEqual(RecentSearchLogic.limit, 5)
        XCTAssertEqual(list.count, 5)
        XCTAssertEqual(list.map(\.name), ["店3", "場所3", "店2", "場所2", "店1"])
    }

    func test_1件消す() {
        let shop = RecentSearch(name: "店", latitude: 35.0, longitude: 139.0, cafeID: UUID())
        let list = [entry("渋谷"), shop, entry("新宿")]
        XCTAssertEqual(RecentSearchLogic.removing(shop, from: list).map(\.name), ["渋谷", "新宿"])
        XCTAssertEqual(RecentSearchLogic.removing(entry("渋谷"), from: list).map(\.name), ["店", "新宿"])
    }

    @MainActor
    func test_ストアは見たお店を残して消せる() {
        let suiteName = "RecentSearchStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        let cafe = makeCafe(name: "ブルーボトル", latitude: 35.66, longitude: 139.70)
        let store = RecentSearchStore(defaults: defaults)
        store.add(name: "渋谷", latitude: 35.658, longitude: 139.7016)
        store.addViewedCafe(cafe)
        XCTAssertEqual(store.entries.map(\.name), ["ブルーボトル", "渋谷"])
        XCTAssertEqual(store.entries.first?.cafeID, cafe.id)

        // 保存するのは名前・座標・店のidだけ（再起動後も復元する）
        let restored = RecentSearchStore(defaults: defaults)
        XCTAssertEqual(restored.entries, store.entries)
        XCTAssertEqual(restored.entries.first?.latitude, 35.66)

        restored.remove(restored.entries[0])
        XCTAssertEqual(restored.entries.map(\.name), ["渋谷"])
        XCTAssertEqual(RecentSearchStore(defaults: defaults).entries.map(\.name), ["渋谷"])

        restored.removeAll()
        XCTAssertTrue(restored.entries.isEmpty)
        XCTAssertTrue(RecentSearchStore(defaults: defaults).entries.isEmpty)
    }

    @MainActor
    func test_データから消えた見たお店だけを消し_場所の検索は残す() {
        let suiteName = "RecentSearchStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        let kept = makeCafe(name: "残る店", latitude: 35.66, longitude: 139.70)
        let gone = makeCafe(name: "閉店した店", latitude: 35.67, longitude: 139.71)
        let store = RecentSearchStore(defaults: defaults)
        store.add(name: "渋谷", latitude: 35.658, longitude: 139.7016)
        store.addViewedCafe(kept)
        store.addViewedCafe(gone)
        store.removeCafes(notIn: [kept.id])
        XCTAssertEqual(store.entries.map(\.name), ["残る店", "渋谷"])
        XCTAssertEqual(RecentSearchStore(defaults: defaults).entries.map(\.name), ["残る店", "渋谷"])
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
