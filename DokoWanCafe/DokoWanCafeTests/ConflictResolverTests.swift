import XCTest
@testable import DokoWanCafe

/// T045: 矛盾解決のユニットテスト（FR-013 の全分岐, 憲章 原則IV）
final class ConflictResolverTests: XCTestCase {
    private let cafeID = UUID()

    private func makeSource(
        _ status: DogPolicyStatus,
        daysAgo: Int?,
        provenance: Provenance
    ) -> Source {
        Source(
            id: UUID(), cafeID: cafeID, type: .other, reference: nil,
            claimedStatus: status,
            verifiedAt: daysAgo.map { Date(timeIntervalSince1970: 1_700_000_000 - Double($0) * 86_400) },
            provenance: provenance
        )
    }

    func test_出典なしは未確認_矛盾なし() {
        let result = ConflictResolver.resolve(sources: [])
        XCTAssertEqual(result.status, .unverified)
        XCTAssertNil(result.representativeSource)
        XCTAssertFalse(result.hasConflict)
    }

    func test_未確認のみの出典は判定対象外() {
        let result = ConflictResolver.resolve(sources: [
            makeSource(.unverified, daysAgo: 1, provenance: .aggregated),
        ])
        XCTAssertEqual(result.status, .unverified)
        XCTAssertFalse(result.hasConflict)
    }

    func test_単一出典はそのまま代表になる() {
        let source = makeSource(.allowed, daysAgo: 10, provenance: .official)
        let result = ConflictResolver.resolve(sources: [source])
        XCTAssertEqual(result.status, .allowed)
        XCTAssertEqual(result.representativeSource?.id, source.id)
        XCTAssertFalse(result.hasConflict)
    }

    func test_規則1_確認日が新しい出典を優先() {
        // 古い公式「不可」より、新しいブログ集約「可」が優先（確認日が第一基準）
        let newer = makeSource(.allowed, daysAgo: 5, provenance: .aggregated)
        let older = makeSource(.notAllowed, daysAgo: 300, provenance: .official)
        let result = ConflictResolver.resolve(sources: [older, newer])
        XCTAssertEqual(result.status, .allowed)
        XCTAssertEqual(result.representativeSource?.id, newer.id)
        XCTAssertTrue(result.hasConflict)
    }

    func test_規則2_同日なら由来の信頼順で優先() {
        // 同じ確認日: 公式「可」 > AI推測「不可」
        let official = makeSource(.allowed, daysAgo: 10, provenance: .official)
        let ai = makeSource(.notAllowed, daysAgo: 10, provenance: .aiInferred)
        let result = ConflictResolver.resolve(sources: [ai, official])
        XCTAssertEqual(result.status, .allowed)
        XCTAssertEqual(result.representativeSource?.id, official.id)
        XCTAssertTrue(result.hasConflict)
    }

    func test_規則3_確定できなければ未確認_憶測で可にしない() {
        // 同じ確認日・同じ信頼順で可否が割れる → 未確認（憲章 原則I）
        let a = makeSource(.allowed, daysAgo: 10, provenance: .aggregated)
        let b = makeSource(.notAllowed, daysAgo: 10, provenance: .aggregated)
        let result = ConflictResolver.resolve(sources: [a, b])
        XCTAssertEqual(result.status, .unverified)
        XCTAssertNil(result.representativeSource)
        XCTAssertTrue(result.hasConflict)
    }

    func test_確認日なしは最古扱い() {
        let dated = makeSource(.conditional, daysAgo: 100, provenance: .humanVerified)
        let undated = makeSource(.notAllowed, daysAgo: nil, provenance: .official)
        let result = ConflictResolver.resolve(sources: [undated, dated])
        XCTAssertEqual(result.status, .conditional)
        XCTAssertEqual(result.representativeSource?.id, dated.id)
    }

    func test_一致する複数出典は矛盾なし() {
        let a = makeSource(.conditional, daysAgo: 10, provenance: .official)
        let b = makeSource(.conditional, daysAgo: 50, provenance: .aggregated)
        let result = ConflictResolver.resolve(sources: [a, b])
        XCTAssertEqual(result.status, .conditional)
        XCTAssertFalse(result.hasConflict)
    }
}
