import Foundation

/// 矛盾解決の結果（FR-013）
struct ConflictResolution: Equatable, Sendable {
    /// 代表として表示する可否ステータス
    let status: DogPolicyStatus
    /// 代表可否の根拠となった出典（確定できない場合は nil）
    let representativeSource: Source?
    /// 出典間で可否が食い違っているか（FR-011 の提示に使用）
    let hasConflict: Bool
}

/// 矛盾解決（FR-013, 純ロジック・UI非依存, 憲章 原則IV）。
/// 決定順:
///   (1) 最終確認日が最も新しい出典を優先
///   (2) 確認日が同一/不明なら由来の信頼順（公式・運営確認 > 人手確認 > 利用者提案(検証済み) > 外部集約 > AI推測）
///   (3) それでも確定できない場合は「未確認」— 憶測で「可」にしない（憲章 原則I）
enum ConflictResolver {
    static func resolve(sources: [Source]) -> ConflictResolution {
        // 可否を主張しない（unverified を主張する）出典は判定対象外
        let meaningful = sources.filter { $0.claimedStatus != .unverified }

        guard !meaningful.isEmpty else {
            // 出典なし・すべて未確認 → 未確認（FR-009）
            return ConflictResolution(status: .unverified, representativeSource: nil, hasConflict: false)
        }

        let distinctStatuses = Set(meaningful.map(\.claimedStatus))
        let hasConflict = distinctStatuses.count > 1

        // (1) 確認日（無しは最古扱い）→ (2) 信頼順 の優先度で並べる
        let sorted = meaningful.sorted { lhs, rhs in
            let lhsDate = lhs.verifiedAt ?? .distantPast
            let rhsDate = rhs.verifiedAt ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.provenance.trustRank > rhs.provenance.trustRank
        }

        guard let top = sorted.first else {
            return ConflictResolution(status: .unverified, representativeSource: nil, hasConflict: hasConflict)
        }

        // (3) 最上位と同じ「確認日・信頼順」の出典同士で可否が割れている場合は確定できない → 未確認
        let topDate = top.verifiedAt ?? .distantPast
        let peers = sorted.filter {
            ($0.verifiedAt ?? .distantPast) == topDate && $0.provenance.trustRank == top.provenance.trustRank
        }
        let peerStatuses = Set(peers.map(\.claimedStatus))
        if peerStatuses.count > 1 {
            return ConflictResolution(status: .unverified, representativeSource: nil, hasConflict: true)
        }

        return ConflictResolution(status: top.claimedStatus, representativeSource: top, hasConflict: hasConflict)
    }
}
