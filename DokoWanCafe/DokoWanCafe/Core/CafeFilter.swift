import Foundation

/// 可否ステータスによる絞り込み（FR-004, 純ロジック・UI非依存, 憲章 原則IV）。
enum CafeFilter {
    /// `selection` に含まれるステータスのカフェのみを返す。
    /// 空集合は「絞り込みなし」として全件を返す（UIを行き止まりにしない）。
    static func apply(_ selection: Set<DogPolicyStatus>, to cafes: [CafeWithDistance]) -> [CafeWithDistance] {
        guard !selection.isEmpty else { return cafes }
        return cafes.filter { selection.contains($0.cafe.dogPolicyStatus) }
    }
}
