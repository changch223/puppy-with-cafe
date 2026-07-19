import Foundation

/// カフェ（data-model.md: Cafe）。
/// 代表可否 `dogPolicyStatus`・最終確認日・矛盾フラグはサーバ側で FR-013 に従って算出された値。
struct Cafe: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var placeID: String?
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String?
    var contact: String?
    var dogPolicyStatus: DogPolicyStatus
    var dogPolicyCondition: String?
    var lastVerified: Date?
    var representativeSourceID: UUID?
    var hasConflict: Bool
    var isClosed: Bool
    var area: String

    // 002-cafe-rich-info: 追加情報（すべて任意・後方互換, FR-101/107）
    var subArea: String?
    var description: String?
    var phone: String?
    var reservation: String?
    var hoursText: String?
    var holidayNote: String?
    var hours: OpeningHours?
    var links: [CafeLink]?
    var dogAmenities: DogAmenities?
    var dogSizeLimit: String?
    var dogNote: String?
    var infoVerified: Date?
    var operatorNote: OperatorNote?

    // 写真・雰囲気機能: IG投稿埋め込み用の代表投稿URL（任意・後方互換）
    var instagramPostURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case placeID = "place_id"
        case name
        case latitude
        case longitude
        case address
        case contact
        case dogPolicyStatus = "dog_policy_status"
        case dogPolicyCondition = "dog_policy_condition"
        case lastVerified = "last_verified"
        case representativeSourceID = "representative_source_id"
        case hasConflict = "has_conflict"
        case isClosed = "is_closed"
        case area
        case subArea = "sub_area"
        case description
        case phone
        case reservation
        case hoursText = "hours_text"
        case holidayNote = "holiday_note"
        case hours
        case links
        case dogAmenities = "dog_amenities"
        case dogSizeLimit = "dog_size_limit"
        case dogNote = "dog_note"
        case infoVerified = "info_verified"
        case operatorNote = "operator_note"
        case instagramPostURL = "instagram_post_url"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 周辺検索の1件（`nearby_cafes` RPC の戻り値。contracts/api-contracts.md #1）
/// 距離はサーバ算出値。オフラインキャッシュ（FR-029）のため Codable。
struct CafeWithDistance: Codable, Identifiable, Equatable, Sendable {
    let cafe: Cafe
    let distanceMeters: Double

    var id: UUID { cafe.id }

    enum CodingKeys: String, CodingKey {
        case cafe
        case distanceMeters = "distance_m"
    }
}
