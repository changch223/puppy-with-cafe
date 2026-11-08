import MapKit
import XCTest
@testable import DokoWanCafe

/// 同じ場所（5m 以内）の店をまとめる純ロジックと、組のピン・ラベルのユニットテスト（憲章 原則IV）。
final class SameSpotGroupingTests: XCTestCase {
    private let baseLatitude = 35.65697
    private let baseLongitude = 139.79311
    /// 緯度1度あたりのメートル（DistanceCalculator の球面モデルに合わせる）
    private let metersPerDegreeLatitude = 6_371_000.0 * .pi / 180

    /// 基準点から北へ `northMeters` ずらした位置の店を作る
    private func makeItem(
        name: String,
        northMeters: Double = 0,
        distanceMeters: Double = 100,
        status: DogPolicyStatus = .allowed,
        amenities: DogAmenities? = nil,
        hours: OpeningHours? = nil
    ) -> CafeWithDistance {
        CafeWithDistance(
            cafe: Cafe(
                id: UUID(), placeID: nil, name: name,
                latitude: baseLatitude + northMeters / metersPerDegreeLatitude, longitude: baseLongitude,
                address: nil, contact: nil,
                dogPolicyStatus: status, dogPolicyCondition: nil,
                lastVerified: nil, representativeSourceID: nil,
                hasConflict: false, isClosed: false, area: "tokyo",
                hours: hours, dogAmenities: amenities
            ),
            distanceMeters: distanceMeters
        )
    }

    private func groups(_ items: [CafeWithDistance], favorites: Set<UUID> = [], at date: Date = Date()) -> [[CafeWithDistance]] {
        SameSpotGrouping.groups(for: items, favoriteIDs: favorites, at: date)
    }

    /// 2026-07-06 は月曜
    private func mondayNoon() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 12))!
    }

    // MARK: - まとめ方

    func test_座標が同じ3店は1組3店() {
        let items = [makeItem(name: "食堂101"), makeItem(name: "ANEA CAFE Toyosu"), makeItem(name: "ピッツェリア ダ ボッカ")]
        let result = groups(items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].count, 3)
    }

    func test_4_8mは同じ組_6mは別の組() {
        let near = groups([makeItem(name: "A"), makeItem(name: "B", northMeters: 4.8)])
        XCTAssertEqual(near.count, 1)
        let far = groups([makeItem(name: "A"), makeItem(name: "B", northMeters: 6)])
        XCTAssertEqual(far.count, 2)
        XCTAssertTrue(far.allSatisfy { $0.count == 1 })
    }

    func test_連結しているなら端どうしが8m離れていても1組() {
        let result = groups([
            makeItem(name: "A"),
            makeItem(name: "B", northMeters: 4),
            makeItem(name: "C", northMeters: 8),
        ])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].count, 3)
    }

    func test_格子の境目をまたぐ近い店も同じ組() {
        // 5m 格子のどこかの境目をまたぐように、0.2m 刻みでずらしても必ず 4.8m 以内は同じ組になる
        for step in 0..<50 {
            let offset = Double(step) * 0.2
            let result = groups([makeItem(name: "A", northMeters: offset), makeItem(name: "B", northMeters: offset + 4.8)])
            XCTAssertEqual(result.count, 1, "offset \(offset)")
        }
    }

    func test_空配列は空() {
        XCTAssertTrue(groups([]).isEmpty)
    }

    func test_単独の店は要素1つの組() {
        let result = groups([makeItem(name: "A"), makeItem(name: "B", northMeters: 100)])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.count == 1 })
    }

    func test_組の数と店の総数は入力と一致し漏れも重複もない() {
        var items: [CafeWithDistance] = []
        for index in 0..<120 {
            // 10m 間隔の列の途中に、同じ座標の店を混ぜる
            items.append(makeItem(name: "店\(index)", northMeters: Double(index / 2) * 10, distanceMeters: Double(index)))
        }
        let result = groups(items)
        XCTAssertEqual(result.count, 60, "同じ座標の2店ずつが60組")
        XCTAssertEqual(result.flatMap { $0 }.count, items.count)
        XCTAssertEqual(Set(result.flatMap { $0 }.map(\.cafe.id)), Set(items.map(\.cafe.id)))
    }

    func test_組同士は代表の距離順() {
        let result = groups([
            makeItem(name: "遠い", northMeters: 100, distanceMeters: 500),
            makeItem(name: "近い", northMeters: 200, distanceMeters: 50),
            makeItem(name: "中", northMeters: 300, distanceMeters: 200),
        ])
        XCTAssertEqual(result.map { $0[0].cafe.name }, ["近い", "中", "遠い"])
    }

    // MARK: - 代表の並び

    func test_代表の並びは行きたい_営業中_可否の分類_店名の順() {
        let open = OpeningHours(mon: [TimeRange(open: "09:00", close: "19:00")], tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
        let closed = OpeningHours(mon: [TimeRange(open: "13:00", close: "19:00")], tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
        let indoor = DogAmenities(indoor: true)
        let terrace = DogAmenities(terrace: true)

        let favorite = makeItem(name: "ん行きたい（時間外・条件を確認）", hours: closed)
        let openTerrace = makeItem(name: "あ営業中テラス", amenities: terrace, hours: open)
        let closedIndoor = makeItem(name: "あ時間外店内", amenities: indoor, hours: closed)
        let openIndoorB = makeItem(name: "い営業中店内", amenities: indoor, hours: open)
        let openIndoorA = makeItem(name: "あ営業中店内", amenities: indoor, hours: open)

        let all = [closedIndoor, openIndoorB, openTerrace, favorite, openIndoorA]
        let result = groups(all, favorites: [favorite.cafe.id], at: mondayNoon())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(
            result[0].map(\.cafe.name),
            ["ん行きたい（時間外・条件を確認）", "あ営業中店内", "い営業中店内", "あ営業中テラス", "あ時間外店内"]
        )
    }

    func test_行きたいがなければ営業中の店が代表() {
        let open = OpeningHours(mon: [TimeRange(open: "09:00", close: "19:00")], tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
        let closed = OpeningHours(mon: [TimeRange(open: "13:00", close: "19:00")], tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
        let result = groups(
            [makeItem(name: "A時間外", hours: closed), makeItem(name: "B営業中", hours: open)],
            at: mondayNoon()
        )
        XCTAssertEqual(result[0].first?.cafe.name, "B営業中")
    }

    func test_並びは入力の順に依らず決まる() {
        let items = (0..<6).map { _ in makeItem(name: "同名") }
        let forward = groups(items)[0].map(\.cafe.id)
        let backward = groups(items.reversed())[0].map(\.cafe.id)
        XCTAssertEqual(forward, backward, "名前まで同じなら id で決める")
    }

    // MARK: - 補助

    func test_指定した店の入っている組を返す() {
        let a = makeItem(name: "A")
        let b = makeItem(name: "B")
        let c = makeItem(name: "C", northMeters: 100)
        let result = groups([a, b, c])
        XCTAssertEqual(Set(SameSpotGrouping.group(containing: b.cafe.id, in: result)?.map(\.cafe.id) ?? []), [a.cafe.id, b.cafe.id])
        XCTAssertEqual(SameSpotGrouping.group(containing: c.cafe.id, in: result)?.count, 1)
        XCTAssertNil(SameSpotGrouping.group(containing: UUID(), in: result))
    }

    func test_座標が非有限や範囲外の店は落ちずに単独の組になる() {
        let a = makeItem(name: "A")
        let b = makeItem(name: "B")
        func broken(_ name: String, latitude: Double, longitude: Double) -> CafeWithDistance {
            let base = makeItem(name: name)
            return CafeWithDistance(cafe: Cafe(
                id: base.cafe.id, placeID: nil, name: name, latitude: latitude, longitude: longitude,
                address: nil, contact: nil, dogPolicyStatus: .allowed, dogPolicyCondition: nil,
                lastVerified: nil, representativeSourceID: nil, hasConflict: false, isClosed: false, area: "tokyo",
                hours: nil, dogAmenities: nil
            ), distanceMeters: 100)
        }
        let nan = broken("NaN", latitude: .nan, longitude: baseLongitude)
        let infinite = broken("Inf", latitude: baseLatitude, longitude: .infinity)
        let outOfRange = broken("範囲外", latitude: 120, longitude: baseLongitude)
        let outOfRangeTwin = broken("範囲外2", latitude: 120, longitude: baseLongitude)
        let result = groups([a, nan, b, infinite, outOfRange, outOfRangeTwin])
        XCTAssertEqual(result.map(\.count).reduce(0, +), 6, "店の漏れも重複もない")
        XCTAssertEqual(SameSpotGrouping.group(containing: a.cafe.id, in: result)?.count, 2, "正常な店どうしはまとまる")
        for item in [nan, infinite, outOfRange, outOfRangeTwin] {
            XCTAssertEqual(SameSpotGrouping.group(containing: item.cafe.id, in: result)?.count, 1, "\(item.cafe.name) は単独")
        }
    }

    func test_カード用の組は全件で求めた組と同じ並び() {
        let a = makeItem(name: "A")
        let b = makeItem(name: "B", northMeters: 4)
        let c = makeItem(name: "C", northMeters: 8)
        let far = makeItem(name: "遠い", northMeters: 500)
        let items = [far, c, a, b]
        let full = SameSpotGrouping.group(containing: c.cafe.id, in: groups(items))
        let card = SameSpotGrouping.group(of: c, in: items, favoriteIDs: [], at: Date())
        XCTAssertEqual(card?.map(\.cafe.id), full?.map(\.cafe.id))
        XCTAssertEqual(card?.count, 3)
        XCTAssertNil(SameSpotGrouping.group(of: makeItem(name: "載っていない"), in: items, favoriteIDs: [], at: Date()))
    }

    // MARK: - 地図側（組のラベル・優先度・バッジ）

    func test_組の店名ラベルは_ほかN店() {
        let group = [makeItem(name: "食堂101"), makeItem(name: "ANEA CAFE Toyosu"), makeItem(name: "ピッツェリア ダ ボッカ")]
        XCTAssertEqual(MapViewModel.nameLabel(for: group), "食堂101 ほか2店")
        XCTAssertEqual(MapViewModel.nameLabel(for: [group[0]]), "食堂101")
    }

    func test_組の読み上げ文は代表の文のあとにほかの店を続ける() {
        let group = [makeItem(name: "食堂101"), makeItem(name: "ANEA CAFE Toyosu"), makeItem(name: "ピッツェリア ダ ボッカ")]
        XCTAssertEqual(
            MapViewModel.spokenLabel(for: group, representative: "食堂101、店内OK"),
            "食堂101、店内OK。同じ場所にほか2店: ANEA CAFE Toyosu、ピッツェリア ダ ボッカ"
        )
        XCTAssertEqual(MapViewModel.spokenLabel(for: [group[0]], representative: "食堂101、店内OK"), "食堂101、店内OK")
    }

    func test_組の表示優先度は組の中でいちばん高い値() {
        let near = makeItem(name: "近い")
        let far = makeItem(name: "遠い")
        let priorities: [UUID: MKFeatureDisplayPriority] = [near.cafe.id: .required, far.cafe.id: .defaultLow]
        XCTAssertEqual(MapViewModel.displayPriority(for: [far, near], priorities: priorities), .required)
        XCTAssertEqual(MapViewModel.displayPriority(for: [far], priorities: priorities), .defaultLow)
    }

    func test_バッジの数字は9まで_10以上は9プラス() {
        XCTAssertEqual(MapPinRenderer.badgeText(count: 2), "2")
        XCTAssertEqual(MapPinRenderer.badgeText(count: 9), "9")
        XCTAssertEqual(MapPinRenderer.badgeText(count: 10), "9+")
        XCTAssertEqual(MapPinRenderer.badgeText(count: 25), "9+")
    }

    func test_バッジ付きのピン画像は別にキャッシュされ_1店はバッジなしと同じ画像() {
        let style = MapPinStyle(category: .indoorOK, isFavorite: false, isDimmed: false)
        let plain = MapPinRenderer.image(for: style)
        XCTAssertTrue(plain === MapPinRenderer.image(for: style, count: 1))
        let badged = MapPinRenderer.image(for: style, count: 3)
        XCTAssertFalse(plain === badged)
        XCTAssertTrue(badged === MapPinRenderer.image(for: style, count: 3))
        XCTAssertTrue(MapPinRenderer.image(for: style, count: 10) === MapPinRenderer.image(for: style, count: 40), "10以上は同じ「9+」")
        XCTAssertGreaterThan(badged.size.width, plain.size.width, "バッジのぶん余白が広い")
        let selectedBadged = MapPinRenderer.image(for: style, isSelected: true, count: 3)
        XCTAssertGreaterThan(selectedBadged.size.width, badged.size.width, "選択中の拡大にもバッジが付く")
    }

    func test_バッジ付きのしずくピンもピンの先端が座標に合う() {
        let drop = MapPinStyle(category: .checkDetail, isFavorite: false, isDimmed: false)
        let image = MapPinRenderer.image(for: drop, count: 3)
        let offset = MapPinRenderer.centerOffset(for: drop, image: image, count: 3)
        XCTAssertLessThan(offset.y, 0)
        // バッジなしより余白が広いので、画像の中心から先端までの距離は変わらない
        let plainImage = MapPinRenderer.image(for: drop)
        let plainOffset = MapPinRenderer.centerOffset(for: drop, image: plainImage)
        XCTAssertEqual(offset.y, plainOffset.y, accuracy: 0.001)
    }

    func test_カードの高さは同じ場所の列のぶん高くなる() {
        let base = CafeSheetDetent.cardHeight(containerHeight: 800)
        XCTAssertEqual(base, 320)
        XCTAssertEqual(CafeSheetDetent.cardHeight(containerHeight: 800, hasSameSpotRow: true), base + CafeSheetDetent.sameSpotRowHeight)
        XCTAssertLessThanOrEqual(CafeSheetDetent.cardHeight(containerHeight: 300, hasSameSpotRow: true), 300 * 0.8)
    }
}
