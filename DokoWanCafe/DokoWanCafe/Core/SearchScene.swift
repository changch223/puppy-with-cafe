import Foundation

/// 検索画面の「場面から探す」（入力前の5つのボタン）。押すと、場面に合う条件がまとめて入る。
/// 純ロジック・UI非依存（憲章 原則IV）。どの場面も、データに明記された事実だけで絞る（原則I）。
/// 「雨の日でも」は天気を見ない（店内OKの店を出すだけ）。
enum SearchScene: CaseIterable, Identifiable, Sendable {
    /// 雨の日でも: 店内OK
    case rainy
    /// テラスでのんびり: テラス席OK
    case terrace
    /// 大型犬と一緒に: 大型犬OK
    case largeDog
    /// 夜も開いている: 今日の20:00に営業している
    case night
    /// 犬メニューがある: 犬メニューあり
    case dogMenu

    var id: Self { self }

    /// ボタンの文言
    var title: String {
        switch self {
        case .rainy: return String(localized: "雨の日でも")
        case .terrace: return String(localized: "テラスでのんびり")
        case .largeDog: return String(localized: "大型犬と一緒に")
        case .night: return String(localized: "夜も開いている")
        case .dogMenu: return String(localized: "犬メニューがある")
        }
    }

    /// ボタンの絵柄（SF Symbol）
    var systemImage: String {
        switch self {
        case .rainy: return "umbrella"
        case .terrace: return "sun.max"
        case .largeDog: return "dog"
        case .night: return "moon"
        case .dogMenu: return "fork.knife"
        }
    }

    /// 場面が入れる条件。何が絞られるかを VoiceOver で伝える（ボタンの読み上げ）
    var spokenHint: String {
        switch self {
        case .rainy: return String(localized: "店内OKの店に絞ります")
        case .terrace: return String(localized: "テラス席OKの店に絞ります")
        case .largeDog: return String(localized: "大型犬OKの店に絞ります")
        case .night: return String(localized: "夜8時に開いている店に絞ります")
        case .dogMenu: return String(localized: "犬メニューありの店に絞ります")
        }
    }

    /// 「夜も開いている」で見る時刻（その日の20:00）
    static let nightMinutes = 20 * 60

    /// 場面が入れる条件。押すと、それまでの絞り込み条件はこれに置き換わる（足し算にしない）。
    struct Conditions: Equatable {
        var amenities = AmenityFilter()
        /// 営業している店だけに絞るか
        var openNowOnly = false
        /// 営業を見る時刻。nil は今（`openNowOnly` のときだけ意味がある）。保存しない（「いつ行く？」と同じ）
        var targetTime: Date?
    }

    /// 場面の条件。`now` は「夜も開いている」で20:00が過ぎているかの判定に使う。
    func conditions(now: Date) -> Conditions {
        var result = Conditions()
        switch self {
        case .rainy: result.amenities.indoorOnly = true
        case .terrace: result.amenities.terraceOnly = true
        case .largeDog: result.amenities.largeDogOnly = true
        case .dogMenu: result.amenities.dogMenuOnly = true
        case .night:
            result.openNowOnly = true
            result.targetTime = Self.nightTarget(now: now)
        }
        return result
    }

    /// 今日（東京）の20:00。すでに20:00を過ぎていたら nil（＝今の時刻で見る）。
    static func nightTarget(now: Date) -> Date? {
        guard let target = TargetTime.date(dayOffset: 0, minutes: nightMinutes, now: now), now <= target else { return nil }
        return target
    }
}
