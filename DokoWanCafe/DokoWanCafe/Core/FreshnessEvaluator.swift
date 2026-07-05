import Foundation

/// 鮮度評価（FR-010: 最終確認日が既定しきい値（365日）より古い情報には警告を表示する。
/// 純ロジック・UI非依存, 憲章 原則IV）。
enum FreshnessEvaluator {
    static let defaultThresholdDays = 365

    /// 最終確認日がしきい値より古いか。
    /// `lastVerified` が nil（確認日なし）の場合も「古い/不明」として true を返す（FR-009 と整合）。
    static func isStale(
        lastVerified: Date?,
        referenceDate: Date = Date(),
        thresholdDays: Int = defaultThresholdDays
    ) -> Bool {
        guard let lastVerified else { return true }
        let threshold = TimeInterval(thresholdDays) * 24 * 60 * 60
        return referenceDate.timeIntervalSince(lastVerified) > threshold
    }
}
