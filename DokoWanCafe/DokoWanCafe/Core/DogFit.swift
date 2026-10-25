import Foundation

/// うちの子（`DogProfile`）がその店に入れるかの判定（再設計 段階3。純ロジック・UI非依存, 憲章 原則IV）。
///
/// 憲章 原則I: 推測で「うちの子OK」と言わない。データに明記された事実だけで判定し、分からないときは `unknown`。
/// 席（店内・テラス）ごとに 入れると明記（fits）／入れないと明記（doesNotFit）／分からない（unknown）を返し、
/// 店全体は「いずれかの席が fits → fits」「すべての席が doesNotFit → doesNotFit」「それ以外 → unknown」。
/// 過ごし方（`indoor_style`）は網羅的でないため判定には使わず、補足（`matchedStyles`）にだけ使う。
enum DogFit {
    enum Seat: Equatable, Sendable {
        case indoor
        case terrace

        var label: String {
            switch self {
            case .indoor: return String(localized: "店内")
            case .terrace: return String(localized: "テラス")
            }
        }
    }

    /// 入れないと分かる理由
    enum NoReason: Equatable, Sendable {
        /// その席が不可（可否が false）
        case seatNotAllowed
        /// その席のサイズ上限をうちの子が超える
        case sizeLimit(DogSize)
        /// 店そのものが犬同伴不可
        case policyNotAllowed
    }

    /// 分からない理由
    enum UnknownReason: Equatable, Sendable {
        /// 未確認（確認日なしを含む）
        case unverified
        /// その席の可否の記載がない
        case seatNotStated
        /// サイズの記載がない（中型犬・大型犬）
        case sizeNotStated
        /// サイズの条件の文がある（店の説明を読む必要がある）
        case sizeConditionText
    }

    enum Verdict: Equatable, Sendable {
        case fits
        case doesNotFit(NoReason)
        case unknown(UnknownReason)
    }

    enum Overall: Equatable, Sendable {
        case fits
        case doesNotFit
        case unknown
    }

    struct Result: Equatable, Sendable {
        let dog: DogProfile
        let indoor: Verdict
        let terrace: Verdict
        let overall: Overall
        /// うちの子の過ごし方のうち、`indoor_style` に明記されているもの（判定には使わない補足）
        let matchedStyles: [DogStyle]
        /// 店の犬同伴が条件つき（conditional）か。fits でも条件があることを詳細の1行で添える
        let isConditional: Bool
    }

    // MARK: - 判定

    static func evaluate(cafe: Cafe, dog: DogProfile) -> Result {
        // 未確認（確認日なしを含む）は常に「分からない」
        guard CafeDetailAnswer.isConfirmed(cafe) else {
            return Result(
                dog: dog, indoor: .unknown(.unverified), terrace: .unknown(.unverified),
                overall: .unknown, matchedStyles: [], isConditional: false
            )
        }
        if cafe.dogPolicyStatus == .notAllowed {
            return Result(
                dog: dog, indoor: .doesNotFit(.policyNotAllowed), terrace: .doesNotFit(.policyNotAllowed),
                overall: .doesNotFit, matchedStyles: [], isConditional: false
            )
        }

        let amenities = cafe.dogAmenities
        let hasSizeCondition = nonEmpty(cafe.dogSizeLimit) != nil
        // 片方の席にサイズ上限が明記されている店は、大型犬可（large_dogs）がどちらの席の話か分からないため、
        // 上限のないもう片方の席を large_dogs で fits にしない（unknown のまま）
        let anySeatHasLimit = amenities?.sizeMaxIndoor != nil || amenities?.sizeMaxTerrace != nil
        let indoor = seatVerdict(
            allowed: amenities?.indoor, sizeMax: amenities?.sizeMaxIndoor,
            dog: dog, largeDogs: amenities?.largeDogs, hasSizeCondition: hasSizeCondition,
            anySeatHasLimit: anySeatHasLimit
        )
        let terrace = seatVerdict(
            allowed: amenities?.terrace, sizeMax: amenities?.sizeMaxTerrace,
            dog: dog, largeDogs: amenities?.largeDogs, hasSizeCondition: hasSizeCondition,
            anySeatHasLimit: anySeatHasLimit
        )

        let overall: Overall
        if indoor == .fits || terrace == .fits {
            overall = .fits
        } else if case .doesNotFit = indoor, case .doesNotFit = terrace {
            overall = .doesNotFit
        } else {
            overall = .unknown
        }

        let listed = Set(amenities?.indoorStyle ?? [])
        return Result(
            dog: dog, indoor: indoor, terrace: terrace, overall: overall,
            matchedStyles: dog.orderedStyles.filter { listed.contains($0) },
            isConditional: cafe.dogPolicyStatus == .conditional
        )
    }

    /// 1つの席の判定
    private static func seatVerdict(
        allowed: Bool?,
        sizeMax: DogSize?,
        dog: DogProfile,
        largeDogs: Bool?,
        hasSizeCondition: Bool,
        anySeatHasLimit: Bool
    ) -> Verdict {
        // その席の可否が true でなければ: false は不可、nil は分からない
        guard let allowed else { return .unknown(.seatNotStated) }
        guard allowed else { return .doesNotFit(.seatNotAllowed) }

        // 明記されたサイズ上限
        if let sizeMax {
            return dog.size <= sizeMax ? .fits : .doesNotFit(.sizeLimit(sizeMax))
        }
        // 上限の明記がない
        switch dog.size {
        case .small:
            // 犬同伴可の席で小型犬を断る明記がないため入れる。ただしサイズの条件の文がある店は読んでもらう
            return hasSizeCondition ? .unknown(.sizeConditionText) : .fits
        case .medium, .large:
            // large_dogs での補完は、どちらの席にもサイズ上限の明記がない店だけ
            if largeDogs == true, !hasSizeCondition, !anySeatHasLimit { return .fits }
            return .unknown(hasSizeCondition ? .sizeConditionText : .sizeNotStated)
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

/// 判定結果の文言（タグ・行の注記・詳細の1行・VoiceOver）
extension DogFit.Result {
    /// 「うちの子OK」（入れると明記された店だけ）
    var tagLabel: String? {
        overall == .fits ? String(localized: "うちの子OK") : nil
    }

    /// 入れない理由。席ごとに「店内は中型犬まで」「テラスは不可」を「・」でつなぐ。入れない店でなければ nil
    var reasonText: String? {
        guard overall == .doesNotFit else { return nil }
        if case .doesNotFit(.policyNotAllowed) = indoor {
            return String(localized: "犬の同伴は不可")
        }
        let parts = [
            Self.reason(of: indoor, seat: .indoor),
            Self.reason(of: terrace, seat: .terrace),
        ].compactMap { $0 }
        return parts.joined(separator: "・")
    }

    /// 行・カードに灰色で出す注記（「うちの子は不可（店内は中型犬まで）」）。入れない店でなければ nil
    var rowNote: String? {
        reasonText.map { String(localized: "うちの子は不可（\($0)）") }
    }

    /// 詳細の答えのカードの上の1行（「うちの子（小型犬）は：店内で過ごせます」）
    /// 犬同伴が条件つき（conditional）の店で入れると言うときは「（条件あり）」を添える（無条件に見せない）。
    var detailLine: String {
        let name = dog.size.displayName
        let line = String(localized: "うちの子（\(name)）は：\(detailBody)")
        guard overall == .fits, isConditional else { return line }
        // 末尾がすでに括弧（「（店内は不可）」）なら、その中にまとめる（「（店内は不可・条件あり）」）
        if line.hasSuffix("）") {
            return String(line.dropLast()) + String(localized: "・条件あり）")
        }
        return line + String(localized: "（条件あり）")
    }

    /// 詳細の1行の「：」より後ろ
    var detailBody: String {
        switch overall {
        case .fits:
            if indoor == .fits { return String(localized: "店内で過ごせます") }
            if let indoorReason = Self.reason(of: indoor, seat: .indoor) {
                return String(localized: "テラス席なら過ごせます（\(indoorReason)）")
            }
            return String(localized: "テラス席なら過ごせます")
        case .doesNotFit:
            let reason = reasonText ?? ""
            return String(localized: "入れません（\(reason)）")
        case .unknown:
            return unknownBody
        }
    }

    /// 過ごし方の補足（「カート・キャリーでの入店が明記されています」）。
    /// 店内で入れないと分かっているときは出さない（矛盾して見えるため）。
    var styleNote: String? {
        guard !matchedStyles.isEmpty else { return nil }
        if case .doesNotFit = indoor { return nil }
        let names = matchedStyles.map(\.admissionLabel).joined(separator: "、")
        return String(localized: "\(names)での入店が明記されています")
    }

    private var unknownBody: String {
        let reasons = [indoor, terrace].compactMap { verdict -> DogFit.UnknownReason? in
            if case .unknown(let reason) = verdict { return reason }
            return nil
        }
        if reasons.contains(.unverified) {
            return String(localized: "まだ確認できていないため、来店前に確認を")
        }
        if reasons.contains(.sizeNotStated) {
            return String(localized: "サイズの記載がないため、来店前に確認を")
        }
        if reasons.contains(.sizeConditionText) {
            return String(localized: "サイズの条件があるため、来店前に確認を")
        }
        return String(localized: "席の種類の記載がないため、来店前に確認を")
    }

    /// 入れない席の理由（「店内は不可」「テラスは中型犬まで」）。入れないと分かっていない席は nil
    private static func reason(of verdict: DogFit.Verdict, seat: DogFit.Seat) -> String? {
        guard case .doesNotFit(let reason) = verdict else { return nil }
        let label = seat.label
        switch reason {
        case .seatNotAllowed: return String(localized: "\(label)は不可")
        case .sizeLimit(let max):
            let size = max.displayName
            return String(localized: "\(label)は\(size)まで")
        case .policyNotAllowed: return String(localized: "犬の同伴は不可")
        }
    }
}
