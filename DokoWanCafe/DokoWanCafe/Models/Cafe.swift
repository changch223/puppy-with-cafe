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
