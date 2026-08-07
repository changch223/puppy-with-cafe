import XCTest
@testable import DokoWanCafe

/// T024: 可否フィルタのユニットテスト（FR-004, 憲章 原則IV）
final class CafeFilterTests: XCTestCase {
    private func makeItem(
        _ status: DogPolicyStatus,
        distance: Double = 100,
        amenities: DogAmenities? = nil,
        lastVerified: Date? = nil
    ) -> CafeWithDistance {
        CafeWithDistance(
            cafe: Cafe(
                id: UUID(), placeID: nil, name: "テスト \(status.rawValue)",
                latitude: 35.68, longitude: 139.76,
                address: nil, contact: nil,
                dogPolicyStatus: status, dogPolicyCondition: nil,
                lastVerified: lastVerified, representativeSourceID: nil,
                hasConflict: false, isClosed: false, area: "tokyo",
                dogAmenities: amenities
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

    // MARK: - amenities（UI/UXブラッシュアップ設計書 1b）

    private var amenityItems: [CafeWithDistance] {
        [
            makeItem(.allowed, amenities: DogAmenities(indoor: true, terrace: false, largeDogs: nil, dogMenu: true)),
            makeItem(.allowed, amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil)),
            makeItem(.conditional, amenities: nil),
            makeItem(.unverified, amenities: DogAmenities(indoor: true, terrace: true, largeDogs: nil, dogMenu: true))
        ]
    }

    func test_トグルなしでもincludeUnverifiedがfalseなら未確認は除外される() {
        let result = CafeFilter.apply(amenities: AmenityFilter(), to: amenityItems)
        XCTAssertEqual(result.count, 3)
        XCTAssertFalse(result.contains { $0.cafe.dogPolicyStatus == .unverified })
    }

    func test_includeUnverifiedをtrueにすると未確認も含まれる() {
        let result = CafeFilter.apply(amenities: AmenityFilter(), includeUnverified: true, to: amenityItems)
        XCTAssertEqual(result.count, amenityItems.count)
    }

    /// QA指摘: 将来 not_allowed が入っても、トグル（includeUnverified）に関わらず常時除外されること
    /// （本アプリは犬同伴OK店のみを扱うデータ方針。MapPinCategoryの誤分類を防ぐガード）
    func test_notAllowedはincludeUnverifiedをtrueにしても常に除外される() {
        let items = amenityItems + [makeItem(.notAllowed, amenities: DogAmenities(indoor: true, terrace: true, largeDogs: nil, dogMenu: true))]
        let result = CafeFilter.apply(amenities: AmenityFilter(), includeUnverified: true, to: items)
        XCTAssertFalse(result.contains { $0.cafe.dogPolicyStatus == .notAllowed })
        XCTAssertEqual(result.count, amenityItems.count)
    }

    func test_indoorOnlyはindoorがtrueの店のみ通す() {
        let result = CafeFilter.apply(
            amenities: AmenityFilter(indoorOnly: true),
            includeUnverified: true,
            to: amenityItems
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.cafe.dogAmenities?.indoor == true })
    }

    func test_indoorOnlyとterraceOnlyはAND結合で両方trueの店のみ通す() {
        let result = CafeFilter.apply(
            amenities: AmenityFilter(indoorOnly: true, terraceOnly: true),
            includeUnverified: true,
            to: amenityItems
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.cafe.dogPolicyStatus, .unverified)
    }

    func test_dogMenuOnlyはamenity不明nilの店を通さない() {
        let result = CafeFilter.apply(
            amenities: AmenityFilter(dogMenuOnly: true),
            includeUnverified: true,
            to: amenityItems
        )
        // dogMenu が true の店は「indoor:true」と「未確認」の2件（未確認はincludeUnverified=trueで対象）
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.cafe.dogAmenities?.dogMenu == true })
    }

    // MARK: - sorted（UI/UXブラッシュアップ設計書 1b）

    func test_distanceソートは距離昇順() {
        let items = [
            makeItem(.allowed, distance: 300),
            makeItem(.allowed, distance: 100),
            makeItem(.allowed, distance: 200)
        ]
        let sorted = CafeFilter.sorted(items, by: .distance)
        XCTAssertEqual(sorted.map(\.distanceMeters), [100, 200, 300])
    }

    func test_recentlyVerifiedソートはlastVerified降順でnilは末尾() {
        let newer = Date(timeIntervalSince1970: 1_700_000_000)
        let older = Date(timeIntervalSince1970: 1_600_000_000)
        let items = [
            makeItem(.allowed, lastVerified: nil),
            makeItem(.allowed, lastVerified: older),
            makeItem(.allowed, lastVerified: newer)
        ]
        let sorted = CafeFilter.sorted(items, by: .recentlyVerified)
        XCTAssertEqual(sorted.map(\.cafe.lastVerified), [newer, older, nil])
    }
}
