import XCTest
@testable import DokoWanCafe

/// SavedPlacesStore のユニットテスト（再設計 段階2）。
/// テストごとに専用の UserDefaults suite を注入し、他テスト・実データと隔離する。
@MainActor
final class SavedPlacesStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "SavedPlacesStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func test_初期状態は保存なし() {
        let store = SavedPlacesStore(defaults: makeDefaults())
        XCTAssertNil(store.status(of: UUID()))
        XCTAssertTrue(store.wantToGoIDs.isEmpty)
        XCTAssertTrue(store.visitedIDs.isEmpty)
    }

    func test_行きたい_行った_外すの遷移() {
        var time = t0
        let store = SavedPlacesStore(defaults: makeDefaults(), now: { time })
        let id = UUID()

        store.toggleWantToGo(id)
        XCTAssertTrue(store.isWantToGo(id))

        time = t0.addingTimeInterval(60)
        store.toggleVisited(id)
        XCTAssertEqual(store.status(of: id), .visited)
        XCTAssertFalse(store.isWantToGo(id))
        XCTAssertEqual(store.visitedDate(of: id), time)

        store.toggleVisited(id)
        XCTAssertNil(store.status(of: id))
    }

    func test_保存内容は同じsuiteの別インスタンスから読み込める() {
        let defaults = makeDefaults()
        let want = UUID(), visited = UUID()
        let store = SavedPlacesStore(defaults: defaults, now: { self.t0 })
        store.toggleWantToGo(want)
        store.toggleVisited(visited)

        let reloaded = SavedPlacesStore(defaults: defaults)
        XCTAssertTrue(reloaded.isWantToGo(want))
        XCTAssertEqual(reloaded.status(of: visited), .visited)
        XCTAssertEqual(reloaded.visitedDate(of: visited), t0)
    }

    func test_異なるsuiteは互いに影響しない() {
        let id = UUID()
        let storeA = SavedPlacesStore(defaults: makeDefaults())
        let storeB = SavedPlacesStore(defaults: makeDefaults())
        storeA.toggleWantToGo(id)
        XCTAssertTrue(storeA.isWantToGo(id))
        XCTAssertNil(storeB.status(of: id))
    }

    // MARK: - 読めないデータの退避

    func test_読めない保存データは空で上書きせず別キーへ退避してから空で始める() {
        let defaults = makeDefaults()
        let garbage = Data("これはJSONではない".utf8)
        defaults.set(garbage, forKey: SavedPlacesStore.storageKey)

        let store = SavedPlacesStore(defaults: defaults, now: { self.t0 })
        XCTAssertTrue(store.wantToGoIDs.isEmpty)
        XCTAssertTrue(store.visitedIDs.isEmpty)

        let backupKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(SavedPlacesStore.corruptKeyPrefix) }
        XCTAssertEqual(backupKeys.count, 1)
        XCTAssertEqual(defaults.data(forKey: backupKeys[0]), garbage, "読めなかったデータはそのまま残す")
        // 元のキーから読めないデータは消えている（初回の移行で保存された空のデータに置き換わる）
        XCTAssertNotEqual(defaults.data(forKey: SavedPlacesStore.storageKey), garbage)
        let current = defaults.data(forKey: SavedPlacesStore.storageKey)
        XCTAssertEqual(current.flatMap { try? JSONDecoder().decode(SavedPlaces.self, from: $0) }, SavedPlaces())

        // 次の起動でも退避は増えない（1回だけ）
        _ = SavedPlacesStore(defaults: defaults, now: { self.t0.addingTimeInterval(60) })
        XCTAssertEqual(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(SavedPlacesStore.corruptKeyPrefix) }.count, 1)

        // 空で始めたあとの保存で元のキーが上書きされても、退避したデータは消えない
        store.toggleWantToGo(UUID())
        XCTAssertEqual(defaults.data(forKey: backupKeys[0]), garbage)
    }

    func test_読めるデータなら退避しない() {
        let defaults = makeDefaults()
        let store = SavedPlacesStore(defaults: defaults, now: { self.t0 })
        store.toggleWantToGo(UUID())
        _ = SavedPlacesStore(defaults: defaults)
        XCTAssertTrue(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(SavedPlacesStore.corruptKeyPrefix) }.isEmpty)
    }

    // MARK: - 旧お気に入りの移行

    func test_初回起動で旧お気に入りは行きたいに入り旧キーは残る() {
        let defaults = makeDefaults()
        let a = UUID(), b = UUID()
        defaults.set([a.uuidString, b.uuidString], forKey: SavedPlacesStore.legacyFavoritesKey)

        let store = SavedPlacesStore(defaults: defaults, now: { self.t0 })

        XCTAssertEqual(store.wantToGoIDs, [a, b])
        XCTAssertTrue(store.visitedIDs.isEmpty)
        XCTAssertEqual(
            defaults.stringArray(forKey: SavedPlacesStore.legacyFavoritesKey)?.count, 2,
            "旧キーは移行後も消さない（利用者のデータを失わない）"
        )
        XCTAssertTrue(defaults.bool(forKey: SavedPlacesStore.migratedFlagKey))
    }

    func test_移行は1回だけで二重に移行しない() {
        let defaults = makeDefaults()
        let a = UUID()
        defaults.set([a.uuidString], forKey: SavedPlacesStore.legacyFavoritesKey)

        let first = SavedPlacesStore(defaults: defaults, now: { self.t0 })
        // 利用者が行きたいから外した後、再起動しても旧お気に入りから復活しない
        first.toggleWantToGo(a)
        XCTAssertNil(first.status(of: a))

        let second = SavedPlacesStore(defaults: defaults)
        XCTAssertNil(second.status(of: a), "移行済みフラグで二重移行を防ぐ")
        XCTAssertTrue(second.wantToGoIDs.isEmpty)
    }

    func test_行ったに移した店は再起動しても行きたいに戻らない() {
        let defaults = makeDefaults()
        let a = UUID()
        defaults.set([a.uuidString], forKey: SavedPlacesStore.legacyFavoritesKey)

        let first = SavedPlacesStore(defaults: defaults, now: { self.t0 })
        first.toggleVisited(a)

        let second = SavedPlacesStore(defaults: defaults)
        XCTAssertEqual(second.status(of: a), .visited)
    }

    func test_旧データがなくても移行済みになり新規保存は影響を受けない() {
        let defaults = makeDefaults()
        let store = SavedPlacesStore(defaults: defaults)
        XCTAssertTrue(store.wantToGoIDs.isEmpty)
        XCTAssertTrue(defaults.bool(forKey: SavedPlacesStore.migratedFlagKey))

        // 移行後に旧キーが書き込まれても（古い版に戻した場合など）読み込み直しで取り込まない
        let late = UUID()
        defaults.set([late.uuidString], forKey: SavedPlacesStore.legacyFavoritesKey)
        XCTAssertNil(SavedPlacesStore(defaults: defaults).status(of: late))
    }
}
