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
    /// ピン・写真のない店のタイルの中に置く SF Symbol。条件を確認＝？、未確認＝肉球（まだ席が分からない）。
    /// 店内OK・テラスは絵柄を使わず文字（`pinLines`）で言い切るので nil。
    /// （家は「家」に、傘は「雨」に見え、絵柄＋文字は 36pt では両方が小さくなるため、2026-11-13 に文字だけにした）
    var symbolName: String? {
        switch self {
        case .indoorOK, .terraceOnly: return nil
        case .checkDetail: return "questionmark"
        case .unverified: return "pawprint.fill"
        }
    }

    /// ピン・タイルの中に2行で書く文字。店内OK＝「店内／OK」、テラス＝「テラス／OK」。
    /// 条件を確認・未確認は絵柄（`symbolName`）だけなので nil。
    var pinLines: [String]? {
        switch self {
        case .indoorOK: return [String(localized: "店内"), "OK"]
        case .terraceOnly: return [String(localized: "テラス"), "OK"]
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

