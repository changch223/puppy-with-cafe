import Foundation

/// 店名の頭文字タイル（写真がない店の代替表示）の純ロジック（憲章 原則IV）。
enum InitialTile {
    /// 色パレットの数（色そのものはUI側が持ち、ここでは番号だけを決める）
    static let paletteSize = 8

    /// タイルに出す1文字。先頭の記号・空白は飛ばして最初の文字・数字を使い、英字は大文字にする。
    static func character(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let picked = trimmed.first(where: { $0.isLetter || $0.isNumber }) ?? trimmed.first
        guard let picked else { return "店" }
        return String(picked).uppercased()
    }

    /// 店IDから決まる色番号（0..<paletteSize）。UUIDのバイト列から求めるので起動をまたいでも変わらない。
    static func colorIndex(for id: UUID) -> Int {
        let sum = withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(0) { ($0 &* 31 &+ Int($1)) & 0xFFFF }
        }
        return sum % paletteSize
    }
}

/// 一覧の行・ピンカードのタグ（最大2つ: うちの子OK ＋ 店内OK／テラスのみ／条件を確認／未確認、または 可否 ＋ 大型犬OK）
struct CafeTag: Equatable {
    enum Kind: Equatable {
        case category(MapPinCategory)
        case largeDog
        /// うちの子が入れると明記された店（再設計 段階3）
        case myDog
    }

    let kind: Kind
    let label: String
}

extension MapPinCategory {
    /// 行・カード用の短いタグ文言
    var tagLabel: String {
        switch self {
        case .indoorOK: return String(localized: "店内OK")
        // 店内が不可と分かっているときだけ「テラスのみ」。不明なら断定しない（`CafePresentation.categoryLabel`）
        case .terraceOnly: return String(localized: "テラスOK")
        case .checkDetail: return String(localized: "条件を確認")
        case .unverified: return String(localized: "未確認")
        }
    }
}

/// 行・カードの表示用に店から取り出す要点（純ロジック）
enum CafePresentation {
    /// 可否のタグ文言。テラス席のみ可のうち、店内が不可（`indoor == false`）と分かる店だけ「テラスのみ」、
    /// 店内が不明（nil）の店は「テラスOK」（憶測で「店内は不可」と言わない, 憲章 原則I）。
    static func categoryLabel(for cafe: Cafe) -> String {
        let category = MapPinCategory.category(for: cafe)
        if category == .terraceOnly, cafe.dogAmenities?.indoor == false {
            return String(localized: "テラスのみ")
        }
        return category.tagLabel
    }

    /// 「大型犬OK」タグを出すか。`largeDogs == true` でも `dogSizeLimit`（サイズの条件）が書かれている店は
    /// 条件つきなので出さない（詳細画面と同じ規則）。
    static func showsLargeDogTag(for cafe: Cafe) -> Bool {
        guard cafe.dogAmenities?.largeDogs == true else { return false }
        let limit = cafe.dogSizeLimit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return limit.isEmpty
    }

    /// 行・カードのタグ（最大2つ。標準の文字サイズで1行に収める）。
    /// うちの子が入れると明記された店は「うちの子OK」＋可否のタグ。そうでなければ可否のタグ＋大型犬OK
    /// （無条件で大型犬が可と分かる店だけ。不明・条件つきは出さない）。「大型犬OK」は詳細にも出る。
    /// 「うちの子OK」は `dog` が設定済みで、その子が入れると明記された店だけ（再設計 段階3）。
    static let maxTagCount = 2

    static func tags(for cafe: Cafe, dog: DogProfile? = nil) -> [CafeTag] {
        let category = MapPinCategory.category(for: cafe)
        let categoryTag = CafeTag(kind: .category(category), label: categoryLabel(for: cafe))
        if let dog, let label = DogFit.evaluate(cafe: cafe, dog: dog).tagLabel {
            return [CafeTag(kind: .myDog, label: label), categoryTag]
        }
        var result = [categoryTag]
        if showsLargeDogTag(for: cafe) {
            result.append(CafeTag(kind: .largeDog, label: String(localized: "大型犬OK")))
        }
        return Array(result.prefix(maxTagCount))
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

    /// 行・カードのVoiceOver用ラベル。「店名、店内OK、条件の要点、営業中19時まで、徒歩約7分、情報が古い可能性があります」のように1つにまとめる。
    /// - Parameters:
    ///   - date: 営業の判定に使う時刻（今、または「いつ行く？」の対象時刻）
    ///   - isTargetTime: `date` が対象時刻か（営業を「土 12:00 は営業中…」の言い方で読む）
    ///   - clock: 「情報が古い可能性」の判定に使う「今」。対象時刻ではなく今で判定する。省略時は `date`
    ///   - caption: 保存タブの「10/25 に行った」など、名前に続けて読む一言
    ///   - dog: うちの子の設定（あれば「うちの子OK」「うちの子は不可（…）」も読む）
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
        parts.append(contentsOf: tags(for: item.cafe, dog: dog).map(\.label))
        if let dog, let note = DogFit.evaluate(cafe: item.cafe, dog: dog).rowNote { parts.append(note) }
        if let condition = conditionSummary(for: item.cafe) { parts.append(condition) }
        parts.append(OpenLine.make(hours: item.cafe.hours, at: date, isTargetTime: isTargetTime).spokenText)
        parts.append(WalkingTime.summary(meters: item.distanceMeters).spoken)
        if showsFreshnessWarning(for: item.cafe, now: clock ?? date) {
            parts.append(String(localized: "情報が古い可能性があります"))
        }
        return parts.joined(separator: "、")
    }
}

/// 営業の行（「営業中・19:00まで」「営業時間外」「本日定休」「時間の情報なし」）の純ロジック。
/// 「いつ行く？」で対象時刻を決めているときは、その時刻のことだと分かる言い方にする
/// （「土 12:00 は営業中・19:00まで」「土 12:00 は営業時間外」「土曜は定休」）。
/// 時間が分からない店を「営業中」とも「時間外」とも言わない（憲章 原則I）。
struct OpenLine: Equatable {
    let state: OpenState
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
                        state: state,
                        text: String(localized: "\(label) は営業中・\(closing)まで"),
                        spokenText: String(localized: "\(label) は営業中\(spokenTime(closing))まで")
                    )
                }
                let text = String(localized: "\(label) は営業中")
                return OpenLine(state: state, text: text, spokenText: text)
            }
            if let closing {
                return OpenLine(
                    state: state,
                    text: String(localized: "営業中・\(closing)まで"),
                    spokenText: String(localized: "営業中\(spokenTime(closing))まで")
                )
            }
            let text = String(localized: "営業中")
            return OpenLine(state: state, text: text, spokenText: text)
        case .outsideHours:
            let text = label.map { String(localized: "\($0) は営業時間外") } ?? String(localized: "営業時間外")
            return OpenLine(state: state, text: text, spokenText: text)
        case .closedToday:
            let text = isTargetTime
                ? String(localized: "\(TargetTime.weekdayName(of: date))曜は定休")
                : String(localized: "本日定休")
            return OpenLine(state: state, text: text, spokenText: text)
        case .unknown:
            let text = String(localized: "時間の情報なし")
            return OpenLine(state: state, text: text, spokenText: text)
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
