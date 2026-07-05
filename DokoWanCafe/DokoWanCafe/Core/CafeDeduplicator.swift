import Foundation

/// 名寄せ（FR-030, research.md R6, 純ロジック・UI非依存, 憲章 原則IV）。
/// 同一カフェの識別: place_id が一致すれば同一。place_id が無い場合は
/// 「正規化した名称の一致」かつ「位置近接（既定50m）」で同一とみなし統合する。
enum CafeDeduplicator {
    static let defaultProximityMeters: Double = 50

    /// 重複を統合した配列を返す。統合時は情報の新しい方（最終確認日が新しい方）を残す。
    static func deduplicate(_ cafes: [Cafe], proximityMeters: Double = defaultProximityMeters) -> [Cafe] {
        var kept: [Cafe] = []

        for candidate in cafes {
            if let index = kept.firstIndex(where: { isSameCafe($0, candidate, proximityMeters: proximityMeters) }) {
                kept[index] = preferred(kept[index], candidate)
            } else {
                kept.append(candidate)
            }
        }
        return kept
    }

    /// 2件が同一カフェか判定する。
    static func isSameCafe(_ lhs: Cafe, _ rhs: Cafe, proximityMeters: Double = defaultProximityMeters) -> Bool {
        // 1) place_id が双方にあれば、それだけで判定（FR-030: 主キー）
        if let lhsID = lhs.placeID, let rhsID = rhs.placeID {
            return lhsID == rhsID
        }
        // 2) 正規化名称の一致 ＋ 位置近接
        guard normalizedName(lhs.name) == normalizedName(rhs.name) else { return false }
        let distance = DistanceCalculator.distanceMeters(
            fromLatitude: lhs.latitude, fromLongitude: lhs.longitude,
            toLatitude: rhs.latitude, toLongitude: rhs.longitude
        )
        return distance <= proximityMeters
    }

    /// 名称の正規化: 前後空白除去・小文字化・全角/半角の統一（NFKC）・空白除去
    static func normalizedName(_ name: String) -> String {
        let folded = name
            .precomposedStringWithCompatibilityMapping // NFKC: 全角英数・半角カナ等を統一
            .lowercased()
        return folded.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    /// 統合時にどちらを残すか: 最終確認日が新しい方（同等なら情報量が多い方）
    private static func preferred(_ lhs: Cafe, _ rhs: Cafe) -> Cafe {
        let lhsDate = lhs.lastVerified ?? .distantPast
        let rhsDate = rhs.lastVerified ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate ? lhs : rhs
        }
        return infoCount(lhs) >= infoCount(rhs) ? lhs : rhs
    }

    private static func infoCount(_ cafe: Cafe) -> Int {
        [cafe.placeID, cafe.address, cafe.contact, cafe.dogPolicyCondition].compactMap { $0 }.count
    }
}
