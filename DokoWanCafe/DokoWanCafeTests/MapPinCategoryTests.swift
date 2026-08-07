import XCTest
@testable import DokoWanCafe

/// MapPinCategory のユニットテスト（UI/UXブラッシュアップ設計書 1a, 憲章 原則IV）
final class MapPinCategoryTests: XCTestCase {
    private func makeCafe(
        status: DogPolicyStatus = .allowed,
        amenities: DogAmenities? = nil
    ) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: "テストカフェ",
            latitude: 35.68, longitude: 139.76,
            address: nil, contact: nil,
            dogPolicyStatus: status, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo",
            dogAmenities: amenities
        )
    }

    func test_未確認は設備に関わらず未確認カテゴリが最優先() {
        let cafe = makeCafe(
            status: .unverified,
            amenities: DogAmenities(indoor: true, terrace: true, largeDogs: nil, dogMenu: nil)
        )
        XCTAssertEqual(MapPinCategory.category(for: cafe), .unverified)
    }

    func test_indoorがtrueなら店内OK() {
        let cafe = makeCafe(
            status: .allowed,
            amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil)
        )
        XCTAssertEqual(MapPinCategory.category(for: cafe), .indoorOK)
    }

    func test_indoorとterraceが両方trueなら店内OKが優先() {
        let cafe = makeCafe(
            status: .conditional,
            amenities: DogAmenities(indoor: true, terrace: true, largeDogs: nil, dogMenu: nil)
        )
        XCTAssertEqual(MapPinCategory.category(for: cafe), .indoorOK)
    }

    func test_indoorがfalseでterraceがtrueならテラスOK() {
        let cafe = makeCafe(
            status: .allowed,
            amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil)
        )
        XCTAssertEqual(MapPinCategory.category(for: cafe), .terraceOnly)
    }

    func test_indoorが不明でterraceがtrueならテラスOK() {
        let cafe = makeCafe(
            status: .allowed,
            amenities: DogAmenities(indoor: nil, terrace: true, largeDogs: nil, dogMenu: nil)
        )
        XCTAssertEqual(MapPinCategory.category(for: cafe), .terraceOnly)
    }

    func test_設備情報自体がなければ詳細確認() {
        let cafe = makeCafe(status: .allowed, amenities: nil)
        XCTAssertEqual(MapPinCategory.category(for: cafe), .checkDetail)
    }

    func test_indoorもterraceも不明またはfalseなら詳細確認() {
        let cafe = makeCafe(
            status: .conditional,
            amenities: DogAmenities(indoor: false, terrace: false, largeDogs: nil, dogMenu: nil)
        )
        XCTAssertEqual(MapPinCategory.category(for: cafe), .checkDetail)
    }

    func test_各カテゴリのdisplayName() {
        XCTAssertEqual(MapPinCategory.unverified.displayName, "未確認")
        XCTAssertEqual(MapPinCategory.indoorOK.displayName, "店内OK")
        XCTAssertEqual(MapPinCategory.terraceOnly.displayName, "テラスOK")
        XCTAssertEqual(MapPinCategory.checkDetail.displayName, "詳細確認")
    }
}
