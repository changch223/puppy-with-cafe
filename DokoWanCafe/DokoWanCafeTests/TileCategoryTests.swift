import XCTest
@testable import DokoWanCafe

/// 写真のない店のタイルの分類が、うちの子の判定（答えの行）と食い違わないこと（原則I）。
final class TileCategoryTests: XCTestCase {
    private func makeCafe(
        indoor: Bool? = nil,
        terrace: Bool? = nil,
        sizeIndoor: DogSize? = nil,
        sizeTerrace: DogSize? = nil
    ) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: "テストカフェ",
            latitude: 35.68, longitude: 139.76,
            address: nil, contact: nil,
            dogPolicyStatus: .conditional, dogPolicyCondition: nil,
            lastVerified: Date(timeIntervalSince1970: 1_780_000_000), representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo",
            dogAmenities: DogAmenities(
                indoor: indoor, terrace: terrace, largeDogs: nil, dogMenu: nil,
                sizeMaxIndoor: sizeIndoor, sizeMaxTerrace: sizeTerrace, indoorStyle: nil
            ),
            dogSizeLimit: nil
        )
    }

    func test_うちの子が未設定ならピンと同じ分類() {
        let cafe = makeCafe(indoor: true, sizeIndoor: .small)
        XCTAssertEqual(CafePresentation.tileCategory(for: cafe, dog: nil), .indoorOK)
    }

    func test_店内が小型犬までの店は_中型犬なら店内OKと言わず条件を確認() {
        let cafe = makeCafe(indoor: true, terrace: nil, sizeIndoor: .small)
        XCTAssertEqual(MapPinCategory.category(for: cafe), .indoorOK)
        XCTAssertEqual(CafePresentation.tileCategory(for: cafe, dog: DogProfile(size: .medium)), .checkDetail)
        // 小型犬なら店内に入れると明記されているのでそのまま
        XCTAssertEqual(CafePresentation.tileCategory(for: cafe, dog: DogProfile(size: .small)), .indoorOK)
    }

    func test_店内に入れなくてもテラスに入れると明記されていればテラス() {
        let cafe = makeCafe(indoor: true, terrace: true, sizeIndoor: .small)
        XCTAssertEqual(CafePresentation.tileCategory(for: cafe, dog: DogProfile(size: .large)), .terraceOnly)
    }

    func test_テラスの席に入れないと明記されたテラスの店は条件を確認() {
        let cafe = makeCafe(indoor: nil, terrace: true, sizeTerrace: .small)
        XCTAssertEqual(MapPinCategory.category(for: cafe), .terraceOnly)
        XCTAssertEqual(CafePresentation.tileCategory(for: cafe, dog: DogProfile(size: .large)), .checkDetail)
    }

    func test_分からないだけなら分類は変えない() {
        let cafe = makeCafe(indoor: true)
        XCTAssertEqual(CafePresentation.tileCategory(for: cafe, dog: DogProfile(size: .large)), .indoorOK)
    }
}
