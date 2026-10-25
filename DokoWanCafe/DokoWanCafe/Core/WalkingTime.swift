import Foundation

/// 徒歩の目安（直線距離ベース・分速80m・切り上げ）の純ロジック（憲章 原則IV）。
/// 2kmを超える距離では徒歩の目安を出さず、距離（km）だけを示す。
enum WalkingTime {
    /// 分速（m/分）
    static let metersPerMinute: Double = 80
    /// 徒歩の目安を出す上限距離（m）。これを超えたら距離のみ表示する。
    static let maxWalkableMeters: Double = 2_000

    /// 徒歩の分数（切り上げ・最低1分）。距離が負なら0として扱う。
    static func minutes(meters: Double) -> Int {
        max(1, Int((max(meters, 0) / metersPerMinute).rounded(.up)))
    }

    static func isWalkable(meters: Double) -> Bool {
        meters <= maxWalkableMeters
    }

    /// 距離の短い表記。995m未満は「320 m」（10m単位に丸め・最小10 m）、1km以上は「3.2 km」。
    static func distanceText(meters: Double) -> String {
        let value = max(meters, 0)
        if value < 995 {
            return "\(max(10, Int((value / 10).rounded()) * 10)) m"
        }
        return String(format: "%.1f km", value / 1_000)
    }

    /// 行・カードの右側に出す表記。
    struct Summary: Equatable {
        /// 大きく出す方。徒歩圏なら「徒歩約7分」、圏外なら「3.2 km」。
        let headline: String
        /// 小さく添える距離。徒歩圏のときだけ（「520 m」）。圏外は headline が距離なので nil。
        let detail: String?
        /// VoiceOver 用の読み上げ
        let spoken: String
    }

    static func summary(meters: Double) -> Summary {
        if isWalkable(meters: meters) {
            let text = String(localized: "徒歩約\(minutes(meters: meters))分")
            return Summary(headline: text, detail: distanceText(meters: meters), spoken: text)
        }
        let kilometers = String(format: "%.1f", max(meters, 0) / 1_000)
        return Summary(
            headline: distanceText(meters: meters),
            detail: nil,
            spoken: String(localized: "\(kilometers)キロメートル")
        )
    }
}
