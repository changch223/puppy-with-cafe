import Foundation

/// 行・カードの表示用に店から取り出す要点（純ロジック）
enum CafePresentation {
    /// 「大型犬OK」を出す前提条件。`largeDogs == true` でも `dogSizeLimit`（サイズの条件）が書かれている店は
    /// 条件つきなので出さない（詳細画面と同じ規則）。
    static func showsLargeDogTag(for cafe: Cafe) -> Bool {
        guard cafe.dogAmenities?.largeDogs == true else { return false }
        let limit = cafe.dogSizeLimit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return limit.isEmpty
    }

    // MARK: - 答えの1行（一覧の行・ピンのカード）

    /// 行・カードの「答え」1行。主文（色つき）と補足（薄い色・1つまで）、色の種類を返す（再設計 第1弾）。
    /// データに明記されたことだけを言う（憲章 原則I）。うちの子の判定は `DogFit` に任せ、言い回しもそれに合わせる。
    struct AnswerLine: Equatable {
        /// 色の種類。色だけに頼らず主文でも区別できる
        enum Tone: Equatable {
            /// 店内OK（ブランド色）
            case indoor
            /// テラス（青）
            case terrace
            /// 条件を確認・うちの子が入れるか分からない（橙）
            case attention
            /// 未確認（グレー）
            case unverified
            /// うちの子は入れないと明記（薄い文字色）
            case notAllowed
        }

        let main: String
        let supplement: String?
        let tone: Tone

        /// 画面に出す1行（「うちの子は店内OK・床で待てる」）
        var text: String {
            guard let supplement else { return main }
            return String(localized: "\(main)・\(supplement)")
        }

        /// VoiceOver 用（主文と補足を続けて読む）
        var spoken: String {
            guard let supplement else { return main }
            return String(localized: "\(main)、\(supplement)")
        }
    }

    static func answerLine(for cafe: Cafe, dog: DogProfile? = nil) -> AnswerLine {
        let category = MapPinCategory.category(for: cafe)
        let amenities = cafe.dogAmenities
        let conditional = cafe.dogPolicyStatus == .conditional
        // 過ごし方（indoor_style）は店内の話。店内が不可と分かる店・未確認の店には添えない
        let indoorStyleAllowed = category != .unverified && amenities?.indoor != false

        if let dog {
            // うちの子が設定済みのときは、主文がその子への答え。「大型犬OK」の補足は出さない
            let fit = DogFit.evaluate(cafe: cafe, dog: dog)
            switch fit.overall {
            case .fits:
                let isIndoor = fit.indoor == .fits
                let base = isIndoor ? String(localized: "うちの子は店内OK") : String(localized: "うちの子はテラスならOK")
                let main = conditional ? String(localized: "\(base)（条件あり）") : base
                // うちの子が使うと明記された過ごし方
                let style = isIndoor ? fit.matchedStyles.first : nil
                return AnswerLine(main: main, supplement: style?.displayName, tone: isIndoor ? .indoor : .terrace)
            case .doesNotFit:
                return AnswerLine(main: fit.rowNote ?? String(localized: "うちの子は不可"), supplement: nil, tone: .notAllowed)
            case .unknown:
                // 判定できない店は、席の種類だけを補足で伝える（推測で入れるとは言わない）
                let seat: String?
                switch category {
                case .indoorOK: seat = String(localized: "店内OKの店")
                case .terraceOnly:
                    seat = amenities?.indoor == false ? String(localized: "テラスのみの店") : String(localized: "テラスOKの店")
                case .checkDetail, .unverified: seat = nil
                }
                // 補足が「OK」と言う席に、うちの子は入れないと明記されているときは、その理由を補足にする
                // （「店内OKの店」と言うと入れるように読めるため。例: 店内は小型犬まで・テラスは記載なしの店に中型犬）
                let claimedSeat: DogFit.Verdict? = category == .indoorOK ? fit.indoor : (category == .terraceOnly ? fit.terrace : nil)
                var supplement = seat
                if let claimedSeat, case .doesNotFit = claimedSeat {
                    supplement = fit.notAllowedSeatsText ?? seat
                }
                return AnswerLine(
                    main: String(localized: "うちの子は分かりません"), supplement: supplement,
                    tone: category == .unverified ? .unverified : .attention
                )
            }
        }

        switch category {
        case .indoorOK:
            let main = conditional ? String(localized: "店内OK（条件あり）") : String(localized: "店内OK")
            // 過ごし方は並びを固定（床→カート・キャリー→抱っこ）して先頭の1つ。なければ大型犬OK
            let style = indoorStyleAllowed
                ? DogStyle.allCases.first { amenities?.indoorStyle?.contains($0) == true } : nil
            return AnswerLine(main: main, supplement: style?.displayName ?? largeDogSupplement(for: cafe, seat: .indoor), tone: .indoor)
        case .terraceOnly:
            // 「のみ」は店内が不可と分かる店だけ（不明なら断定しない）
            let base = amenities?.indoor == false ? String(localized: "テラスのみOK") : String(localized: "テラスならOK")
            let main = conditional ? String(localized: "\(base)（条件あり）") : base
            return AnswerLine(main: main, supplement: largeDogSupplement(for: cafe, seat: .terrace), tone: .terrace)
        case .checkDetail:
            // 席を言わない答えには「大型犬OK」を添えない
            return AnswerLine(main: String(localized: "条件を確認"), supplement: nil, tone: .attention)
        case .unverified:
            return AnswerLine(main: String(localized: "未確認"), supplement: nil, tone: .unverified)
        }
    }

    /// 「大型犬OK」の補足（うちの子が未設定のときだけ）。主文が指す席を大型犬で `DogFit` 評価して入れると明記される店に限る
    /// （`large_dogs` だけでは席のサイズ上限と食い違うことがあるため。`DogFit` と同じ判定にそろえる）。
    private static func largeDogSupplement(for cafe: Cafe, seat: DogFit.Seat) -> String? {
        guard showsLargeDogTag(for: cafe) else { return nil }
        let fit = DogFit.evaluate(cafe: cafe, dog: DogProfile(size: .large))
        let verdict = seat == .indoor ? fit.indoor : fit.terrace
        return verdict == .fits ? String(localized: "大型犬OK") : nil
    }

    /// 条件の要点。`dogPolicyCondition`、なければ `dogSizeLimit`。空文字は無いものとして扱う。
    static func conditionSummary(for cafe: Cafe) -> String? {
        for candidate in [cafe.dogPolicyCondition, cafe.dogSizeLimit] {
            if let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return text
            }
        }
        return nil
    }

    /// 未確認 or 最終確認から1年超（行の鮮度警告）
    static func showsFreshnessWarning(for cafe: Cafe, now: Date = Date()) -> Bool {
        cafe.dogPolicyStatus == .unverified
            || FreshnessEvaluator.isStale(lastVerified: cafe.lastVerified, referenceDate: now)
    }

    /// 行・カードのVoiceOver用ラベル。「店名、答え、営業、距離」の順に1つにまとめる
    /// （例: 「店名、店内OK、営業中19時まで、徒歩約7分、情報が古い可能性があります」）。
    /// - Parameters:
    ///   - date: 営業の判定に使う時刻（今、または「いつ行く？」の対象時刻）
    ///   - isTargetTime: `date` が対象時刻か（営業を「土 12:00 は営業中…」の言い方で読む）
    ///   - clock: 「情報が古い可能性」の判定に使う「今」。対象時刻ではなく今で判定する。省略時は `date`
    ///   - caption: 保存タブの「10/25 に行った」など、名前に続けて読む一言
    ///   - dog: うちの子の設定（あれば答えが「うちの子は店内OK」などになる）
    static func accessibilityLabel(
        for item: CafeWithDistance,
        savedStatus: SavedStatus? = nil,
        at date: Date = Date(),
        isTargetTime: Bool = false,
        clock: Date? = nil,
        caption: String? = nil,
        dog: DogProfile? = nil
    ) -> String {
        var parts = [item.cafe.name]
        switch savedStatus {
        case .wantToGo: parts.append(String(localized: "行きたいに登録済み"))
        case .visited: parts.append(String(localized: "行った"))
        case nil: break
        }
        if let caption { parts.append(caption) }
        parts.append(answerLine(for: item.cafe, dog: dog).spoken)
        parts.append(OpenLine.make(hours: item.cafe.hours, at: date, isTargetTime: isTargetTime).spokenText)
        parts.append(WalkingTime.summary(meters: item.distanceMeters).spoken)
        if showsFreshnessWarning(for: item.cafe, now: clock ?? date) {
            parts.append(String(localized: "情報が古い可能性があります"))
        }
        return parts.joined(separator: "、")
    }
}

/// 営業の行（「営業中・19:00まで」「あと40分で閉店」「営業時間外」「本日定休」「営業時間は分かりません」）の純ロジック。
/// 「いつ行く？」で対象時刻を決めているときは、その時刻のことだと分かる言い方にする
/// （「土 12:00 は営業中・19:00まで」「土 12:00 は営業時間外」「土曜は定休」）。
/// 時間が分からない店を「営業中」とも「時間外」とも言わない（憲章 原則I）。
struct OpenLine: Equatable {
    /// 営業の状態。`OpenState` に「営業中だが閉店まで60分以内」を足したもの
    enum State: Equatable {
        case open
        /// 営業中で、閉店まで60分以内（「あと40分で閉店」）。対象時刻の指定中は使わない
        case closingSoon
        case outsideHours
        case closedToday
        case unknown

        /// 営業中と分かっているか（`open` と `closingSoon`）
        var isOpen: Bool { self == .open || self == .closingSoon }
    }

    /// 「あと◯分で閉店」を出す残り分の上限
    static let closingSoonMinutes = 60

    let state: State
    let text: String
    let spokenText: String

    /// - Parameters:
    ///   - date: 判定する時刻（今、または対象時刻）
    ///   - isTargetTime: `date` が「いつ行く？」で決めた対象時刻か
    static func make(hours: OpeningHours?, at date: Date = Date(), isTargetTime: Bool = false) -> OpenLine {
        let state = OpeningHoursEvaluator.state(hours: hours, at: date)
        let label = isTargetTime ? TargetTime.shortLabel(date) : nil
        switch state {
        case .open:
            let closing = OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: date)
            if let label {
                if let closing {
                    return OpenLine(
                        state: .open,
                        text: String(localized: "\(label) は営業中・\(closing)まで"),
                        spokenText: String(localized: "\(label) は営業中\(spokenTime(closing))まで")
                    )
                }
                let text = String(localized: "\(label) は営業中")
                return OpenLine(state: .open, text: text, spokenText: text)
            }
            // 未来の時刻に「あと◯分」は紛らわしいので、今のときだけ出す
            if let remaining = OpeningHoursEvaluator.minutesUntilClosingIfOpen(hours: hours, at: date),
               (1...closingSoonMinutes).contains(remaining) {
                let text = String(localized: "あと\(remaining)分で閉店")
                return OpenLine(state: .closingSoon, text: text, spokenText: String(localized: "営業中、\(text)"))
            }
            if let closing {
                return OpenLine(
                    state: .open,
                    text: String(localized: "営業中・\(closing)まで"),
                    spokenText: String(localized: "営業中\(spokenTime(closing))まで")
                )
            }
            let text = String(localized: "営業中")
            return OpenLine(state: .open, text: text, spokenText: text)
        case .outsideHours:
            let text = label.map { String(localized: "\($0) は営業時間外") } ?? String(localized: "営業時間外")
            return OpenLine(state: .outsideHours, text: text, spokenText: text)
        case .closedToday:
            let text = isTargetTime
                ? String(localized: "\(TargetTime.weekdayName(of: date))曜は定休")
                : String(localized: "本日定休")
            return OpenLine(state: .closedToday, text: text, spokenText: text)
        case .unknown:
            let text = String(localized: "営業時間は分かりません")
            return OpenLine(state: .unknown, text: text, spokenText: text)
        }
    }

    /// "19:00" → "19時"、"19:30" → "19時30分"
    static func spokenTime(_ time: String) -> String {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return time }
        return minute == 0 ? "\(hour)時" : "\(hour)時\(minute)分"
    }
}

/// 電話ボタンの `tel:` URL（番号があるときだけボタンを出す）
enum PhoneLink {
    /// 数字と先頭の「+」だけを残して `tel:` URL にする。数字が6桁未満なら nil（電話番号として扱わない）。
    static func url(for phone: String?) -> URL? {
        guard let phone else { return nil }
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter { $0.isASCII && $0.isNumber }
        guard digits.count >= 6 else { return nil }
        let number = trimmed.hasPrefix("+") ? "+" + digits : digits
        return URL(string: "tel:\(number)")
    }
}
