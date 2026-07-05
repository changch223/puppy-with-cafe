import Foundation

/// 出典（data-model.md: Source）。全情報は出典・確認日・由来を保持する（憲章 原則I, FR-008）。
struct Source: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var cafeID: UUID
    var type: SourceType
    var reference: String?
    var claimedStatus: DogPolicyStatus
    var verifiedAt: Date?
    var provenance: Provenance

    enum CodingKeys: String, CodingKey {
        case id
        case cafeID = "cafe_id"
        case type
        case reference
        case claimedStatus = "claimed_status"
        case verifiedAt = "verified_at"
        case provenance
    }

    var referenceURL: URL? {
        guard let reference, let url = URL(string: reference), url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }
}

/// カフェ詳細（カフェ本体＋関連出典。contracts/api-contracts.md #2）
struct CafeDetail: Decodable, Equatable, Sendable {
    let cafe: Cafe
    let sources: [Source]

    private enum CodingKeys: String, CodingKey {
        case sources
    }

    init(cafe: Cafe, sources: [Source]) {
        self.cafe = cafe
        self.sources = sources
    }

    init(from decoder: Decoder) throws {
        self.cafe = try Cafe(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sources = try container.decodeIfPresent([Source].self, forKey: .sources) ?? []
    }
}
