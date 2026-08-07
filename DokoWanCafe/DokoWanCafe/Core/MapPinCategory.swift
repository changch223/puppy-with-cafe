import Foundation

/// 地図ピンの犬目線分類（UI/UXブラッシュアップ設計書 1a）。
/// 純ロジック・UI非依存（憲章 原則IV）。色・アイコンの実マッピングは呼び出し側（MapViewModel等）で行う。
enum MapPinCategory: Equatable, Sendable {
    /// 未確認（既定では地図・一覧に出ない。原則I: 未確認を可と主張しない）
    case unverified
    /// 店内OK
    case indoorOK
    /// テラスのみOK
    case terraceOnly
    /// 可・条件付きだが席種が不明 → 詳細確認を促す
    case checkDetail

    /// 一覧・地図・詳細で共通に使う表示名（日本語ファースト）
    var displayName: String {
        switch self {
        case .unverified: return String(localized: "未確認")
        case .indoorOK: return String(localized: "店内OK")
        case .terraceOnly: return String(localized: "テラスOK")
        case .checkDetail: return String(localized: "詳細確認")
        }
    }

    /// カフェの犬同伴可否・設備情報から優先順で判定する。
    /// 1. `dogPolicyStatus == .unverified` → `.unverified`
    /// 2. `dogAmenities?.indoor == true` → `.indoorOK`
    /// 3. `dogAmenities?.terrace == true` → `.terraceOnly`
    /// 4. それ以外（可・条件付きだが席種不明） → `.checkDetail`
    static func category(for cafe: Cafe) -> MapPinCategory {
        if cafe.dogPolicyStatus == .unverified {
            return .unverified
        }
        if cafe.dogAmenities?.indoor == true {
            return .indoorOK
        }
        if cafe.dogAmenities?.terrace == true {
            return .terraceOnly
        }
        return .checkDetail
    }
}
