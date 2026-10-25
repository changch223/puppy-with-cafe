import Foundation

/// 「いつ行く？」で決める対象時刻の組み立てと文言の純ロジック（憲章 原則IV）。
/// 日付・曜日は Asia/Tokyo で数える（v1 は東京のみ, OpeningHoursEvaluator と同じ）。
/// 対象時刻は保存しない（アプリを開き直したら「今」）。
enum TargetTime {
    static let timeZone = OpeningHoursEvaluator.tokyoTimeZone

    /// 日の選択肢の数: 今日・明日と、その先5日分の曜日（計7日）
    static let dayCount = 7

    /// 時刻を選ぶ刻み（分）
    static let stepMinutes = 30

    /// 時刻の選択肢（0:00〜23:30 の30分刻み。0時からの分で表す）
    static let timeChoices: [Int] = Array(stride(from: 0, to: 24 * 60, by: stepMinutes))

    /// 「今」から日付を選んだときの時刻の初期値（昼 12時）
    static let defaultMinutes = 12 * 60

    struct Preset: Equatable, Identifiable {
        let title: String
        let minutes: Int
        var id: Int { minutes }
        /// 例: 「朝 9時」
        var label: String { String(localized: "\(title) \(minutes / 60)時") }
    }

    /// 朝 9時／昼 12時／午後 15時／夜 18時
    static let presets: [Preset] = [
        Preset(title: String(localized: "朝"), minutes: 9 * 60),
        Preset(title: String(localized: "昼"), minutes: 12 * 60),
        Preset(title: String(localized: "午後"), minutes: 15 * 60),
        Preset(title: String(localized: "夜"), minutes: 18 * 60),
    ]

    /// 日の選択肢1つ（「今」は含まない。「今」は対象時刻なし＝nil で表す）
    struct DayOption: Equatable, Identifiable {
        /// 今日からの日数（0=今日, 1=明日, 2...6=その先の曜日）
        let offset: Int
        /// 「今日」「明日」「火」…
        let title: String
        /// 小さく添える日付（例: 「10/27」）
        let dateText: String
        /// その日の0時（東京）
        let startOfDay: Date
        var id: Int { offset }
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// 今日・明日と、その先5日分の曜日。
    static func dayOptions(now: Date) -> [DayOption] {
        let calendar = calendar
        let today = calendar.startOfDay(for: now)
        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let title: String
            switch offset {
            case 0: title = String(localized: "今日")
            case 1: title = String(localized: "明日")
            default: title = weekdayName(of: day)
            }
            return DayOption(offset: offset, title: title, dateText: monthDayText(day), startOfDay: day)
        }
    }

    /// `dayOffset` 日後の `minutes`（その日0時からの分。0〜1439）の時刻。
    static func date(dayOffset: Int, minutes: Int, now: Date) -> Date? {
        guard (0..<dayCount).contains(dayOffset), (0..<24 * 60).contains(minutes) else { return nil }
        let calendar = calendar
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        return calendar.date(byAdding: .minute, value: minutes, to: day)
    }

    /// 対象時刻を（今日からの日数, 0時からの分）に戻す。選択肢の範囲外（アプリを開いたまま日が進んだ等）は nil。
    static func selection(of target: Date, now: Date) -> (dayOffset: Int, minutes: Int)? {
        let calendar = calendar
        let today = calendar.startOfDay(for: now)
        let targetDay = calendar.startOfDay(for: target)
        guard let offset = calendar.dateComponents([.day], from: today, to: targetDay).day,
              (0..<dayCount).contains(offset) else { return nil }
        return (offset, minutesOfDay(target))
    }

    /// その日の0時からの分（東京）
    static func minutesOfDay(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// 例: 「12:00」
    static func timeText(minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// 例: 「土」
    static func weekdayName(of date: Date) -> String {
        Weekday.from(calendarWeekday: calendar.component(.weekday, from: date))?.displayName ?? ""
    }

    /// チップ・営業の行・見出しに使う短い表記（例: 「土 12:00」）
    static func shortLabel(_ date: Date) -> String {
        "\(weekdayName(of: date)) \(timeText(minutes: minutesOfDay(date)))"
    }

    /// ボタン・読み上げ用の表記（例: 「土曜 12:00」）
    static func longLabel(_ date: Date) -> String {
        "\(weekdayName(of: date))曜 \(timeText(minutes: minutesOfDay(date)))"
    }

    /// 日付だけの表記（例: 「10/25」）。「行った ✓ 10/25」にも使う。
    static func monthDayText(_ date: Date) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)/\(components.day ?? 0)"
    }

    /// シートの下のボタン文言。0件のときは理由を言う（ボタンは無効にする）。
    /// - Parameter target: 対象時刻。nil は「今」
    static func applyButtonTitle(target: Date?, count: Int) -> String {
        guard count > 0 else { return String(localized: "この時間に開いているお店はありません") }
        if let target {
            return String(localized: "\(longLabel(target)) に開いている \(count)件を表示")
        }
        return String(localized: "今開いている \(count)件を表示")
    }
}
