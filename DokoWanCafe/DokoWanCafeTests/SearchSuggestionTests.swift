import CoreLocation
import XCTest
@testable import DokoWanCafe

/// 入力中の候補（条件・エリア・組み合わせ・お店の並び・お店の行の2行目）の純ロジックのユニットテスト
final class SearchSuggestionTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func makeCafe(
        name: String = "店", subArea: String? = nil,
        latitude: Double = 35.68, longitude: Double = 139.76,
        status: DogPolicyStatus = .allowed, isClosed: Bool = false,
        hours: OpeningHours? = nil, address: String? = nil
    ) -> Cafe {
        var cafe = Cafe(
            id: UUID(), placeID: nil, name: name,
            latitude: latitude, longitude: longitude,
            address: address, contact: nil,
            dogPolicyStatus: status, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: isClosed, area: "tokyo"
        )
        cafe.subArea = subArea
        cafe.hours = hours
        return cafe
    }

    /// 2026-07-06 は月曜日
    private func tokyoDate(day: Int = 6, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = tokyo
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        return calendar.date(from: components)!
    }

    private func area(_ name: String, count: Int, latitude: Double = 35.68, longitude: Double = 139.76) -> SearchArea {
        SearchArea(name: name, latitude: latitude, longitude: longitude, count: count)
    }

    // MARK: - 条件の辞書

    func test_条件の言葉と言い換えが当たる() {
        XCTAssertEqual(SearchSuggestion.conditions(for: "テラス", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "terrace", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "外席", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "屋外", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "店内", hasMyDog: false), [.indoor])
        XCTAssertEqual(SearchSuggestion.conditions(for: "室内", hasMyDog: false), [.indoor])
        XCTAssertEqual(SearchSuggestion.conditions(for: "indoor", hasMyDog: false), [.indoor])
        XCTAssertEqual(SearchSuggestion.conditions(for: "大型犬", hasMyDog: false), [.largeDog])
        XCTAssertEqual(SearchSuggestion.conditions(for: "大きい犬", hasMyDog: false), [.largeDog])
        XCTAssertEqual(SearchSuggestion.conditions(for: "large", hasMyDog: false), [.largeDog])
        XCTAssertEqual(SearchSuggestion.conditions(for: "犬メニュー", hasMyDog: false), [.dogMenu])
        XCTAssertEqual(SearchSuggestion.conditions(for: "ドッグメニュー", hasMyDog: false), [.dogMenu])
        XCTAssertEqual(SearchSuggestion.conditions(for: "犬用メニュー", hasMyDog: false), [.dogMenu])
        XCTAssertEqual(SearchSuggestion.conditions(for: "営業中", hasMyDog: false), [.openNow])
        XCTAssertEqual(SearchSuggestion.conditions(for: "今開いてる", hasMyDog: false), [.openNow])
        XCTAssertEqual(SearchSuggestion.conditions(for: "open", hasMyDog: false), [.openNow])
    }

    func test_雨は1文字でも店内に当たる() {
        // 「雨」はその1文字のとき、「雨の日」は辞書の言葉として当たる
        XCTAssertEqual(SearchSuggestion.conditions(for: "雨", hasMyDog: false), [.indoor])
        XCTAssertEqual(SearchSuggestion.conditions(for: "雨の日", hasMyDog: false), [.indoor])
    }

    func test_言葉の先頭との一致は2文字以上から() {
        XCTAssertTrue(SearchSuggestion.conditions(for: "テ", hasMyDog: false).isEmpty)
        XCTAssertEqual(SearchSuggestion.conditions(for: "テラ", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "大型", hasMyDog: false), [.largeDog])
        // 英字の言葉は4文字以上から（「ope」では出さない）
        XCTAssertTrue(SearchSuggestion.conditions(for: "ope", hasMyDog: false).isEmpty)
        // 言葉の途中だけの一致は当たらない（入力が言葉を含むわけでも、先頭でもない）
        XCTAssertTrue(SearchSuggestion.conditions(for: "ラス", hasMyDog: false).isEmpty)
    }

    func test_入力を含む言葉も当たる() {
        XCTAssertEqual(SearchSuggestion.conditions(for: "テラス席", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "店内OK", hasMyDog: false), [.indoor])
    }

    func test_全角半角とひらがなを同一視する() {
        XCTAssertEqual(SearchSuggestion.conditions(for: "ＴＥＲＲＡＣＥ", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "わんこメニュー", hasMyDog: false), [.dogMenu])
        XCTAssertEqual(SearchSuggestion.conditions(for: "てらす", hasMyDog: false), [.terrace])
    }

    func test_うちの子はうちの子が設定済みのときだけ() {
        XCTAssertTrue(SearchSuggestion.conditions(for: "うちの子", hasMyDog: false).isEmpty)
        XCTAssertEqual(SearchSuggestion.conditions(for: "うちの子", hasMyDog: true), [.myDog])
    }

    func test_空の入力と関係ない語は当たらない() {
        XCTAssertTrue(SearchSuggestion.conditions(for: "", hasMyDog: true).isEmpty)
        XCTAssertTrue(SearchSuggestion.conditions(for: "  ", hasMyDog: true).isEmpty)
        XCTAssertTrue(SearchSuggestion.conditions(for: "代官山", hasMyDog: true).isEmpty)
    }

    func test_条件の文言() {
        XCTAssertEqual(SearchCondition.terrace.title(), "テラス席OKのお店に絞る")
        XCTAssertEqual(
            SearchCondition.terrace.subtitle(originName: "渋谷駅"),
            "渋谷駅の周り · 「絞り込み」の「テラス」をオンにします"
        )
        XCTAssertEqual(
            SearchCondition.indoor.subtitle(originName: "現在地"),
            "現在地の周り · 「絞り込み」の「店内OK」をオンにします"
        )
        XCTAssertEqual(SearchCondition.terrace.spokenText(), "テラス席OKのお店に絞る。地図の条件をオンにします")
    }

    func test_条件をフィルタへ反映する() {
        var amenities = AmenityFilter()
        var openNow = false
        var myDog = false
        SearchCondition.apply([.terrace, .openNow], amenities: &amenities, openNowOnly: &openNow, myDogOnly: &myDog)
        XCTAssertTrue(amenities.terraceOnly)
        XCTAssertTrue(openNow)
        XCTAssertFalse(amenities.indoorOnly)
        XCTAssertFalse(myDog)

        // すでにオンの条件は消さない
        SearchCondition.apply([.largeDog, .dogMenu, .indoor, .myDog], amenities: &amenities, openNowOnly: &openNow, myDogOnly: &myDog)
        XCTAssertEqual(amenities, AmenityFilter(indoorOnly: true, terraceOnly: true, largeDogOnly: true, dogMenuOnly: true))
        XCTAssertTrue(openNow)
        XCTAssertTrue(myDog)
    }

    // MARK: - 組み合わせ

    func test_エリアと条件の組み合わせ() {
        let index = [area("二子玉川", count: 12), area("代官山", count: 22)]
        let combo = SearchSuggestion.combo(for: "二子玉川 テラス", areas: index, hasMyDog: false)
        XCTAssertEqual(combo?.area.name, "二子玉川")
        XCTAssertEqual(combo?.conditions, [.terrace])
        XCTAssertEqual(combo?.title(), "二子玉川の周りで、テラス席OKのお店")
    }

    func test_全角の空白でも区切る() {
        let index = [area("代官山", count: 22)]
        let combo = SearchSuggestion.combo(for: "代官山　大型犬", areas: index, hasMyDog: false)
        XCTAssertEqual(combo?.area.name, "代官山")
        XCTAssertEqual(combo?.conditions, [.largeDog])
    }

    func test_語の順番が逆でも組み合わせになる() {
        let index = [area("代官山", count: 22)]
        XCTAssertEqual(SearchSuggestion.combo(for: "テラス 代官山", areas: index, hasMyDog: false)?.area.name, "代官山")
    }

    func test_条件が複数あれば全部入る() {
        let index = [area("代官山", count: 22)]
        let combo = SearchSuggestion.combo(for: "代官山 テラス 大型犬", areas: index, hasMyDog: false)
        XCTAssertEqual(combo?.conditions, [.terrace, .largeDog])
        XCTAssertEqual(combo?.title(), "代官山の周りで、テラス席OK・大型犬OKのお店")
    }

    func test_組み合わせにならない入力() {
        let index = [area("代官山", count: 22)]
        // 1語だけ
        XCTAssertNil(SearchSuggestion.combo(for: "代官山", areas: index, hasMyDog: false))
        // エリアが無い
        XCTAssertNil(SearchSuggestion.combo(for: "テラス 店内", areas: index, hasMyDog: false))
        // 条件が無い
        XCTAssertNil(SearchSuggestion.combo(for: "代官山 ブルー", areas: index, hasMyDog: false))
        // うちの子が未設定
        XCTAssertNil(SearchSuggestion.combo(for: "代官山 うちの子", areas: index, hasMyDog: false))
        XCTAssertEqual(SearchSuggestion.combo(for: "代官山 うちの子", areas: index, hasMyDog: true)?.conditions, [.myDog])
    }

    // MARK: - エリアの索引

    func test_索引の中心は掲載店の座標の中央値で_件数は閉店や未確認を数えない() {
        let cafes = [
            makeCafe(subArea: "代官山", latitude: 35.0, longitude: 139.0),
            makeCafe(subArea: "代官山", latitude: 36.0, longitude: 140.0),
            makeCafe(subArea: "代官山", latitude: 50.0, longitude: 150.0, isClosed: true),
            makeCafe(subArea: "代官山", latitude: 50.0, longitude: 150.0, status: .unverified),
            makeCafe(subArea: "代官山", latitude: 50.0, longitude: 150.0, status: .notAllowed),
        ]
        let index = SearchSuggestion.buildIndex(cafes: cafes, presets: [])
        XCTAssertEqual(index.count, 1)
        XCTAssertEqual(index[0].name, "代官山")
        XCTAssertEqual(index[0].count, 2)
        XCTAssertEqual(index[0].latitude, 35.5, accuracy: 0.0001)
        XCTAssertEqual(index[0].longitude, 139.5, accuracy: 0.0001)
    }

    func test_件数0のエリアと空のsub_areaは出さない() {
        let cafes = [
            makeCafe(subArea: "閉店だけ", isClosed: true),
            makeCafe(subArea: nil),
            makeCafe(subArea: "   "),
        ]
        let far = ManualArea(id: "far", name: "遠い所", latitude: 34.0, longitude: 135.0)
        XCTAssertTrue(SearchSuggestion.buildIndex(cafes: cafes, presets: [far]).isEmpty)
    }

    func test_近くにデータのエリアが無いプリセットはプリセットの座標と半径の件数で残す() {
        let preset = ManualArea(id: "shibuya", name: "渋谷", latitude: 35.6580, longitude: 139.7016)
        let cafes = [
            makeCafe(subArea: "代官山", latitude: 35.6800, longitude: 139.7016),  // 約2.4km 北
            makeCafe(latitude: 35.6585, longitude: 139.7020),                      // sub_area なし・プリセットの半径内
        ]
        let index = SearchSuggestion.buildIndex(cafes: cafes, presets: [preset])
        let shibuya = index.first { $0.name == "渋谷" }
        XCTAssertEqual(shibuya?.latitude, 35.6580)
        XCTAssertEqual(shibuya?.longitude, 139.7016)
        XCTAssertEqual(shibuya?.count, 1)
    }

    func test_近くにデータのエリアがあるプリセットはそのエリアの別名になり2件並ばない() {
        let preset = ManualArea(id: "shibuya", name: "渋谷", latitude: 35.6580, longitude: 139.7016)
        let cafes = [
            makeCafe(subArea: "渋谷駅周辺", latitude: 35.6590, longitude: 139.7020),
            makeCafe(subArea: "渋谷駅周辺", latitude: 35.6595, longitude: 139.7025),
        ]
        let index = SearchSuggestion.buildIndex(cafes: cafes, presets: [preset])
        XCTAssertEqual(index.map(\.name), ["渋谷駅周辺"])
        XCTAssertEqual(SearchSuggestion.areas(matching: "渋谷", in: index).map(\.name), ["渋谷駅周辺"])
        // 別名でも当たる（「東京駅」で「丸の内・神田」のように）
        let tokyo = ManualArea(id: "tokyo", name: "東京駅周辺", latitude: 35.6812, longitude: 139.7671)
        let marunouchi = SearchSuggestion.buildIndex(
            cafes: [makeCafe(subArea: "丸の内・神田", latitude: 35.6826, longitude: 139.7665)], presets: [tokyo]
        )
        XCTAssertEqual(SearchSuggestion.areas(matching: "東京駅", in: marunouchi).map(\.name), ["丸の内・神田"])
        XCTAssertEqual(SearchSuggestion.nearbyAreas(in: marunouchi, origin: nil).map(\.name), ["丸の内・神田"])
        XCTAssertEqual(
            SearchCombo(area: marunouchi[0], conditions: [.openNow]).title(isTargetTime: true),
            "丸の内・神田の周りで、その時間に営業のお店"
        )
    }

    func test_中央値なので遠い店1軒に中心が引っ張られない() {
        let cafes = [
            makeCafe(subArea: "あきる野", latitude: 35.7290, longitude: 139.2940),
            makeCafe(subArea: "あきる野", latitude: 35.7300, longitude: 139.2950),
            makeCafe(subArea: "あきる野", latitude: 35.7800, longitude: 139.2200),
        ]
        let area = SearchSuggestion.buildIndex(cafes: cafes, presets: [])[0]
        XCTAssertEqual(area.latitude, 35.7300, accuracy: 0.00001)
        XCTAssertEqual(area.longitude, 139.2940, accuracy: 0.00001)
    }

    func test_中点でつないだエリアは部分で打っても全体の名前で1件だけ出す() {
        let cafes = [
            makeCafe(subArea: "立川・昭島", latitude: 35.6980, longitude: 139.4140, address: "東京都立川市曙町1-1"),
            makeCafe(subArea: "立川・昭島", latitude: 35.6990, longitude: 139.4150, address: "東京都立川市柴崎町2-2"),
            makeCafe(subArea: "立川・昭島", latitude: 35.7050, longitude: 139.3530, address: "東京都昭島市昭和町3-3"),
        ]
        let index = SearchSuggestion.buildIndex(cafes: cafes, presets: [])
        XCTAssertEqual(index.count, 1)
        for typing in ["昭島", "立川", "立川・"] {
            let found = SearchSuggestion.areas(matching: typing, in: index)
            XCTAssertEqual(found.map(\.name), ["立川・昭島"], typing)
            XCTAssertEqual(found.first?.count, 3, typing)
        }
    }

    func test_同じ名前のエリアがあるプリセットは_より近い別のエリアに付けない() {
        let preset = ManualArea(id: "nakameguro", name: "中目黒", latitude: 35.6440, longitude: 139.6990)
        let cafes = [
            makeCafe(subArea: "中目黒", latitude: 35.6520, longitude: 139.7050),
            makeCafe(subArea: "代官山", latitude: 35.6445, longitude: 139.6995),
        ]
        let index = SearchSuggestion.buildIndex(cafes: cafes, presets: [preset])
        XCTAssertEqual(SearchSuggestion.areas(matching: "中目黒", in: index).map(\.name), ["中目黒"])
        XCTAssertEqual(index.first { $0.name == "代官山" }?.keys, [CafeNameSearch.normalize("代官山")])
    }

    // MARK: - エリアの照合

    func test_エリアは前から一致を先に_件数の多い順() {
        let index = [
            area("渋谷駅周辺", count: 19),
            area("代官山", count: 22),
            area("代々木", count: 30),
            area("恵比寿・代官山口", count: 40),
            area("北代田", count: 50),
        ]
        // 「代」: 前から一致（「・」で区切った部分を含む）が件数の多い順。途中一致（北代田）は1文字では出さない
        XCTAssertEqual(SearchSuggestion.areas(matching: "代", in: index).map(\.name), ["恵比寿・代官山口", "代々木", "代官山"])
        XCTAssertEqual(SearchSuggestion.areas(matching: "代官", in: index).map(\.name), ["恵比寿・代官山口", "代官山"])
    }

    func test_途中一致は前から一致の後ろに出す() {
        let index = [area("表参道・青山", count: 5), area("青山一丁目", count: 1), area("北青山", count: 30)]
        // 「青山」: 前から一致（青山一丁目・表参道・青山の部分）が先、途中一致（北青山）が後
        XCTAssertEqual(
            SearchSuggestion.areas(matching: "青山", in: index).map(\.name),
            ["表参道・青山", "青山一丁目", "北青山"]
        )
    }

    func test_中黒で区切った各部分でも当たる() {
        let index = [area("表参道・青山", count: 28), area("渋谷", count: 5)]
        XCTAssertEqual(SearchSuggestion.areas(matching: "青山", in: index).map(\.name), ["表参道・青山"])
        XCTAssertEqual(SearchSuggestion.areas(matching: "表参道", in: index).map(\.name), ["表参道・青山"])
    }

    // MARK: - 見つからないときの案内

    func test_どれにも当たらないときだけ案内を出す() {
        let cafe = makeCafe(latitude: 35.68, longitude: 139.76)
        let someArea = area("渋谷", count: 3)
        XCTAssertTrue(SearchSuggestion.hasNoMatch(query: "zzz", hasCombo: false, conditions: [], areas: [], shops: []))
        // お店だけ0件（エリアや条件がある）なら案内を出さない
        XCTAssertFalse(SearchSuggestion.hasNoMatch(query: "zzz", hasCombo: false, conditions: [], areas: [someArea], shops: []))
        XCTAssertFalse(SearchSuggestion.hasNoMatch(query: "zzz", hasCombo: false, conditions: [.terrace], areas: [], shops: []))
        XCTAssertFalse(SearchSuggestion.hasNoMatch(query: "zzz", hasCombo: true, conditions: [], areas: [], shops: []))
        XCTAssertFalse(SearchSuggestion.hasNoMatch(query: "zzz", hasCombo: false, conditions: [], areas: [], shops: [cafe]))
    }

    func test_エリアの照合は正規化する() {
        let index = [area("Cafe街", count: 3), area("カフェ通り", count: 2)]
        // 「カフェ」と「cafe」を同じに扱うようになったので、全角の cafe もひらがなの「かふぇ」も両方に当たる（件数の多い順）
        XCTAssertEqual(SearchSuggestion.areas(matching: "ｃａｆｅ", in: index).map(\.name), ["Cafe街", "カフェ通り"])
        XCTAssertEqual(SearchSuggestion.areas(matching: "かふぇ", in: index).map(\.name), ["Cafe街", "カフェ通り"])
        // カフェ以外の名前は、全角半角・ひらがなカタカナの違いだけで当たる
        let others = [area("ＡＢＣ街", count: 3), area("ブルー通り", count: 2)]
        XCTAssertEqual(SearchSuggestion.areas(matching: "abc", in: others).map(\.name), ["ＡＢＣ街"])
        XCTAssertEqual(SearchSuggestion.areas(matching: "ぶるー", in: others).map(\.name), ["ブルー通り"])
    }

    func test_エリアの候補は最大5件で空の入力は何も返さない() {
        let index = (0..<10).map { area("新宿\($0)", count: $0) }
        let matches = SearchSuggestion.areas(matching: "新宿", in: index)
        XCTAssertEqual(matches.count, 5)
        XCTAssertEqual(matches.map(\.count), [9, 8, 7, 6, 5])
        XCTAssertTrue(SearchSuggestion.areas(matching: "  ", in: index).isEmpty)
    }

    // MARK: - 近くのエリア

    func test_近くのエリアは起点から近い順に8件() {
        // 経度が大きいほど遠い
        let index = (0..<10).map { area("エリア\($0)", count: 10 - $0, latitude: 35.0, longitude: 139.0 + Double($0) * 0.01) }.reversed()
        let nearby = SearchSuggestion.nearbyAreas(
            in: Array(index), origin: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)
        )
        XCTAssertEqual(nearby.map(\.name), (0..<8).map { "エリア\($0)" })
    }

    func test_起点が無いときは件数の多い順() {
        let index = [area("A", count: 1), area("B", count: 9), area("C", count: 5)]
        XCTAssertEqual(SearchSuggestion.nearbyAreas(in: index, origin: nil).map(\.name), ["B", "C", "A"])
    }

    // MARK: - お店の並び

    func test_お店は前方一致を先に_各グループで行きたい_近い順() {
        let origin = CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)
        let prefixFar = makeCafe(name: "ブルー遠い", latitude: 35.1, longitude: 139.0)
        let prefixNear = makeCafe(name: "ブルー近い", latitude: 35.01, longitude: 139.0)
        let prefixWant = makeCafe(name: "ブルー行きたい", latitude: 35.5, longitude: 139.0)
        let otherFar = makeCafe(name: "カフェブルー遠い", latitude: 35.2, longitude: 139.0)
        let otherNear = makeCafe(name: "カフェブルー近い", latitude: 35.02, longitude: 139.0)
        let otherWant = makeCafe(name: "カフェブルー行きたい", latitude: 35.6, longitude: 139.0)
        let closed = makeCafe(name: "ブルー閉店", isClosed: true)
        let all = [otherFar, prefixFar, otherWant, closed, prefixNear, otherNear, prefixWant]

        let names = SearchSuggestion.shops(
            matching: "ブルー", in: all, wantToGoIDs: [prefixWant.id, otherWant.id], origin: origin
        ).map(\.name)
        XCTAssertEqual(names, [
            "ブルー行きたい", "ブルー近い", "ブルー遠い",
            "カフェブルー行きたい", "カフェブルー近い", "カフェブルー遠い",
        ])
    }

    func test_起点が無ければ元の並びのまま() {
        let a = makeCafe(name: "ブルーA")
        let b = makeCafe(name: "ブルーB")
        XCTAssertEqual(SearchSuggestion.shops(matching: "ブルー", in: [a, b], wantToGoIDs: [], origin: nil).map(\.name), ["ブルーA", "ブルーB"])
        XCTAssertEqual(SearchSuggestion.shops(matching: "ブルー", in: [a, b], wantToGoIDs: [b.id], origin: nil).map(\.name), ["ブルーB", "ブルーA"])
    }

    func test_並べ替えのあとで最大20件() {
        // 21番目に行きたいの店がいても、並べ替えてから20件に切る
        var cafes = (0..<25).map { makeCafe(name: "カフェ\($0)") }
        let want = makeCafe(name: "カフェ行きたい")
        cafes.append(want)
        let result = SearchSuggestion.shops(matching: "カフェ", in: cafes, wantToGoIDs: [want.id], origin: nil)
        XCTAssertEqual(result.count, 20)
        XCTAssertEqual(result.first?.name, "カフェ行きたい")
    }

    func test_行きたいの店は近い順に最大3件で閉店は出さない() {
        let origin = CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)
        let cafes = (1...5).map { makeCafe(name: "店\($0)", latitude: 35.0 + Double($0) * 0.01, longitude: 139.0) }
        let closed = makeCafe(name: "閉店", latitude: 35.0001, longitude: 139.0, isClosed: true)
        let notWanted = makeCafe(name: "行きたくない", latitude: 35.0002, longitude: 139.0)
        let all = (cafes.reversed() + [closed, notWanted])
        let wanted = Set(cafes.map(\.id) + [closed.id])

        XCTAssertEqual(
            SearchSuggestion.wantToGoShops(in: all, wantToGoIDs: wanted, origin: origin).map(\.name),
            ["店1", "店2", "店3"]
        )
        XCTAssertTrue(SearchSuggestion.wantToGoShops(in: all, wantToGoIDs: [], origin: origin).isEmpty)
    }

    // MARK: - お店の行の2行目

    private var mondayHours: OpeningHours {
        OpeningHours(
            mon: [TimeRange(open: "09:00", close: "18:00")],
            tue: [], wed: nil, thu: nil, fri: nil, sat: nil, sun: nil
        )
    }

    func test_2行目はエリア_距離_営業の順() {
        let cafe = makeCafe(subArea: "代官山", latitude: 35.6600, longitude: 139.7000, hours: mondayHours)
        let origin = CLLocationCoordinate2D(latitude: 35.6600, longitude: 139.7000)
        let subtitle = SearchShopSubtitle.make(cafe: cafe, origin: origin, at: tokyoDate(hour: 10, minute: 0))
        XCTAssertEqual(subtitle.parts, ["代官山", "10 m", "営業中・18時まで"])
        XCTAssertEqual(subtitle.text, "代官山 · 10 m · 営業中・18時まで")
        XCTAssertEqual(subtitle.spokenParts, ["代官山", "10メートル", "営業中18時まで"])
    }

    func test_営業時間外と定休() {
        let cafe = makeCafe(hours: mondayHours)
        XCTAssertEqual(SearchShopSubtitle.make(cafe: cafe, origin: nil, at: tokyoDate(hour: 20, minute: 0)).parts, ["時間外"])
        // 火曜日は定休（空配列）
        XCTAssertEqual(SearchShopSubtitle.make(cafe: cafe, origin: nil, at: tokyoDate(day: 7, hour: 10, minute: 0)).parts, ["本日定休"])
    }

    func test_営業時間が分からなければ営業の状態は書かない() {
        let noHours = makeCafe(subArea: "代官山", hours: nil)
        XCTAssertEqual(SearchShopSubtitle.make(cafe: noHours, origin: nil, at: tokyoDate(hour: 10, minute: 0)).parts, ["代官山"])
        // 水曜日は未登録（nil）→ 不明
        let unknownDay = makeCafe(hours: mondayHours)
        XCTAssertTrue(SearchShopSubtitle.make(cafe: unknownDay, origin: nil, at: tokyoDate(day: 8, hour: 10, minute: 0)).parts.isEmpty)
        XCTAssertNil(SearchShopSubtitle.make(cafe: unknownDay, origin: nil, at: tokyoDate(day: 8, hour: 10, minute: 0)).text)
    }

    func test_対象時刻のときはその時刻のことだと分かる言い方にする() {
        let cafe = makeCafe(hours: mondayHours)
        let date = tokyoDate(hour: 10, minute: 0)
        let label = TargetTime.shortLabel(date)
        XCTAssertEqual(
            SearchShopSubtitle.make(cafe: cafe, origin: nil, at: date, isTargetTime: true).parts,
            ["\(label) は営業中・18時まで"]
        )
        XCTAssertEqual(
            SearchShopSubtitle.make(cafe: cafe, origin: nil, at: tokyoDate(hour: 20, minute: 0), isTargetTime: true).parts,
            ["\(TargetTime.shortLabel(tokyoDate(hour: 20, minute: 0))) は時間外"]
        )
    }

    func test_距離の読み上げ() {
        XCTAssertEqual(SearchShopSubtitle.spokenDistance(meters: 320), "320メートル")
        XCTAssertEqual(SearchShopSubtitle.spokenDistance(meters: 3_200), "3.2キロメートル")
    }

    // MARK: - 条件の誤爆を減らす決まり

    func test_1文字の言葉は入力がその1文字のときだけ() {
        XCTAssertEqual(SearchSuggestion.conditions(for: "雨", hasMyDog: false), [.indoor])
        XCTAssertTrue(SearchSuggestion.conditions(for: "彩雨珈琲店", hasMyDog: false).isEmpty)
    }

    func test_英字の言葉は4文字以上の前方一致か_空白で区切った語が同じときだけ() {
        for typing in ["la", "in", "te", "op", "lar"] {
            XCTAssertTrue(SearchSuggestion.conditions(for: typing, hasMyDog: false).isEmpty, typing)
        }
        XCTAssertEqual(SearchSuggestion.conditions(for: "terr", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "open", hasMyDog: false), [.openNow])
        XCTAssertEqual(SearchSuggestion.conditions(for: "渋谷 open", hasMyDog: false), [.openNow])
        XCTAssertTrue(SearchSuggestion.conditions(for: "opener", hasMyDog: false).isEmpty)
    }

    func test_長い言葉は半分以上打ったときに前方一致で当たる() {
        XCTAssertTrue(SearchSuggestion.conditions(for: "ドッ", hasMyDog: false).isEmpty)
        XCTAssertTrue(SearchSuggestion.conditions(for: "ドッグ", hasMyDog: false).isEmpty)
        XCTAssertTrue(SearchSuggestion.conditions(for: "わんこ", hasMyDog: false).isEmpty)
        XCTAssertEqual(SearchSuggestion.conditions(for: "ドッグメ", hasMyDog: false), [.dogMenu])
        XCTAssertEqual(SearchSuggestion.conditions(for: "テラ", hasMyDog: false), [.terrace])
        XCTAssertEqual(SearchSuggestion.conditions(for: "大型", hasMyDog: false), [.largeDog])
    }

    func test_店名そのものを打ったときは条件を出さない() {
        let names: Set<String> = [CafeNameSearch.normalize("THE OPEN BAKERY"), CafeNameSearch.normalize("カキノキテラス")]
        XCTAssertTrue(SearchSuggestion.conditions(for: "THE OPEN BAKERY", hasMyDog: false, shopNames: names).isEmpty)
        XCTAssertTrue(SearchSuggestion.conditions(for: "カキノキテラス", hasMyDog: false, shopNames: names).isEmpty)
        XCTAssertEqual(SearchSuggestion.conditions(for: "テラス", hasMyDog: false, shopNames: names), [.terrace])
    }

    func test_対象時刻があるときの営業中の行は_その時間に営業() {
        XCTAssertEqual(SearchCondition.openNow.title(isTargetTime: true), "その時間に営業のお店に絞る")
        XCTAssertEqual(
            SearchCondition.openNow.subtitle(originName: "現在地", isTargetTime: true),
            "現在地の周り · 地図の「その時間に営業」チップをオンにします"
        )
        XCTAssertEqual(SearchCondition.openNow.title(), "営業中のお店に絞る")
    }

    func test_ひらがなだけの入力は変換中とみなして見つからない案内を出さない() {
        XCTAssertFalse(SearchSuggestion.hasNoMatch(query: "しぶや", hasCombo: false, conditions: [], areas: [], shops: []))
        XCTAssertFalse(SearchSuggestion.hasNoMatch(query: "らーめん ぼーい", hasCombo: false, conditions: [], areas: [], shops: []))
        XCTAssertTrue(SearchSuggestion.hasNoMatch(query: "渋谷ぴ", hasCombo: false, conditions: [], areas: [], shops: []))
        XCTAssertTrue(SearchSuggestion.hasNoMatch(query: "シブヤ", hasCombo: false, conditions: [], areas: [], shops: []))
        XCTAssertTrue(SearchSuggestion.hasNoMatch(query: "xyz", hasCombo: false, conditions: [], areas: [], shops: []))
        XCTAssertFalse(SearchSuggestion.isLikelyComposingKana("   "))
        // ローマ字入力の途中（ひらがなの後ろに英字が数文字）も変換中とみなす
        for typing in ["しb", "しぶy", "だいk", "だいかn", "なかm", "しｂ", "ちltsu"] {
            XCTAssertTrue(SearchSuggestion.isLikelyComposingKana(typing), typing)
        }
        // 英字だけ・英字が長く続く・カタカナや漢字が混ざるものは変換中ではない
        for typed in ["s", "cafe", "しcafes", "渋谷k", "シブヤ"] {
            XCTAssertFalse(SearchSuggestion.isLikelyComposingKana(typed), typed)
        }
    }
}
