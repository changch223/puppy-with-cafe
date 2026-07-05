import Foundation

/// 修正提案の送信（FR-023/024/028, contracts/api-contracts.md #5）。
/// 送信された提案は `pending`（審査中）となり、運営承認（v1）まで表示に反映されない。
@MainActor
final class CorrectionService: ObservableObject {
    private let gateway: SupabaseGateway?
    private let auth: AuthService

    init(gateway: SupabaseGateway?, auth: AuthService) {
        self.gateway = gateway
        self.auth = auth
    }

    /// バックエンド設定済みかどうか（サンプルモードでは送信不可）
    var isAvailable: Bool { gateway != nil }

    func submit(
        cafeID: UUID,
        proposedStatus: DogPolicyStatus?,
        proposedCondition: String?,
        note: String?
    ) async throws -> Correction {
        guard let gateway else { throw SupabaseError.notConfigured }
        guard let session = auth.session else { throw SupabaseError.notSignedIn }

        let payload = CorrectionPayload(
            cafeID: cafeID,
            submitterType: SubmitterType.user.rawValue,
            submitterID: session.userID,
            proposedStatus: proposedStatus?.rawValue,
            proposedCondition: normalized(proposedCondition),
            note: normalized(note),
            status: CorrectionStatus.pending.rawValue
        )

        let rows: [Correction] = try await gateway.insertReturning("corrections", body: payload)
        guard let correction = rows.first else { throw SupabaseError.emptyResponse }
        return correction
    }

    private func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
