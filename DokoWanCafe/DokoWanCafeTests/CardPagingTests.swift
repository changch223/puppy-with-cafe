import CoreGraphics
import XCTest
@testable import DokoWanCafe

/// カードを横にめくる判定（次／前・端・位置）と、めくった先のピンを見える範囲へ出す判定の純ロジックのユニットテスト（憲章 原則IV）
final class CardPagingTests: XCTestCase {
    private func makeItem(_ name: String) -> CafeWithDistance {
        CafeWithDistance(
            cafe: Cafe(
                id: UUID(), placeID: nil, name: name, latitude: 35.65, longitude: 139.7,
                address: nil, contact: nil, dogPolicyStatus: .allowed, dogPolicyCondition: nil,
                lastVerified: nil, representativeSourceID: nil, hasConflict: false, isClosed: false, area: "tokyo"
            ),
            distanceMeters: 100
        )
    }

    private lazy var items = ["A", "B", "C", "D"].map(makeItem)

    // MARK: - 次／前

    func test_次の店は一覧の次() {
        XCTAssertEqual(CardPaging.neighbor(of: items[1].id, direction: .next, in: items)?.cafe.name, "C")
    }

    func test_前の店は一覧の前() {
        XCTAssertEqual(CardPaging.neighbor(of: items[1].id, direction: .previous, in: items)?.cafe.name, "A")
    }

    func test_末尾で次へは進まない() {
        XCTAssertNil(CardPaging.neighbor(of: items[3].id, direction: .next, in: items))
    }

    func test_先頭で前へは進まない() {
        XCTAssertNil(CardPaging.neighbor(of: items[0].id, direction: .previous, in: items))
    }

    func test_一覧にいない店からは進まない() {
        XCTAssertNil(CardPaging.neighbor(of: UUID(), direction: .next, in: items))
    }

    func test_1店だけの一覧は両方向とも進まない() {
        let single = [items[0]]
        XCTAssertNil(CardPaging.neighbor(of: items[0].id, direction: .next, in: single))
        XCTAssertNil(CardPaging.neighbor(of: items[0].id, direction: .previous, in: single))
    }

    // MARK: - 位置

    func test_位置は1始まりで全体の数を持つ() {
        let position = CardPaging.position(of: items[1].id, in: items)
        XCTAssertEqual(position, CardPaging.Position(number: 2, total: 4))
        XCTAssertEqual(position?.text, "2 / 4")
    }

    func test_先頭は前がなく末尾は次がない() {
        let first = CardPaging.position(of: items[0].id, in: items)
        XCTAssertEqual(first?.hasPrevious, false)
        XCTAssertEqual(first?.hasNext, true)
        let last = CardPaging.position(of: items[3].id, in: items)
        XCTAssertEqual(last?.hasPrevious, true)
        XCTAssertEqual(last?.hasNext, false)
    }

    func test_一覧にいない店の位置はnil() {
        XCTAssertNil(CardPaging.position(of: UUID(), in: items))
    }

    func test_一覧から消えた店はまだ一覧にいない扱い() {
        let remaining = Array(items.dropFirst())
        XCTAssertFalse(CardPaging.isStillListed(items[0].id, in: remaining))
        XCTAssertTrue(CardPaging.isStillListed(items[1].id, in: remaining))
    }

    // MARK: - ピンを見える範囲へ出す

    private let map = CGSize(width: 400, height: 800)

    func test_見える範囲の中なら動かさない() {
        XCTAssertNil(MapReveal.centerPoint(pin: CGPoint(x: 200, y: 400), mapSize: map, coveredTop: 150, coveredBottom: 250))
    }

    func test_上のバーに隠れるなら動かす() {
        // y=100 は上の 150 にふさがれている
        XCTAssertNotNil(MapReveal.centerPoint(pin: CGPoint(x: 200, y: 100), mapSize: map, coveredTop: 150, coveredBottom: 250))
    }

    func test_下のカードに隠れるなら動かす() {
        XCTAssertNotNil(MapReveal.centerPoint(pin: CGPoint(x: 200, y: 600), mapSize: map, coveredTop: 150, coveredBottom: 250))
    }

    func test_画面の外なら動かす() {
        XCTAssertNotNil(MapReveal.centerPoint(pin: CGPoint(x: -20, y: 400), mapSize: map, coveredTop: 150, coveredBottom: 250))
        XCTAssertNotNil(MapReveal.centerPoint(pin: CGPoint(x: 700, y: 400), mapSize: map, coveredTop: 150, coveredBottom: 250))
    }

    func test_動かすときはピンが見える範囲の真ん中に来る() {
        // 見える範囲は y 150〜550（真ん中 350）。ピン y=700 → 地図の中心は 400 + (700-350) = 750 の点へ
        let point = MapReveal.centerPoint(pin: CGPoint(x: 300, y: 700), mapSize: map, coveredTop: 150, coveredBottom: 250)
        XCTAssertEqual(point, CGPoint(x: 300, y: 750))
    }

    func test_余白の内側ならぎりぎり見えている扱い() {
        let margin = MapReveal.margin
        XCTAssertNil(MapReveal.centerPoint(pin: CGPoint(x: margin, y: 150 + margin), mapSize: map, coveredTop: 150, coveredBottom: 250))
        XCTAssertNotNil(MapReveal.centerPoint(pin: CGPoint(x: margin - 1, y: 300), mapSize: map, coveredTop: 150, coveredBottom: 250))
    }

    func test_地図の大きさが不正なら動かさない() {
        XCTAssertNil(MapReveal.centerPoint(pin: CGPoint(x: 10, y: 10), mapSize: .zero, coveredTop: 0, coveredBottom: 0))
    }
}
