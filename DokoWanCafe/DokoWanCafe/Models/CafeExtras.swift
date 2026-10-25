import Foundation

// 002-cafe-rich-info: カフェ詳細の充実（spec 002, FR-101）。
// すべて任意フィールドとして cafes.json に後方互換で追加される。

/// 公式リンクの種別
enum CafeLinkType: String, Codable, Sendable {
    case website
    case instagram
    case x
    case tabelog
    case googleMap = "google_map"
    case other

    var displayName: String {
        switch self {
        case .website: return String(localized: "公式サイト")
        case .instagram: return "Instagram"
        case .x: return "X"
        case .tabelog: return String(localized: "食べログ")
        case .googleMap: return "Google Map"
        case .other: return String(localized: "リンク")
        }
    }

    var systemImage: String {
        switch self {
        case .website: return "globe"
        case .instagram: return "camera"
        case .x: return "at"
        case .tabelog: return "fork.knife"
        case .googleMap: return "map"
        case .other: return "link"
        }
    }
}

/// 公式リンク（FR-106）
struct CafeLink: Codable, Equatable, Identifiable, Sendable {
    let type: CafeLinkType
    let url: String

    var id: String { "\(type.rawValue)-\(url)" }

    var resolvedURL: URL? { URL(string: url) }
}

/// 営業時間の1枠（"HH:mm"。妥当性はエクスポート時に検証済み, FR-105）
struct TimeRange: Codable, Equatable, Sendable {
    let open: String
    let close: String

    /// "HH:mm" → 0時からの分。パース不能は nil
    /// "24:00"（当日終端＝翌0:00）は 1440分として許可する（S4, 日跨ぎ対応）。
    static func minutes(of time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...59).contains(m), (0...24).contains(h), h < 24 || m == 0 else { return nil }
        return h * 60 + m
    }

    var openMinutes: Int? { Self.minutes(of: open) }
    var closeMinutes: Int? { Self.minutes(of: close) }
}

/// 曜日（OpeningHours のキーに対応）
enum Weekday: String, CaseIterable, Sendable {
    case mon, tue, wed, thu, fri, sat, sun

    /// Calendar.component(.weekday)（1=日〜7=土）から変換
    static func from(calendarWeekday: Int) -> Weekday? {
        switch calendarWeekday {
        case 1: return .sun
        case 2: return .mon
        case 3: return .tue
        case 4: return .wed
        case 5: return .thu
        case 6: return .fri
        case 7: return .sat
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .mon: return String(localized: "月")
        case .tue: return String(localized: "火")
        case .wed: return String(localized: "水")
        case .thu: return String(localized: "木")
        case .fri: return String(localized: "金")
        case .sat: return String(localized: "土")
        case .sun: return String(localized: "日")
        }
    }
}

/// 構造化営業時間（曜日→時間帯配列。キー欠落=不明 / 空配列=定休, FR-102）
struct OpeningHours: Codable, Equatable, Sendable {
    var mon: [TimeRange]?
    var tue: [TimeRange]?
    var wed: [TimeRange]?
    var thu: [TimeRange]?
    var fri: [TimeRange]?
    var sat: [TimeRange]?
    var sun: [TimeRange]?

    /// その曜日の時間帯（nil=不明・[]=定休）
    func ranges(for weekday: Weekday) -> [TimeRange]? {
        switch weekday {
        case .mon: return mon
        case .tue: return tue
        case .wed: return wed
        case .thu: return thu
        case .fri: return fri
        case .sat: return sat
        case .sun: return sun
        }
    }

    /// 登録済みの曜日が1つでもあるか
    var hasAnyDay: Bool {
        Weekday.allCases.contains { ranges(for: $0) != nil }
    }
}

/// 犬向け設備（true=✓ / false=✕ / nil=不明。「不明」を「✕」と混同しない, FR-104）
///
/// 再設計 段階3: 「うちの子」の判定用に、席ごとのサイズ上限と店内での過ごし方を持つ。
/// - `sizeMaxIndoor` / `sizeMaxTerrace`: 明記された上限（nil＝明記なし。「制限なし」ではない）
/// - `indoorStyle`: 店内で認められていると明記された過ごし方。網羅的ではなく、含まれていないことを不可とは扱わない
struct DogAmenities: Codable, Equatable, Sendable {
    var indoor: Bool?
    var terrace: Bool?
    var largeDogs: Bool?
    var dogMenu: Bool?
    var sizeMaxIndoor: DogSize?
    var sizeMaxTerrace: DogSize?
    var indoorStyle: [DogStyle]?

    enum CodingKeys: String, CodingKey {
        case indoor
        case terrace
        case largeDogs = "large_dogs"
        case dogMenu = "dog_menu"
        case sizeMaxIndoor = "size_max_indoor"
        case sizeMaxTerrace = "size_max_terrace"
        case indoorStyle = "indoor_style"
    }
}

extension DogAmenities {
    /// 新キーの未知の値（将来追加される大きさ・過ごし方）は無視して読み込む（デコード全体を落とさない）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        indoor = try container.decodeIfPresent(Bool.self, forKey: .indoor)
        terrace = try container.decodeIfPresent(Bool.self, forKey: .terrace)
        largeDogs = try container.decodeIfPresent(Bool.self, forKey: .largeDogs)
        dogMenu = try container.decodeIfPresent(Bool.self, forKey: .dogMenu)
        sizeMaxIndoor = Self.tolerantSize(container, .sizeMaxIndoor)
        sizeMaxTerrace = Self.tolerantSize(container, .sizeMaxTerrace)
        if let raws = try? container.decodeIfPresent([String].self, forKey: .indoorStyle) {
            indoorStyle = raws.compactMap(DogStyle.init(rawValue:))
        } else {
            indoorStyle = nil
        }
    }

    private static func tolerantSize(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> DogSize? {
        guard let raw = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
        return DogSize(rawValue: raw)
    }
}

/// 運営転記メモ（公式SNS等で運営が確認した内容の転記。出どころ＋確認日必須, FR-103）
struct OperatorNote: Codable, Equatable, Sendable {
    let text: String
    let source: String
    let verifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case text
        case source
        case verifiedAt = "verified_at"
    }

    var sourceDisplayName: String {
        source.lowercased() == "instagram" ? "Instagram" : source
    }
}
