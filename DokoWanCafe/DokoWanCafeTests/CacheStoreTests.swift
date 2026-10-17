import XCTest
@testable import DokoWanCafe

/// CacheStore のユニットテスト（FR-029）。
/// 現在地・検索起点からの距離はキャッシュに保存しない（憲章 原則III）。
final class CacheStoreTests: XCTestCase {
    private var store: CacheStore!

    override func setUp() {
        super.setUp()
        store = CacheStore(filename: "test-cache-\(UUID().uuidString).json")
    }

    override func tearDown() {
        store.clear()
        super.tearDown()
    }

    private func makeCafe(name: String) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: name,
            latitude: 35.6812, longitude: 139.7671,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo"
        )
    }

    func test_保存して読み込める() throws {
        let cafe = makeCafe(name: "テストカフェ")
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        store.save([cafe], fetchedAt: fetchedAt)

        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.cafes, [cafe])
        XCTAssertEqual(loaded.fetchedAt, fetchedAt)
    }

    func test_ディスク上のキャッシュに距離が含まれない() throws {
        store.save([makeCafe(name: "テストカフェ")])

        let raw = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertFalse(raw.contains("distance"), "検索起点由来の距離は保存しない")
    }

    func test_旧形式_距離つきキャッシュも壊れず店データだけ読める() throws {
        // 旧形式: cafes が [{cafe, distance_m}]
        struct LegacySnapshot: Encodable {
            let fetchedAt: Date
            let cafes: [CafeWithDistance]
        }
        let cafe = makeCafe(name: "旧キャッシュのカフェ")
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(
            LegacySnapshot(fetchedAt: fetchedAt, cafes: [CafeWithDistance(cafe: cafe, distanceMeters: 1234)])
        )
        try data.write(to: store.fileURL)

        let loaded = try XCTUnwrap(store.load(), "旧形式でも読み込める")
        XCTAssertEqual(loaded.cafes, [cafe])
        XCTAssertEqual(loaded.fetchedAt, fetchedAt)
    }

    func test_壊れたキャッシュはnil() throws {
        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertNil(store.load())
    }
}
