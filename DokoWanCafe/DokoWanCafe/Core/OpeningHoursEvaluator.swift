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
/// 日跨ぎ営業（close <= open。例 22:00-2:00）にも対応（S4）: 「当日開始・翌日へ延びる枠」と
/// 「前日開始・当日早朝に繰り越す枠」を別々に評価する（前日の曜日の枠を見ずに当日の枠だけで
/// 早朝を判定すると、前日が定休/未登録の場合に誤判定するため, QA指摘）。
enum OpeningHoursEvaluator {
    static let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

    /// 当日開始の枠が現在時刻を含むか。close <= open（日跨ぎ）のときは開店時刻〜24:00（当日中）を
    /// 営業中とみなす（0:00〜closeの早朝分は「前日の枠」として isCarryoverOpen 側が判定する）。
    private static func isForwardOpen(minutes: Int, open: Int, close: Int) -> Bool {
        if close > open {
            return minutes >= open && minutes < close
        }
        return minutes >= open
    }

    /// 前日開始の日跨ぎ枠（close <= open）が当日の早朝（0:00〜close）まで繰り越して営業中か。
    private static func isCarryoverOpen(minutes: Int, open: Int, close: Int) -> Bool {
        guard close <= open else { return false }
        return minutes < close
    }

    /// 前日の曜日（日跨ぎの繰り越し判定に使う, S4）
    private static func previousWeekday(of weekday: Weekday) -> Weekday {
        switch weekday {
        case .mon: return .sun
        case .tue: return .mon
        case .wed: return .tue
        case .thu: return .wed
        case .fri: return .thu
        case .sat: return .fri
        case .sun: return .sat
        }
    }

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
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        // 前日の日跨ぎ枠からの繰り越し（例: 金17:00-02:00の店の土01:00）を先に判定する。
        // 当日の曜日が定休/未登録でも、前日からの営業が続いていれば「営業中」とする。
        if let previousRanges = hours.ranges(for: previousWeekday(of: weekday)) {
            for range in previousRanges {
                guard let open = range.openMinutes, let close = range.closeMinutes else { continue }
                if isCarryoverOpen(minutes: minutes, open: open, close: close) {
                    return .open
                }
            }
        }

        // その曜日が未登録（キー欠落）→ 不明（「定休」と誤認させない, FR-104）
        guard let ranges = hours.ranges(for: weekday) else { return .unknown }
        if ranges.isEmpty { return .closedToday }

        for range in ranges {
            guard let open = range.openMinutes, let close = range.closeMinutes else { continue }
            if isForwardOpen(minutes: minutes, open: open, close: close) {
                return .open
            }
        }
        return .outsideHours
    }

    /// 現在「営業中」なら閉店時刻（"HH:mm"）を返す。営業中でなければ nil
    /// （地図の下部コンパクトカードの「営業中・〜HH:mm」表示にのみ使う。判定不能な店で嘘をつかない, UI/UXブラッシュアップ設計書2）。
    static func closingTimeIfOpen(
        hours: OpeningHours?,
        at date: Date = Date(),
        timeZone: TimeZone = tokyoTimeZone
    ) -> String? {
        guard let hours, hours.hasAnyDay else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: date)) else {
            return nil
        }
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        // 前日からの繰り越し中なら、前日の枠の閉店時刻を返す（state()と同じ判定順, S4）
        if let previousRanges = hours.ranges(for: previousWeekday(of: weekday)) {
            for range in previousRanges {
                guard let open = range.openMinutes, let close = range.closeMinutes else { continue }
                if isCarryoverOpen(minutes: minutes, open: open, close: close) {
                    return range.close
                }
            }
        }

        guard let ranges = hours.ranges(for: weekday), !ranges.isEmpty else { return nil }

        for range in ranges {
            guard let open = range.openMinutes, let close = range.closeMinutes else { continue }
            if isForwardOpen(minutes: minutes, open: open, close: close) {
                return range.close
            }
        }
        return nil
    }
}
