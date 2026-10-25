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

/// 一覧の行・ピンカードのタグ（店内OK／テラスのみ／条件を確認／未確認 ＋ 大型犬OK）
struct CafeTag: Equatable {
    enum Kind: Equatable {
        case category(MapPinCategory)
        case largeDog
    }

    let kind: Kind
    let label: String
}

extension MapPinCategory {
    /// 行・カード用の短いタグ文言（`displayName` は詳細画面で使うので変えない）
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

    /// 可否のタグ1つ＋大型犬OK（無条件で大型犬が可と分かる店だけ。不明・条件つきは出さない）
    static func tags(for cafe: Cafe) -> [CafeTag] {
        let category = MapPinCategory.category(for: cafe)
        var result = [CafeTag(kind: .category(category), label: categoryLabel(for: cafe))]
        if showsLargeDogTag(for: cafe) {
            result.append(CafeTag(kind: .largeDog, label: String(localized: "大型犬OK")))
        }
        return result
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
    static func accessibilityLabel(
        for item: CafeWithDistance,
        isFavorite: Bool = false,
        at date: Date = Date()
    ) -> String {
        var parts = [item.cafe.name]
        if isFavorite { parts.append(String(localized: "保存済み")) }
        parts.append(contentsOf: tags(for: item.cafe).map(\.label))
        if let condition = conditionSummary(for: item.cafe) { parts.append(condition) }
        parts.append(OpenLine.make(hours: item.cafe.hours, at: date).spokenText)
        parts.append(WalkingTime.summary(meters: item.distanceMeters).spoken)
        if showsFreshnessWarning(for: item.cafe, now: date) {
            parts.append(String(localized: "情報が古い可能性があります"))
        }
        return parts.joined(separator: "、")
    }
}

/// 営業の行（「営業中・19:00まで」「営業時間外」「本日定休」「時間の情報なし」）の純ロジック。
/// 時間が分からない店を「営業中」とも「時間外」とも言わない（憲章 原則I）。
struct OpenLine: Equatable {
    let state: OpenState
    let text: String
    let spokenText: String

    static func make(hours: OpeningHours?, at date: Date = Date()) -> OpenLine {
        let state = OpeningHoursEvaluator.state(hours: hours, at: date)
        switch state {
        case .open:
            if let closing = OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: date) {
                return OpenLine(
                    state: state,
                    text: String(localized: "営業中・\(closing)まで"),
                    spokenText: String(localized: "営業中\(spokenTime(closing))まで")
                )
            }
            let text = String(localized: "営業中")
            return OpenLine(state: state, text: text, spokenText: text)
        case .outsideHours:
            let text = String(localized: "営業時間外")
            return OpenLine(state: state, text: text, spokenText: text)
        case .closedToday:
            let text = String(localized: "本日定休")
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
