import XCTest
@testable import DokoWanCafe

/// 写真プレビュー機能: `LinkPreviewService.PureLogic` のユニットテスト（ネットワーク非依存、憲章 原則IV）
final class LinkPreviewServiceTests: XCTestCase {
    // MARK: - cacheKey

    func test_同じURLは同じキャッシュキーになる() {
        let key1 = LinkPreviewService.PureLogic.cacheKey(for: "https://example.com/cafe")
        let key2 = LinkPreviewService.PureLogic.cacheKey(for: "https://example.com/cafe")
        XCTAssertEqual(key1, key2)
    }

    func test_異なるURLは異なるキャッシュキーになる() {
        let key1 = LinkPreviewService.PureLogic.cacheKey(for: "https://example.com/cafe-a")
        let key2 = LinkPreviewService.PureLogic.cacheKey(for: "https://example.com/cafe-b")
        XCTAssertNotEqual(key1, key2)
    }

    func test_キャッシュキーはSHA256の16進64文字でファイル名に安全な文字のみ() {
        let key = LinkPreviewService.PureLogic.cacheKey(for: "https://example.com/わんこカフェ?query=1&other=2")
        XCTAssertEqual(key.count, 64)
        XCTAssertTrue(key.allSatisfy { $0.isHexDigit })
    }

    // MARK: - isFresh (TTL 14日)

    func test_取得直後はTTL内で新鮮() {
        let now = Date()
        XCTAssertTrue(LinkPreviewService.PureLogic.isFresh(fetchedAt: now, now: now))
    }

    func test_TTL境界の直前は新鮮() {
        let now = Date()
        let fetchedAt = now.addingTimeInterval(-LinkPreviewService.PureLogic.ttlSeconds + 1)
        XCTAssertTrue(LinkPreviewService.PureLogic.isFresh(fetchedAt: fetchedAt, now: now))
    }

    func test_TTLちょうど_または超過は新鮮でない() {
        let now = Date()
        let fetchedAt = now.addingTimeInterval(-LinkPreviewService.PureLogic.ttlSeconds)
        XCTAssertFalse(LinkPreviewService.PureLogic.isFresh(fetchedAt: fetchedAt, now: now))
    }

    func test_14日を大きく超えた場合は新鮮でない() {
        let now = Date()
        let fetchedAt = now.addingTimeInterval(-30 * 24 * 60 * 60)
        XCTAssertFalse(LinkPreviewService.PureLogic.isFresh(fetchedAt: fetchedAt, now: now))
    }

    // MARK: - resizedSize（最大辺800px・アスペクト比維持・拡大しない）

    func test_横長画像は最大辺800にアスペクト比を保って縮小される() {
        let size = LinkPreviewService.PureLogic.resizedSize(originalSize: CGSize(width: 1600, height: 800))
        XCTAssertEqual(size.width, 800, accuracy: 0.5)
        XCTAssertEqual(size.height, 400, accuracy: 0.5)
    }

    func test_縦長画像は高さが最大辺基準で縮小される() {
        let size = LinkPreviewService.PureLogic.resizedSize(originalSize: CGSize(width: 400, height: 2000))
        XCTAssertEqual(size.height, 800, accuracy: 0.5)
        XCTAssertEqual(size.width, 160, accuracy: 0.5)
    }

    func test_既に最大辺以下の画像は拡大されない() {
        let size = LinkPreviewService.PureLogic.resizedSize(originalSize: CGSize(width: 300, height: 200))
        XCTAssertEqual(size.width, 300, accuracy: 0.5)
        XCTAssertEqual(size.height, 200, accuracy: 0.5)
    }

    func test_最大辺ちょうどの画像はそのまま() {
        let size = LinkPreviewService.PureLogic.resizedSize(originalSize: CGSize(width: 800, height: 800))
        XCTAssertEqual(size.width, 800, accuracy: 0.5)
        XCTAssertEqual(size.height, 800, accuracy: 0.5)
    }

    func test_不正な0サイズはそのまま返す() {
        let size = LinkPreviewService.PureLogic.resizedSize(originalSize: .zero)
        XCTAssertEqual(size, .zero)
    }
}
