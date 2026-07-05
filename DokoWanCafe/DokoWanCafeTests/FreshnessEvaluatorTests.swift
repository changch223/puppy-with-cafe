import XCTest
@testable import DokoWanCafe

/// T034: 鮮度評価のユニットテスト（FR-010, 憲章 原則IV）
final class FreshnessEvaluatorTests: XCTestCase {
    private let reference = Date(timeIntervalSince1970: 1_700_000_000)

    private func daysAgo(_ days: Double) -> Date {
        reference.addingTimeInterval(-days * 86_400)
    }

    func test_364日前は古くない() {
        XCTAssertFalse(
            FreshnessEvaluator.isStale(lastVerified: daysAgo(364), referenceDate: reference)
        )
    }

    func test_366日前は古い() {
        XCTAssertTrue(
            FreshnessEvaluator.isStale(lastVerified: daysAgo(366), referenceDate: reference)
        )
    }

    func test_確認日なしは古い扱い() {
        XCTAssertTrue(
            FreshnessEvaluator.isStale(lastVerified: nil, referenceDate: reference)
        )
    }

    func test_カスタムしきい値() {
        XCTAssertTrue(
            FreshnessEvaluator.isStale(lastVerified: daysAgo(31), referenceDate: reference, thresholdDays: 30)
        )
        XCTAssertFalse(
            FreshnessEvaluator.isStale(lastVerified: daysAgo(29), referenceDate: reference, thresholdDays: 30)
        )
    }

    func test_未来の確認日は古くない() {
        XCTAssertFalse(
            FreshnessEvaluator.isStale(lastVerified: daysAgo(-1), referenceDate: reference)
        )
    }
}
