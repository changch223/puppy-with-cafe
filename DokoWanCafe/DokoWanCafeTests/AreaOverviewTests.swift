import XCTest
@testable import DokoWanCafe

/// エリア表示（東京全体が見えるほど引いたときのエリア名＋件数）の集計と切り替え判定のユニットテスト（憲章 原則IV）
final class AreaOverviewTests: XCTestCase {
    private func makeItem(_ name: String = "店", area: String?, lat: Double, lng: Double) -> CafeWithDistance {
        var cafe = Cafe(
            id: UUID(), placeID: nil, name: name, latitude: lat, longitude: lng,
            address: nil, contact: nil, dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil, hasConflict: false, isClosed: false, area: "tokyo"
        )
        cafe.subArea = area
        return CafeWithDistance(cafe: cafe, distanceMeters: 100)
    }

    // MARK: - 切り替え（ヒステリシス）

    func test_入る幅と戻る幅には余裕がある() {
        XCTAssertGreaterThan(AreaOverview.enterLatitudeDelta, AreaOverview.exitLatitudeDelta)
    }

    func test_ピン表示からは入る幅以上でエリア表示になる() {
        XCTAssertFalse(AreaOverview.isOverview(latitudeDelta: AreaOverview.enterLatitudeDelta - 0.001, wasOverview: false))
        XCTAssertTrue(AreaOverview.isOverview(latitudeDelta: AreaOverview.enterLatitudeDelta, wasOverview: false))
    }

    func test_エリア表示からは戻る幅を下回るまで続く() {
        let between = (AreaOverview.enterLatitudeDelta + AreaOverview.exitLatitudeDelta) / 2
        XCTAssertTrue(AreaOverview.isOverview(latitudeDelta: between, wasOverview: true))
        XCTAssertFalse(AreaOverview.isOverview(latitudeDelta: between, wasOverview: false))
        XCTAssertFalse(AreaOverview.isOverview(latitudeDelta: AreaOverview.exitLatitudeDelta - 0.001, wasOverview: true))
    }

    func test_幅が不正なら今の表示のまま() {
        XCTAssertTrue(AreaOverview.isOverview(latitudeDelta: .nan, wasOverview: true))
        XCTAssertFalse(AreaOverview.isOverview(latitudeDelta: .infinity, wasOverview: false))
    }

    // MARK: - 集計

    func test_エリアごとに件数を数える() {
        let items = [
            makeItem(area: "渋谷", lat: 35.66, lng: 139.70), makeItem(area: "渋谷", lat: 35.67, lng: 139.71),
            makeItem(area: "原宿", lat: 35.69, lng: 139.70),
        ]
        let summaries = AreaOverview.summaries(for: items)
        XCTAssertEqual(summaries.map(\.name), ["渋谷", "原宿"])
        XCTAssertEqual(summaries.map(\.count), [2, 1])
    }

    func test_件数が同じなら名前順() {
        let items = [makeItem(area: "原宿", lat: 35.69, lng: 139.70), makeItem(area: "渋谷", lat: 35.66, lng: 139.70)]
        XCTAssertEqual(AreaOverview.summaries(for: items).map(\.name), ["原宿", "渋谷"].sorted())
    }

    func test_エリア名がない店と座標が不正な店は数えない() {
        let items = [
            makeItem(area: nil, lat: 35.66, lng: 139.70), makeItem(area: "  ", lat: 35.66, lng: 139.70),
            makeItem(area: "渋谷", lat: .nan, lng: 139.70), makeItem(area: "渋谷", lat: 35.66, lng: 139.70),
        ]
        let summaries = AreaOverview.summaries(for: items)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].count, 1)
    }

    func test_表示結果が空なら何も出さない() {
        XCTAssertTrue(AreaOverview.summaries(for: []).isEmpty)
    }

    func test_中心は座標の中央値で外れ値に引っぱられない() {
        let items = [
            makeItem(area: "渋谷", lat: 35.660, lng: 139.700),
            makeItem(area: "渋谷", lat: 35.662, lng: 139.702),
            makeItem(area: "渋谷", lat: 35.664, lng: 139.704),
            makeItem(area: "渋谷", lat: 35.800, lng: 139.900), // 外れ値
        ]
        let summary = AreaOverview.summaries(for: items)[0]
        // 偶数件は真ん中2つの平均。平均値なら 35.6965 になるところ
        XCTAssertEqual(summary.centerLatitude, 35.663, accuracy: 1e-9)
        XCTAssertEqual(summary.centerLongitude, 139.703, accuracy: 1e-9)
    }

    func test_収まる範囲は店の最小最大() {
        let items = [makeItem(area: "渋谷", lat: 35.66, lng: 139.70), makeItem(area: "渋谷", lat: 35.68, lng: 139.72)]
        let summary = AreaOverview.summaries(for: items)[0]
        XCTAssertEqual(summary.minLatitude, 35.66)
        XCTAssertEqual(summary.maxLatitude, 35.68)
        XCTAssertEqual(summary.minLongitude, 139.70)
        XCTAssertEqual(summary.maxLongitude, 139.72)
    }

    // MARK: - 寄せる範囲

    func test_寄せる範囲は店が収まる余白つき() {
        let items = [makeItem(area: "渋谷", lat: 35.66, lng: 139.70), makeItem(area: "渋谷", lat: 35.68, lng: 139.72)]
        let fit = AreaOverview.fitRegion(for: AreaOverview.summaries(for: items)[0])
        XCTAssertEqual(fit.centerLatitude, 35.67, accuracy: 1e-9)
        XCTAssertEqual(fit.centerLongitude, 139.71, accuracy: 1e-9)
        XCTAssertEqual(fit.latitudeDelta, 0.02 * AreaOverview.fitPaddingFactor, accuracy: 1e-9)
        XCTAssertEqual(fit.longitudeDelta, 0.02 * AreaOverview.fitPaddingFactor, accuracy: 1e-9)
    }

    func test_1店のエリアでも寄りすぎない() {
        let fit = AreaOverview.fitRegion(for: AreaOverview.summaries(for: [makeItem(area: "目白", lat: 35.72, lng: 139.71)])[0])
        XCTAssertEqual(fit.latitudeDelta, AreaOverview.fitMinDelta)
        XCTAssertEqual(fit.longitudeDelta, AreaOverview.fitMinDelta)
    }

    func test_広がったエリアでもピン表示に戻る幅に収める() {
        let items = [makeItem(area: "町田", lat: 35.4, lng: 139.2), makeItem(area: "町田", lat: 35.9, lng: 139.9)]
        let fit = AreaOverview.fitRegion(for: AreaOverview.summaries(for: items)[0])
        XCTAssertEqual(fit.latitudeDelta, AreaOverview.fitMaxLatitudeDelta)
        XCTAssertEqual(fit.longitudeDelta, AreaOverview.fitMaxLongitudeDelta)
        XCTAssertLessThan(fit.latitudeDelta, AreaOverview.exitLatitudeDelta)
    }

    // MARK: - 間引きの優先度

    func test_件数が多いほど優先度が高い() {
        XCTAssertEqual(AreaOverview.priority(count: 42, maxCount: 42), 1)
        XCTAssertGreaterThan(AreaOverview.priority(count: 30, maxCount: 42), AreaOverview.priority(count: 5, maxCount: 42))
        XCTAssertEqual(AreaOverview.priority(count: 5, maxCount: 0), 0)
    }

    // MARK: - 札の重なり

    private func box(_ id: String, count: Int, x: Double, y: Double, width: Double = 80, height: Double = 34) -> AreaOverview.LabelBox {
        AreaOverview.LabelBox(id: id, count: count, centerX: x, centerY: y, width: width, height: height)
    }

    func test_重なる札は件数の多い方だけ出す() {
        let ids = AreaOverview.nonOverlappingLabelIDs([
            box("少ない", count: 10, x: 100, y: 100), box("多い", count: 50, x: 120, y: 110),
        ])
        XCTAssertEqual(ids, ["多い"])
    }

    func test_離れた札は両方出す() {
        let ids = AreaOverview.nonOverlappingLabelIDs([
            box("左", count: 10, x: 100, y: 100), box("右", count: 50, x: 100 + 80 + AreaOverview.labelGap, y: 100),
            box("下", count: 5, x: 100, y: 100 + 34 + AreaOverview.labelGap),
        ])
        XCTAssertEqual(ids, ["左", "右", "下"])
    }

    func test_すき間より近い札は重なり扱い() {
        let ids = AreaOverview.nonOverlappingLabelIDs([
            box("左", count: 10, x: 100, y: 100), box("右", count: 50, x: 100 + 80 + AreaOverview.labelGap - 1, y: 100),
        ])
        XCTAssertEqual(ids, ["右"])
    }

    func test_隠れた札には邪魔されない() {
        // 中は大に隠れる。小は中とだけ重なるので、出せる
        let ids = AreaOverview.nonOverlappingLabelIDs([
            box("大", count: 100, x: 100, y: 100), box("中", count: 50, x: 170, y: 100), box("小", count: 10, x: 240, y: 100),
        ])
        XCTAssertEqual(ids, ["大", "小"])
    }

    func test_件数が同じなら名前順で決める_位置が不正な札は出さない() {
        let ids = AreaOverview.nonOverlappingLabelIDs([
            box("い", count: 10, x: 100, y: 100), box("あ", count: 10, x: 110, y: 100), box("不正", count: 99, x: .nan, y: 0),
        ])
        XCTAssertEqual(ids, ["あ"])
    }
}
