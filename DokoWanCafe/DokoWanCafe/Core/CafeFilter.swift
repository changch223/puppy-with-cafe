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

/// 犬向け条件のトグル（UI/UXブラッシュアップ設計書 1b）。
/// 各トグルは AND 結合。`true` のトグルのみ、該当amenityが `true` の店を通す
/// （`nil`=不明は通さない。憶測で条件を満たしたことにしない）。
struct AmenityFilter: Equatable, Sendable {
    var indoorOnly = false
    var terraceOnly = false
    var dogMenuOnly = false

    /// いずれのトグルもオフ（絞り込みなし）
    var isEmpty: Bool { !indoorOnly && !terraceOnly && !dogMenuOnly }
}

/// 一覧・地図の並び順（UI/UXブラッシュアップ設計書 1b）
enum CafeSortOrder: Equatable, Sendable {
    /// 距離昇順（既定）
    case distance
    /// 最終確認日（`lastVerified`）が新しい順。未確認（nil）は末尾
    case recentlyVerified
}

extension CafeFilter {
    /// 犬向け条件＋未確認の表示可否で絞り込む（UI/UXブラッシュアップ設計書 1b, FR-004改訂）。
    /// - Parameters:
    ///   - amenities: 店内OK/テラスOK/犬メニューのトグル（AND結合）
    ///   - includeUnverified: `false`（既定）なら未確認ステータスの店を除外する
    static func apply(
        amenities: AmenityFilter,
        includeUnverified: Bool = false,
        to cafes: [CafeWithDistance]
    ) -> [CafeWithDistance] {
        cafes.filter { item in
            // 犬不可(not_allowed)は常時除外する（トグルでも表示しない）。
            // 本アプリは犬同伴OK店のみを扱うデータ方針であり（実データは不可0件）、
            // 将来 not_allowed が入っても既定フィルタを素通りして
            // MapPinCategory が犬OK系（緑/青/橙）に誤分類されることを防ぐガード。
            if item.cafe.dogPolicyStatus == .notAllowed {
                return false
            }
            if !includeUnverified && item.cafe.dogPolicyStatus == .unverified {
                return false
            }
            if amenities.indoorOnly && item.cafe.dogAmenities?.indoor != true {
                return false
            }
            if amenities.terraceOnly && item.cafe.dogAmenities?.terrace != true {
                return false
            }
            if amenities.dogMenuOnly && item.cafe.dogAmenities?.dogMenu != true {
                return false
            }
            return true
        }
    }

    /// 指定した並び順でソートする（UI/UXブラッシュアップ設計書 1b）。
    static func sorted(_ cafes: [CafeWithDistance], by order: CafeSortOrder) -> [CafeWithDistance] {
        switch order {
        case .distance:
            return cafes.sorted { $0.distanceMeters < $1.distanceMeters }
        case .recentlyVerified:
            return cafes.sorted { lhs, rhs in
                switch (lhs.cafe.lastVerified, rhs.cafe.lastVerified) {
                case let (l?, r?): return l > r
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                }
            }
        }
    }
}
