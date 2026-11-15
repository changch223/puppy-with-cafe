import XCTest
@testable import DokoWanCafe

/// 細かいエリアを広いエリアへまとめる対応表のユニットテスト（憲章 原則IV）
final class BroadAreaTests: XCTestCase {
    private func makeItem(area: String?, lat: Double, lng: Double) -> CafeWithDistance {
        var cafe = Cafe(
            id: UUID(), placeID: nil, name: "店", latitude: lat, longitude: lng,
            address: nil, contact: nil, dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil, hasConflict: false, isClosed: false, area: "tokyo"
        )
        cafe.subArea = area
        return CafeWithDistance(cafe: cafe, distanceMeters: 100)
    }

    func test_細かいエリアは広いエリアにまとまる() {
        XCTAssertEqual(BroadArea.name(forSubArea: "渋谷駅周辺"), "渋谷・恵比寿・六本木")
        XCTAssertEqual(BroadArea.name(forSubArea: "表参道・青山"), "渋谷・恵比寿・六本木")
        XCTAssertEqual(BroadArea.name(forSubArea: "代官山"), "渋谷・恵比寿・六本木")
        XCTAssertEqual(BroadArea.name(forSubArea: "高尾山"), "高尾")
    }

    func test_表にないエリアはその名前のまま() {
        XCTAssertEqual(BroadArea.name(forSubArea: "新しいエリア"), "新しいエリア")
        XCTAssertEqual(BroadArea.shortName(forArea: "新しいエリア"), "新しいエリア")
    }

    func test_札には短い名前を出す() {
        XCTAssertEqual(BroadArea.shortName(forArea: "渋谷・恵比寿・六本木"), "渋谷")
        XCTAssertEqual(BroadArea.shortName(forArea: "自由が丘・学芸大学"), "自由が丘")
        // 短い名前は重ならず、長い札にならない（5文字まで）
        let shorts = BroadArea.groups.map(\.shortName)
        XCTAssertEqual(shorts.count, Set(shorts).count)
        XCTAssertTrue(shorts.allSatisfy { !$0.isEmpty && $0.count <= 5 })
    }

    func test_同じ細かいエリアが2つの広いエリアに入っていない() {
        let all = BroadArea.groups.flatMap(\.subAreas)
        XCTAssertEqual(all.count, Set(all).count)
    }

    func test_広いエリアの名前は重ならず_細かいエリアの名前とも取り違えない() {
        let names = BroadArea.groups.map(\.name)
        XCTAssertEqual(names.count, Set(names).count)
        // 広いエリアと同じ名前の細かいエリアは、その広いエリアの中にある（別の広いエリアに入っていない）
        for group in BroadArea.groups {
            for other in BroadArea.groups where other.name != group.name {
                XCTAssertFalse(other.subAreas.contains(group.name), "\(group.name) が \(other.name) に入っている")
            }
        }
    }

    func test_同梱の店のエリアはすべて表にある() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "cafes", withExtension: "json"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let cafes = try XCTUnwrap(object["cafes"] as? [[String: Any]])
        let known = Set(BroadArea.groups.flatMap(\.subAreas))
        let subAreas = Set(cafes.compactMap { $0["sub_area"] as? String }.filter { !$0.isEmpty })
        XCTAssertFalse(subAreas.isEmpty)
        XCTAssertEqual(subAreas.subtracting(known), [], "対応表にないエリアがある（BroadArea.groups に足す）")
    }

    func test_札は広いエリアで数える() {
        let items = [
            makeItem(area: "渋谷駅周辺", lat: 35.660, lng: 139.700),
            makeItem(area: "表参道・青山", lat: 35.667, lng: 139.713),
            makeItem(area: "千駄ヶ谷", lat: 35.679, lng: 139.708),
            makeItem(area: "吉祥寺", lat: 35.702, lng: 139.578),
        ]
        let summaries = AreaOverview.summaries(for: items)
        XCTAssertEqual(summaries.map(\.name), ["渋谷・恵比寿・六本木", "吉祥寺・三鷹"])
        XCTAssertEqual(summaries.map(\.count), [3, 1])
    }
}
