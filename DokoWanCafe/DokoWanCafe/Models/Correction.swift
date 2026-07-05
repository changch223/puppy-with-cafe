import Foundation

/// 修正提案（data-model.md: Correction）。
/// 送信直後は `pending`（審査中）であり、運営承認（v1）まで表示に反映されない（FR-024）。
struct Correction: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var cafeID: UUID
    var submitterType: SubmitterType
    var submitterID: UUID?
    var proposedStatus: DogPolicyStatus?
    var proposedCondition: String?
    var note: String?
    var status: CorrectionStatus
    var operatorReview: String?
    var appliedAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case cafeID = "cafe_id"
        case submitterType = "submitter_type"
        case submitterID = "submitter_id"
        case proposedStatus = "proposed_status"
        case proposedCondition = "proposed_condition"
        case note
        case status
        case operatorReview = "operator_review"
        case appliedAt = "applied_at"
        case createdAt = "created_at"
    }
}

/// 修正提案の送信ペイロード（corrections への insert。RLS により認証必須）
struct CorrectionPayload: Encodable, Sendable {
    let cafeID: UUID
    let submitterType: String
    let submitterID: UUID
    let proposedStatus: String?
    let proposedCondition: String?
    let note: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case cafeID = "cafe_id"
        case submitterType = "submitter_type"
        case submitterID = "submitter_id"
        case proposedStatus = "proposed_status"
        case proposedCondition = "proposed_condition"
        case note
        case status
    }
}
