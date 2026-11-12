import Foundation

/// 地図ピンの形（色だけに頼らず形でも区別する）
enum MapPinShape: Equatable, Sendable {
    /// 店内OK
    case circle
    /// テラスのみ
    case roundedSquare
    /// 条件を確認
    case teardrop
    /// 未確認（店内OKの丸・薄い店内OKのピンと見分けるため、丸にしない）
    case diamond
}

extension MapPinCategory {
    var pinShape: MapPinShape {
        switch self {
        case .indoorOK: return .circle
        case .unverified: return .diamond
        case .terraceOnly: return .roundedSquare
        case .checkDetail: return .teardrop
        }
    }
}

extension MapPinCategory {
    /// ピン・写真のない店のタイルの中に置く SF Symbol（席の種類が絵柄で分かる）。
    /// 店内OK＝フォークとナイフ（お店の中で過ごせる）、テラス＝太陽（外の席）、条件を確認＝？。
    /// 未確認はまだ席が分からないので従来の肉球のまま。
    /// （家の絵柄は「家」に、傘の絵柄は「雨」に見えるため、2026-11-13 に差し替えた）
    var symbolName: String {
        switch self {
        case .indoorOK: return "fork.knife"
        case .terraceOnly: return "sun.max.fill"
        case .checkDetail: return "questionmark"
        case .unverified: return "pawprint.fill"
        }
    }

    /// 絵柄の下に添える短い文字（絵柄だけでは意味が伝わりにくい2種類に付ける）。
    /// 店内OK＝「OK」、テラス＝「テラス」。条件を確認・未確認は絵柄だけ。
    var pinCaption: String? {
        switch self {
        case .indoorOK: return "OK"
        case .terraceOnly: return String(localized: "テラス")
        case .checkDetail, .unverified: return nil
        }
    }
}

/// 1つのピンの見た目を決める要素（純ロジック・描画しない）。
/// 営業時間が分かっていて今は営業していない店のピンは薄くする（時間が不明の店は薄くしない）。
struct MapPinStyle: Hashable, Sendable {
    let category: MapPinCategory
    let isFavorite: Bool
    let isDimmed: Bool

    /// 薄いピンの不透明度
    static let dimmedAlpha: Double = 0.4

    var alpha: Double { isDimmed ? Self.dimmedAlpha : 1 }
    var shape: MapPinShape { category.pinShape }

    static func make(for cafe: Cafe, isFavorite: Bool, at date: Date = Date()) -> MapPinStyle {
        let state = OpeningHoursEvaluator.state(hours: cafe.hours, at: date)
        let isDimmed = state == .outsideHours || state == .closedToday
        return MapPinStyle(category: MapPinCategory.category(for: cafe), isFavorite: isFavorite, isDimmed: isDimmed)
    }
}

