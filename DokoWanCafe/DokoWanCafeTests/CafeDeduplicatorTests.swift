import XCTest
@testable import DokoWanCafe

/// T019: 名寄せのユニットテスト（FR-030, 憲章 原則IV）
final class CafeDeduplicatorTests: XCTestCase {
    private func makeCafe(
        placeID: String? = nil,
        name: String,
        latitude: Double = 35.6800,
        longitude: Double = 139.7700,
        lastVerified: Date? = nil
    ) -> Cafe {
        Cafe(
            id: UUID(), placeID: placeID, name: name,
            latitude: latitude, longitude: longitude,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: lastVerified, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo"
        )
    }

    func test_同じplace_idは同一とみなす() {
        // 名称・座標が違っても place_id が一致すれば同一（FR-030: 主キー）
        let a = makeCafe(placeID: "p-1", name: "ドッグカフェA", latitude: 35.68, longitude: 139.77)
        let b = makeCafe(placeID: "p-1", name: "Dog Cafe A 支店表記", latitude: 35.70, longitude: 139.80)
        XCTAssertTrue(CafeDeduplicator.isSameCafe(a, b))
        XCTAssertEqual(CafeDeduplicator.deduplicate([a, b]).count, 1)
    }

    func test_異なるplace_idは別店舗() {
        let a = makeCafe(placeID: "p-1", name: "ドッグカフェ")
        let b = makeCafe(placeID: "p-2", name: "ドッグカフェ")
        XCTAssertFalse(CafeDeduplicator.isSameCafe(a, b))
        XCTAssertEqual(CafeDeduplicator.deduplicate([a, b]).count, 2)
    }

    func test_place_idなし_同名かつ50m以内は統合() {
        // 緯度 0.0004度 ≒ 44m
        let a = makeCafe(name: "わんこカフェ 日本橋", latitude: 35.6800)
        let b = makeCafe(name: "わんこカフェ 日本橋", latitude: 35.6804)
        XCTAssertTrue(CafeDeduplicator.isSameCafe(a, b))
        XCTAssertEqual(CafeDeduplicator.deduplicate([a, b]).count, 1)
    }

    func test_place_idなし_同名でも遠ければ別店舗() {
        // 緯度 0.0018度 ≒ 200m
        let a = makeCafe(name: "わんこカフェ", latitude: 35.6800)
        let b = makeCafe(name: "わんこカフェ", latitude: 35.6818)
        XCTAssertFalse(CafeDeduplicator.isSameCafe(a, b))
        XCTAssertEqual(CafeDeduplicator.deduplicate([a, b]).count, 2)
    }

    func test_近くても名称が違えば別店舗() {
        let a = makeCafe(name: "カフェ・ワン", latitude: 35.6800)
        let b = makeCafe(name: "カフェ・ニャン", latitude: 35.6801)
        XCTAssertFalse(CafeDeduplicator.isSameCafe(a, b))
    }

    func test_名称正規化_空白と大文字小文字と全角半角を吸収() {
        XCTAssertEqual(
            CafeDeduplicator.normalizedName("Dog Cafe TOKYO"),
            CafeDeduplicator.normalizedName("ｄｏｇ　ｃａｆｅ　tokyo")
        )
        XCTAssertEqual(
            CafeDeduplicator.normalizedName(" わんこカフェ "),
            CafeDeduplicator.normalizedName("わんこカフェ")
        )
    }

    func test_統合時は最終確認日が新しい方を残す() {
        let old = makeCafe(placeID: "p-1", name: "古い方", lastVerified: Date(timeIntervalSince1970: 1_000))
        let new = makeCafe(placeID: "p-1", name: "新しい方", lastVerified: Date(timeIntervalSince1970: 2_000))
        let result = CafeDeduplicator.deduplicate([old, new])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "新しい方")
    }
}
