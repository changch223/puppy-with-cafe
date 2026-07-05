import Foundation

/// 営業状態（FR-102）
enum OpenState: Equatable, Sendable {
    /// 営業中
    case open
    /// 本日は営業日だが現在は時間外
    case outsideHours
    /// 本日定休
    case closedToday
    /// 構造化データなし → バッジを出さない（推測で「営業中」と示さない）
    case unknown

    var displayText: String? {
        switch self {
        case .open: return String(localized: "営業中")
        case .outsideHours: return String(localized: "営業時間外")
        case .closedToday: return String(localized: "本日定休")
        case .unknown: return nil
        }
    }
}

/// 営業中判定（純ロジック・UI非依存, 憲章 原則IV / FR-102）。
/// タイムゾーンは Asia/Tokyo 固定（v1 は東京のみ, 001/FR-022）。
/// 開店時刻は含み、閉店時刻は含まない（9:00-18:00 → 9:00は営業中、18:00は時間外）。
enum OpeningHoursEvaluator {
    static let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

    static func state(
        hours: OpeningHours?,
        at date: Date = Date(),
        timeZone: TimeZone = tokyoTimeZone
    ) -> OpenState {
        guard let hours, hours.hasAnyDay else { return .unknown }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: date)) else {
            return .unknown
        }
        // その曜日が未登録（キー欠落）→ 不明（「定休」と誤認させない, FR-104）
        guard let ranges = hours.ranges(for: weekday) else { return .unknown }
        if ranges.isEmpty { return .closedToday }

        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        for range in ranges {
            guard let open = range.openMinutes, let close = range.closeMinutes else { continue }
            if minutes >= open && minutes < close {
                return .open
            }
        }
        return .outsideHours
    }
}
