import CoreGraphics
import Foundation

// 店詳細の再設計（段階1b）で使う純ロジック群（UI非依存, 憲章 原則IV）。

// MARK: - 3つの要点タイル

/// 「今日」「予約」「大型犬」の小タイル1枚分。
struct CafeDetailHighlight: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        /// 良い知らせ（営業中・大型犬可）
        case good
        /// 注意（本日定休・大型犬不可）
        case caution
        /// 中立の情報
        case neutral
        /// 情報なし
        case unknown
    }

    let title: String
    let value: String
    let tone: Tone
}

enum CafeDetailHighlights {
    /// 予約タイルに出す文字数の上限（超えたら末尾を省略。全文は「店舗情報」にある）
    static let reservationMaxLength = 16

    static func all(
        cafe: Cafe,
        at date: Date = Date(),
        isTargetTime: Bool = false,
        timeZone: TimeZone = OpeningHoursEvaluator.tokyoTimeZone
    ) -> [CafeDetailHighlight] {
        [
            today(
                hours: cafe.hours, hoursText: cafe.hoursText, at: date,
                isTargetTime: isTargetTime, timeZone: timeZone
            ),
            reservation(cafe.reservation),
            largeDogs(
                cafe.dogAmenities?.largeDogs,
                confirmed: CafeDetailAnswer.isConfirmed(cafe),
                hasSizeLimit: hasText(cafe.dogSizeLimit)
            ),
        ]
    }

    /// 今日: 「営業中・19:00まで」／「営業時間外」／「本日定休」／「営業時間は下記」（曜日別の時間は無く
    /// hours_text だけがある店）／「時間の情報なし」。
    /// 「いつ行く？」で対象時刻を決めているとき（`isTargetTime`）は、行の「土 12:00 は営業中」と食い違って見えないよう、
    /// タイルの見出しを「土 12:00」にして、その時刻の営業を示す（定休は「定休」。「本日」とは言わない）。
    static func today(
        hours: OpeningHours?,
        hoursText: String? = nil,
        at date: Date = Date(),
        isTargetTime: Bool = false,
        timeZone: TimeZone = OpeningHoursEvaluator.tokyoTimeZone
    ) -> CafeDetailHighlight {
        let title = isTargetTime ? TargetTime.shortLabel(date) : String(localized: "今日")
        switch OpeningHoursEvaluator.state(hours: hours, at: date, timeZone: timeZone) {
        case .open:
            let value: String
            if let closing = OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: date, timeZone: timeZone) {
                value = String(localized: "営業中・\(closing)まで")
            } else {
                value = String(localized: "営業中")
            }
            return CafeDetailHighlight(title: title, value: value, tone: .good)
        case .outsideHours:
            return CafeDetailHighlight(title: title, value: String(localized: "営業時間外"), tone: .neutral)
        case .closedToday:
            let value = isTargetTime ? String(localized: "定休") : String(localized: "本日定休")
            return CafeDetailHighlight(title: title, value: value, tone: .caution)
        case .unknown:
            if hasText(hoursText) {
                return CafeDetailHighlight(title: title, value: String(localized: "営業時間は下記"), tone: .neutral)
            }
            return CafeDetailHighlight(title: title, value: String(localized: "時間の情報なし"), tone: .unknown)
        }
    }

    /// 予約: reservation の要約（最初の1行・長ければ省略）。なければ「情報なし」
    static func reservation(_ text: String?) -> CafeDetailHighlight {
        let title = String(localized: "予約")
        guard let firstLine = text?
            .split(whereSeparator: \.isNewline).first
            .map({ $0.trimmingCharacters(in: .whitespaces) }),
            !firstLine.isEmpty
        else {
            return CafeDetailHighlight(title: title, value: String(localized: "情報なし"), tone: .unknown)
        }
        let value = firstLine.count > reservationMaxLength
            ? String(firstLine.prefix(reservationMaxLength - 1)) + "…"
            : firstLine
        return CafeDetailHighlight(title: title, value: value, tone: .neutral)
    }

    /// 大型犬: 可／不可／情報なし。確認済みでない店（未確認・確認日なし）は「可」と言い切らず中立の
    /// 「記載あり（未確認）」にする。サイズ制限の記載がある店の「可」は「条件つきで可」にする。
    static func largeDogs(_ value: Bool?, confirmed: Bool = true, hasSizeLimit: Bool = false) -> CafeDetailHighlight {
        let title = String(localized: "大型犬")
        switch value {
        case nil:
            return CafeDetailHighlight(title: title, value: String(localized: "情報なし"), tone: .unknown)
        case _? where !confirmed:
            return CafeDetailHighlight(title: title, value: String(localized: "記載あり（未確認）"), tone: .neutral)
        case true?:
            if hasSizeLimit {
                return CafeDetailHighlight(title: title, value: String(localized: "条件つきで可"), tone: .neutral)
            }
            return CafeDetailHighlight(title: title, value: String(localized: "可"), tone: .good)
        case false?:
            return CafeDetailHighlight(title: title, value: String(localized: "不可"), tone: .caution)
        }
    }

    private static func hasText(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

// MARK: - 営業時間の曜日別表

/// 曜日別の表の1行。
struct CafeDetailHoursRow: Equatable, Sendable {
    let weekday: Weekday
    /// 「11:00〜22:00」「定休」「—」（時間が不明な曜日）
    let text: String
    let isToday: Bool
}

enum CafeDetailHoursTable {
    /// 月〜日の7行。今日の行に `isToday`。キー欠落（不明）は「—」、空配列は「定休」。
    static func rows(
        hours: OpeningHours,
        at date: Date = Date(),
        timeZone: TimeZone = OpeningHoursEvaluator.tokyoTimeZone
    ) -> [CafeDetailHoursRow] {
        let today = weekday(at: date, timeZone: timeZone)
        return Weekday.allCases.map { day in
            CafeDetailHoursRow(weekday: day, text: text(for: hours.ranges(for: day)), isToday: day == today)
        }
    }

    static func text(for ranges: [TimeRange]?) -> String {
        guard let ranges else { return "—" }
        if ranges.isEmpty { return String(localized: "定休") }
        return ranges.map { "\($0.open)〜\($0.close)" }.joined(separator: ", ")
    }

    static func weekday(at date: Date, timeZone: TimeZone = OpeningHoursEvaluator.tokyoTimeZone) -> Weekday? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return Weekday.from(calendarWeekday: calendar.component(.weekday, from: date))
    }
}

// MARK: - わんちゃん向け情報（状態を言葉で）

struct CafeDetailAmenityRow: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case yes, no, unknown
        /// 記載はあるが未確認（✓/✕ にせず中立に示す）
        case unconfirmed
        /// 可だがサイズ・席の条件がある（緑の ✓ にせず中立に示す。タイルの「条件つきで可」と同じ）
        case conditional
    }

    let label: String
    let state: State
    /// 状態の言葉（「可」「不可」「あり」「なし」「情報なし」）
    let valueText: String
}

enum CafeDetailAmenities {
    /// 店内・テラス・大型犬・犬メニューの4行。不明は「情報なし」（「不可」と混同しない, FR-104）。
    /// `confirmed == false`（未確認・確認日なしの店）では記載があっても「記載あり（未確認）」の中立表示にする。
    /// `hasSizeLimit`（サイズ・席の条件の記載がある店）の大型犬「可」は、タイルと同じ「条件つきで可」の中立表示にする
    /// （条件の中身は答えのカードと「席・サイズの条件」にあるので、この行は状態の言葉だけ）。
    static func rows(
        _ amenities: DogAmenities, confirmed: Bool = true, hasSizeLimit: Bool = false
    ) -> [CafeDetailAmenityRow] {
        [
            row(String(localized: "店内"), amenities.indoor, confirmed, yes: String(localized: "可"), no: String(localized: "不可")),
            row(String(localized: "テラス"), amenities.terrace, confirmed, yes: String(localized: "可"), no: String(localized: "不可")),
            row(
                String(localized: "大型犬"), amenities.largeDogs, confirmed, yes: String(localized: "可"), no: String(localized: "不可"),
                yesIsConditional: hasSizeLimit
            ),
            row(String(localized: "犬メニュー"), amenities.dogMenu, confirmed, yes: String(localized: "あり"), no: String(localized: "なし")),
        ]
    }

    private static func row(
        _ label: String, _ value: Bool?, _ confirmed: Bool, yes: String, no: String, yesIsConditional: Bool = false
    ) -> CafeDetailAmenityRow {
        guard let value else {
            return CafeDetailAmenityRow(label: label, state: .unknown, valueText: String(localized: "情報なし"))
        }
        if !confirmed {
            return CafeDetailAmenityRow(label: label, state: .unconfirmed, valueText: String(localized: "記載あり（未確認）"))
        }
        if value, yesIsConditional {
            return CafeDetailAmenityRow(label: label, state: .conditional, valueText: String(localized: "条件つきで可"))
        }
        return CafeDetailAmenityRow(label: label, state: value ? .yes : .no, valueText: value ? yes : no)
    }
}

// MARK: - 共有文

enum CafeDetailShare {
    /// 座標で開く Google マップの検索URL
    static func mapsURL(for cafe: Cafe) -> URL? {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(cafe.latitude),\(cafe.longitude)")
    }

    /// 共有する文: 店名・住所・Google マップURL・「Puppy With Cafe で見つけました」
    static func message(for cafe: Cafe) -> String {
        var lines = [cafe.name]
        if let address = cafe.address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            lines.append(address)
        }
        if let url = mapsURL(for: cafe) {
            lines.append(url.absoluteString)
        }
        lines.append(String(localized: "Puppy With Cafe で見つけました"))
        return lines.joined(separator: "\n")
    }
}

// MARK: - 写真の帯

enum CafeDetailBand {
    /// 帯に使う色相の候補（店IDから決まる落ち着いた色）
    static let hues: [Double] = [0.02, 0.08, 0.12, 0.30, 0.42, 0.50, 0.58, 0.66, 0.75, 0.88]

    /// 店IDから決まる色相（同じIDなら常に同じ。`hashValue` は起動ごとに変わるため使わない）
    static func hue(for id: UUID) -> Double {
        let sum = withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 &+ Int($1) } }
        return hues[sum % hues.count]
    }

    /// 帯に出す頭文字（先頭の空白・記号を飛ばした最初の1文字）。取れなければ空文字（呼び出し側で記号に置き換える）。
    static func initial(of name: String) -> String {
        guard let first = name.first(where: { $0.isLetter || $0.isNumber }) else { return "" }
        return String(first).uppercased()
    }

    /// 写真として帯に使える画像か。LinkPresentation は画像がないときサイトのアイコンを返すことがあり、
    /// 引き伸ばすとぼやけるので、小さい画像は写真として扱わない。
    static func isUsablePhoto(size: CGSize) -> Bool {
        size.width >= 300 && size.height >= 160
    }
}
