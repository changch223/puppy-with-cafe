import Foundation

/// 犬同伴可否ステータス（FR-006）。憶測で `allowed` にしない（憲章 原則I）。
enum DogPolicyStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case allowed
    case conditional
    case notAllowed = "not_allowed"
    case unverified

    var id: String { rawValue }

    /// 一覧・地図・詳細で共通に使う表示名（日本語ファースト, FR-019）
    var displayName: String {
        switch self {
        case .allowed: return String(localized: "犬OK")
        case .conditional: return String(localized: "条件付き")
        case .notAllowed: return String(localized: "犬不可")
        case .unverified: return String(localized: "未確認")
        }
    }
}

/// 出典の種別（data-model.md: SourceType）
enum SourceType: String, Codable, CaseIterable, Sendable {
    case officialHP = "official_hp"
    case sns
    case googleMap = "google_map"
    case tabelog
    case blog
    case other

    var displayName: String {
        switch self {
        case .officialHP: return String(localized: "公式HP")
        case .sns: return String(localized: "SNS")
        case .googleMap: return String(localized: "Google Map")
        case .tabelog: return String(localized: "食べログ")
        case .blog: return String(localized: "ブログ")
        case .other: return String(localized: "その他")
        }
    }
}

/// 情報の由来（provenance）。AI推測は確定情報と明確に区別する（FR-012, 憲章 原則I）。
enum Provenance: String, Codable, CaseIterable, Sendable {
    case official
    case operatorVerified = "operator_verified"
    case humanVerified = "human_verified"
    case userSubmittedVerified = "user_submitted_verified"
    case aggregated
    case aiInferred = "ai_inferred"

    /// FR-013 の信頼順（大きいほど信頼できる）。公式・運営確認は同格の最上位。
    var trustRank: Int {
        switch self {
        case .official, .operatorVerified: return 5
        case .humanVerified: return 4
        case .userSubmittedVerified: return 3
        case .aggregated: return 2
        case .aiInferred: return 1
        }
    }

    var isAIInferred: Bool { self == .aiInferred }

    var displayName: String {
        switch self {
        case .official: return String(localized: "公式")
        case .operatorVerified: return String(localized: "運営確認")
        case .humanVerified: return String(localized: "人手確認")
        case .userSubmittedVerified: return String(localized: "利用者提案(検証済み)")
        case .aggregated: return String(localized: "外部集約")
        case .aiInferred: return String(localized: "AI推測")
        }
    }
}

/// 修正提案の審査状態（FR-027）。`applied` 以外は表示に反映されない。
enum CorrectionStatus: String, Codable, Sendable {
    case pending
    case aiChecked = "ai_checked"
    case operatorChecked = "operator_checked"
    case applied
    case rejected

    var displayName: String {
        switch self {
        case .pending: return String(localized: "審査中")
        case .aiChecked: return String(localized: "AI確認済み")
        case .operatorChecked: return String(localized: "運営確認済み")
        case .applied: return String(localized: "反映済み")
        case .rejected: return String(localized: "却下")
        }
    }
}

/// 修正提案の送信者種別
enum SubmitterType: String, Codable, Sendable {
    case user
    case `operator`
}
