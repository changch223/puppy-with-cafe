import XCTest
@testable import DokoWanCafe

/// FavoritesLogic のユニットテスト（UI/UXブラッシュアップ設計書 1c, 憲章 原則IV）
final class FavoritesLogicTests: XCTestCase {
    func test_decodeはnilなら空集合を返す() {
        XCTAssertEqual(FavoritesLogic.decode(nil), [])
    }

    func test_decodeはパース不能な文字列を無視する() {
        let id = UUID()
        let result = FavoritesLogic.decode([id.uuidString, "不正な値"])
        XCTAssertEqual(result, [id])
    }

    func test_encodeとdecodeは往復可能() {
        let ids: Set<UUID> = [UUID(), UUID(), UUID()]
        let decoded = FavoritesLogic.decode(FavoritesLogic.encode(ids))
        XCTAssertEqual(decoded, ids)
    }

    func test_toggledは未登録のIDを追加する() {
        let id = UUID()
        let result = FavoritesLogic.toggled(id, in: [])
        XCTAssertEqual(result, [id])
    }

    func test_toggledは登録済みのIDを除去する() {
        let id = UUID()
        let result = FavoritesLogic.toggled(id, in: [id])
        XCTAssertTrue(result.isEmpty)
    }

    func test_toggledは対象外のIDに影響しない() {
        let target = UUID()
        let other = UUID()
        let result = FavoritesLogic.toggled(target, in: [other])
        XCTAssertEqual(result, [other, target])
    }
}
