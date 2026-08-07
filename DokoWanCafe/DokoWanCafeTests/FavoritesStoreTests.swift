import XCTest
@testable import DokoWanCafe

/// FavoritesStore のユニットテスト（UI/UXブラッシュアップ設計書 1c）。
/// テストごとに専用の UserDefaults suite を注入し、他テスト・実データと隔離する。
@MainActor
final class FavoritesStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "FavoritesStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    func test_初期状態はお気に入りなし() {
        let store = FavoritesStore(defaults: makeDefaults())
        let id = UUID()
        XCTAssertFalse(store.contains(id))
        XCTAssertTrue(store.favoriteIDs.isEmpty)
    }

    func test_toggleでお気に入りに追加され再度toggleで解除される() {
        let store = FavoritesStore(defaults: makeDefaults())
        let id = UUID()

        store.toggle(id)
        XCTAssertTrue(store.contains(id))

        store.toggle(id)
        XCTAssertFalse(store.contains(id))
    }

    func test_保存内容は同じsuiteの別インスタンスから読み込める() {
        let defaults = makeDefaults()
        let id = UUID()

        let store = FavoritesStore(defaults: defaults)
        store.toggle(id)

        let reloaded = FavoritesStore(defaults: defaults)
        XCTAssertTrue(reloaded.contains(id))
    }

    func test_異なるsuiteは互いに影響しない() {
        let id = UUID()
        let storeA = FavoritesStore(defaults: makeDefaults())
        let storeB = FavoritesStore(defaults: makeDefaults())

        storeA.toggle(id)

        XCTAssertTrue(storeA.contains(id))
        XCTAssertFalse(storeB.contains(id))
    }
}
