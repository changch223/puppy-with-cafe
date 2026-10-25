import XCTest
@testable import DokoWanCafe

/// 保存（行きたい／行った）の純ロジック・移行・共有文のユニットテスト（再設計 段階2, 憲章 原則IV）
final class SavedPlacesTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private func later(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    // MARK: - 状態遷移

    func test_初期状態は未保存() {
        let places = SavedPlaces()
        XCTAssertNil(places.status(of: UUID()))
        XCTAssertTrue(places.wantToGoIDs.isEmpty)
        XCTAssertTrue(places.visitedIDs.isEmpty)
    }

    func test_行きたいを押すと追加され再度押すと外れる() {
        var places = SavedPlaces()
        let id = UUID()
        places.toggleWantToGo(id, at: t0)
        XCTAssertEqual(places.status(of: id), .wantToGo)
        places.toggleWantToGo(id, at: later(1))
        XCTAssertNil(places.status(of: id))
    }

    func test_行きたいから行ったに移ると行きたいから外れ行った日が入る() {
        var places = SavedPlaces()
        let id = UUID()
        places.toggleWantToGo(id, at: t0)
        places.toggleVisited(id, at: later(100))

        XCTAssertEqual(places.status(of: id), .visited)
        XCTAssertFalse(places.wantToGoIDs.contains(id), "2つのリストに同時には入らない")
        XCTAssertEqual(places.visitedDate(of: id), later(100))
    }

    func test_行ったをもう一度押すと外れる() {
        var places = SavedPlaces()
        let id = UUID()
        places.toggleVisited(id, at: t0)
        XCTAssertEqual(places.status(of: id), .visited)
        places.toggleVisited(id, at: later(1))
        XCTAssertNil(places.status(of: id))
        XCTAssertNil(places.visitedDate(of: id))
    }

    func test_行った店で行きたいを押すと行きたいに戻る() {
        var places = SavedPlaces()
        let id = UUID()
        places.toggleVisited(id, at: t0)
        places.toggleWantToGo(id, at: later(1))
        XCTAssertEqual(places.status(of: id), .wantToGo)
        XCTAssertNil(places.visitedDate(of: id))
    }

    func test_行きたい_行った_外すの一連の遷移() {
        var places = SavedPlaces()
        let id = UUID()
        let other = UUID()
        places.toggleWantToGo(other, at: t0)
        places.toggleWantToGo(id, at: later(1))
        places.toggleVisited(id, at: later(2))
        places.remove(id)
        XCTAssertNil(places.status(of: id))
        XCTAssertEqual(places.status(of: other), .wantToGo, "他の店には影響しない")
    }

    // MARK: - 並び

    func test_新しい順に並べ同じ日付は店IDで固定する() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let c = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!
        let sorted = SavedPlaces.newestFirst([
            SavedEntry(id: b, date: t0),
            SavedEntry(id: c, date: later(10)),
            SavedEntry(id: a, date: t0),
        ])
        XCTAssertEqual(sorted.map(\.id), [c, a, b])
    }

    private func item(_ id: UUID) -> CafeWithDistance {
        let cafe = Cafe(
            id: id, placeID: nil, name: "店", latitude: 35.0, longitude: 139.0,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo"
        )
        return CafeWithDistance(cafe: cafe, distanceMeters: 100)
    }

    func test_保存一覧は新しい順に店へ当てはめ見つからない店は飛ばす() {
        let older = UUID(), newer = UUID(), missing = UUID()
        let entries = [
            SavedEntry(id: older, date: t0),
            SavedEntry(id: missing, date: later(5)),
            SavedEntry(id: newer, date: later(10)),
        ]
        let result = SavedPlaces.resolve(entries, in: [item(older), item(newer)])
        XCTAssertEqual(result.map(\.cafe.id), [newer, older])
    }

    // MARK: - 保存形式

    func test_JSONの往復で内容が変わらない() throws {
        var places = SavedPlaces()
        let a = UUID(), b = UUID()
        places.toggleWantToGo(a, at: t0)
        places.toggleVisited(b, at: later(1))
        let decoded = try JSONDecoder().decode(SavedPlaces.self, from: JSONEncoder().encode(places))
        XCTAssertEqual(decoded, places)
    }

    // MARK: - 旧お気に入りの移行

    func test_旧お気に入りはすべて行きたいに入る() {
        let a = UUID(), b = UUID()
        let migrated = SavedPlacesMigration.migrate(
            legacyRawIDs: [a.uuidString, b.uuidString, "不正な値"], into: SavedPlaces(), at: t0
        )
        XCTAssertEqual(migrated.wantToGoIDs, [a, b])
        XCTAssertTrue(migrated.visitedIDs.isEmpty)
        XCTAssertEqual(migrated.wantToGo.map(\.date), [t0, t0])
    }

    func test_旧データがなければ何も起きない() {
        XCTAssertEqual(SavedPlacesMigration.migrate(legacyRawIDs: nil, into: SavedPlaces(), at: t0), SavedPlaces())
        XCTAssertEqual(SavedPlacesMigration.migrate(legacyRawIDs: [], into: SavedPlaces(), at: t0), SavedPlaces())
    }

    func test_すでに保存済みの店は移行で動かさない() {
        let visited = UUID(), want = UUID(), fresh = UUID()
        var existing = SavedPlaces()
        existing.toggleVisited(visited, at: t0)
        existing.toggleWantToGo(want, at: t0)

        let migrated = SavedPlacesMigration.migrate(
            legacyRawIDs: [visited.uuidString, want.uuidString, fresh.uuidString], into: existing, at: later(99)
        )
        XCTAssertEqual(migrated.status(of: visited), .visited, "行った店を行きたいに戻さない")
        XCTAssertEqual(migrated.wantToGoIDs, [want, fresh])
        XCTAssertEqual(migrated.wantToGo.first(where: { $0.id == want })?.date, t0, "追加日を上書きしない")
    }

    // MARK: - リスト共有文

    private func cafe(_ name: String, subArea: String? = "代官山", lat: Double = 35.65, lng: Double = 139.70) -> Cafe {
        var cafe = Cafe(
            id: UUID(), placeID: nil, name: name, latitude: lat, longitude: lng,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo"
        )
        cafe.subArea = subArea
        return cafe
    }

    func test_共有文は店名エリアURLを1店1ブロックで並べる() {
        let message = SavedListShare.message(for: [cafe("カフェA"), cafe("カフェB", subArea: nil, lat: 35.1, lng: 139.2)])
        let expected = [
            "行きたいお店リスト（2店）",
            "カフェA\n代官山\nhttps://www.google.com/maps/search/?api=1&query=35.65,139.7",
            "カフェB\nhttps://www.google.com/maps/search/?api=1&query=35.1,139.2",
            "Puppy With Cafe で見つけました",
        ].joined(separator: "\n\n")
        XCTAssertEqual(message, expected)
    }

    func test_共有文は20店まででそれを超えたらほかN店() {
        let cafes = (1...23).map { cafe("店\($0)") }
        let message = SavedListShare.message(for: cafes)
        XCTAssertTrue(message.contains("行きたいお店リスト（23店）"))
        XCTAssertTrue(message.contains("店20\n"))
        XCTAssertFalse(message.contains("店21\n"))
        XCTAssertTrue(message.contains("ほか3店"))
    }

    func test_ちょうど20店ならほかは出さない() {
        let message = SavedListShare.message(for: (1...20).map { cafe("店\($0)") })
        XCTAssertFalse(message.contains("ほか"))
    }
}
