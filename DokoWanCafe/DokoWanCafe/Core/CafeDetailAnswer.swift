import Foundation

/// 店詳細の「答えのカード」の判定（再設計 段階1b。純ロジック・UI非依存, 憲章 原則IV）。
/// 憲章 原則I: 推測で「入れる」と言わない。`indoor` が nil なら「店内で一緒に…」は出さない。
struct CafeDetailAnswer: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// 店内に入れる（indoor == true）
        case indoor
        /// 店内は不可または不明で、テラスが可
        case terrace
        /// 条件つきで可（店内・テラスのどちらにも当たらない）
        case conditional
        /// 可だが席の種類（店内/テラス）の情報がない
        case seatUnknown
        /// 犬同伴不可
        case notAllowed
        /// 未確認
        case unverified
    }

    let kind: Kind
    /// 1行目（大きく見せる一文）
    let headline: String
    /// 2行目の条件の要点（dogPolicyCondition）
    let conditionLine: String?
    /// 3行目のサイズ制限（dogSizeLimit。条件の要点と同文なら nil にして1回だけ出す）
    let sizeLimitLine: String?
    /// 添え書き（「大型犬もOK」「店内は不可」など）
    let notes: [String]

    /// 確認済みの情報か。未確認、または確認日（lastVerified）が無い店は確認済みとして扱わない
    /// （憲章 原則I: 確認の記録が無い情報を「可」と主張しない）。
    static func isConfirmed(_ cafe: Cafe) -> Bool {
        cafe.dogPolicyStatus != .unverified && cafe.lastVerified != nil
    }

    static func make(cafe: Cafe) -> CafeDetailAnswer {
        // 未確認（確認日なしを含む）は他の情報より先に判定する（MapPinCategory と同じ。未確認を可と主張しない）
        if !isConfirmed(cafe) {
            return CafeDetailAnswer(
                kind: .unverified,
                headline: String(localized: "犬同伴の情報を確認中です"),
                conditionLine: nil,
                sizeLimitLine: nil,
                notes: []
            )
        }
        if cafe.dogPolicyStatus == .notAllowed {
            return CafeDetailAnswer(
                kind: .notAllowed,
                headline: String(localized: "犬の同伴はできません"),
                conditionLine: nil,
                sizeLimitLine: nil,
                notes: []
            )
        }

        let amenities = cafe.dogAmenities
        let condition = nonEmpty(cafe.dogPolicyCondition)
        let sizeLimit = nonEmpty(cafe.dogSizeLimit)
        var notes: [String] = []

        let kind: Kind
        let headline: String
        if amenities?.indoor == true {
            kind = .indoor
            headline = String(localized: "店内で一緒に過ごせます")
        } else {
            if amenities?.terrace == true {
                kind = .terrace
                headline = String(localized: "テラス席で一緒に過ごせます")
            } else if cafe.dogPolicyStatus == .conditional {
                kind = .conditional
                headline = String(localized: "条件つきで一緒に入れます")
            } else {
                kind = .seatUnknown
                headline = String(localized: "犬連れで利用できます")
            }
            // 店内が明確に不可なら、どの見出しでも「店内は不可」を添える
            if amenities?.indoor == false {
                notes.append(String(localized: "店内は不可"))
            } else if kind == .seatUnknown {
                // indoor が不明のときだけ「席の種類は確認中」（店内不可が分かっているときは書かない）
                notes.append(String(localized: "席の種類は確認中"))
            }
        }

        // サイズ制限の記載がある店では「大型犬もOK」と言い切らない（例: 大型犬はテラス席のみ）
        if amenities?.largeDogs == true, sizeLimit == nil {
            notes.append(String(localized: "大型犬もOK"))
        }
        return CafeDetailAnswer(
            kind: kind,
            headline: headline,
            conditionLine: condition,
            sizeLimitLine: sizeLimit == condition ? nil : sizeLimit,
            notes: notes
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

/// 答えのカード最下段の「根拠」1行（再設計 段階1b）。
/// 例: 「公式サイトで確認・2026年8月」。出典に食い違いがある店は `hasConflict` を立てる（橙で添える）。
struct CafeDetailEvidence: Equatable, Sendable {
    let text: String
    /// 「出典に食い違いあり」を橙で添えるか
    let hasConflict: Bool
    /// 文そのものが食い違いの警告か（その場合は文を橙で出し、「出典に食い違いあり」は重ねない）
    let textIsWarning: Bool

    static func make(
        sourceType: SourceType?,
        lastVerified: Date?,
        hasConflict: Bool,
        timeZone: TimeZone = OpeningHoursEvaluator.tokyoTimeZone
    ) -> CafeDetailEvidence {
        let month = lastVerified.map { yearMonthText($0, timeZone: timeZone) }
        let text: String
        switch (sourceType, month) {
        case let (type?, month?):
            text = String(localized: "\(typeLabel(type))で確認・\(month)")
        case let (type?, nil):
            text = String(localized: "\(typeLabel(type))で確認（確認日の記録なし）")
        case let (nil, month?):
            text = String(localized: "\(month)に確認")
        case (nil, nil):
            // 確認の記録が無く、出典どうしが食い違っている店は「記録なし」ではなく食い違いを伝える
            if hasConflict {
                return CafeDetailEvidence(
                    text: String(localized: "出典の記載が食い違っています"),
                    hasConflict: false,
                    textIsWarning: true
                )
            }
            text = String(localized: "確認の記録がありません")
        }
        return CafeDetailEvidence(text: text, hasConflict: hasConflict, textIsWarning: false)
    }

    /// 代表出典の種類の表示名（公式サイト／公式SNS／食べログ／ブログ／その他）
    static func typeLabel(_ type: SourceType) -> String {
        switch type {
        case .officialHP: return String(localized: "公式サイト")
        case .sns: return String(localized: "公式SNS")
        case .tabelog: return String(localized: "食べログ")
        case .blog: return String(localized: "ブログ")
        case .googleMap, .other: return String(localized: "その他の出典")
        }
    }

    /// 「2026年8月」（ロケール・端末設定に依存しない固定書式）
    static func yearMonthText(_ date: Date, timeZone: TimeZone = OpeningHoursEvaluator.tokyoTimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)年\(parts.month ?? 0)月"
    }
}
