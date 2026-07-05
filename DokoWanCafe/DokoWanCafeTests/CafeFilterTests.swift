import XCTest
@testable import DokoWanCafe

/// T024: 可否フィルタのユニットテスト（FR-004, 憲章 原則IV）
final class CafeFilterTests: XCTestCase {
    private func makeItem(_ status: DogPolicyStatus, distance: Double = 100) -> CafeWithDistance {
        CafeWithDistance(
            cafe: Cafe(
                id: UUID(), placeID: nil, name: "テスト \(status.rawValue)",
                latitude: 35.68, longitude: 139.76,
                address: nil, contact: nil,
                dogPolicyStatus: status, dogPolicyCondition: nil,
                lastVerified: nil, representativeSourceID: nil,
                hasConflict: false, isClosed: false, area: "tokyo"
            ),
            distanceMeters: distance
        )
    }

    private var allItems: [CafeWithDistance] {
        [makeItem(.allowed), makeItem(.conditional), makeItem(.notAllowed), makeItem(.unverified)]
    }

    func test_可のみで絞り込むと不可と未確認が除外される() {
        let result = CafeFilter.apply([.allowed], to: allItems)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.cafe.dogPolicyStatus, .allowed)
    }

    func test_可と条件付きで絞り込む() {
        let result = CafeFilter.apply([.allowed, .conditional], to: allItems)
        XCTAssertEqual(
            Set(result.map(\.cafe.dogPolicyStatus)),
            [.allowed, .conditional]
        )
    }

    func test_空の選択は全件を返す() {
        let result = CafeFilter.apply([], to: allItems)
        XCTAssertEqual(result.count, allItems.count)
    }

    func test_全ステータス選択は全件を返す() {
        let result = CafeFilter.apply(Set(DogPolicyStatus.allCases), to: allItems)
        XCTAssertEqual(result.count, allItems.count)
    }
}
