import Foundation

/// 犬の大きさ（再設計 段階3）。データの `size_max_*` と同じ3値（小さい順）。
enum DogSize: String, Codable, CaseIterable, Comparable, Identifiable, Sendable {
    case small
    case medium
    case large

    var id: String { rawValue }

    private var rank: Int {
        switch self {
        case .small: return 0
        case .medium: return 1
        case .large: return 2
        }
    }

    static func < (lhs: DogSize, rhs: DogSize) -> Bool { lhs.rank < rhs.rank }

    /// 「小型犬」「中型犬」「大型犬」
    var displayName: String {
        switch self {
        case .small: return String(localized: "小型犬")
        case .medium: return String(localized: "中型犬")
        case .large: return String(localized: "大型犬")
        }
    }

    /// 検索バーの犬ボタンに添える頭文字（「小」「中」「大」）
    var initial: String {
        switch self {
        case .small: return String(localized: "小")
        case .medium: return String(localized: "中")
        case .large: return String(localized: "大")
        }
    }
}

/// お店での過ごし方（再設計 段階3）。データの `indoor_style` と同じ3語。
enum DogStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case floor
    case carrier
    case hold

    var id: String { rawValue }

    /// 設定の選択肢の表記
    var displayName: String {
        switch self {
        case .floor: return String(localized: "床で待てる")
        case .carrier: return String(localized: "カート・キャリー")
        case .hold: return String(localized: "抱っこ")
        }
    }

    /// 「〜での入店が明記されています」に続く短い表記
    var admissionLabel: String {
        switch self {
        case .floor: return String(localized: "床（足元・席）")
        case .carrier: return String(localized: "カート・キャリー")
        case .hold: return String(localized: "抱っこ")
        }
    }
}

/// うちの子の設定（端末内のみ・名前などの個人情報は持たない, 憲章 原則III）。
struct DogProfile: Codable, Equatable, Sendable {
    var size: DogSize
    var styles: Set<DogStyle>

    init(size: DogSize, styles: Set<DogStyle> = []) {
        self.size = size
        self.styles = styles
    }

    /// 並びを固定した過ごし方（床→カート・キャリー→抱っこ）
    var orderedStyles: [DogStyle] {
        DogStyle.allCases.filter { styles.contains($0) }
    }

    /// 「床で待てる、抱っこ」。未選択なら nil
    var stylesSummary: String? {
        let names = orderedStyles.map(\.displayName)
        return names.isEmpty ? nil : names.joined(separator: "、")
    }
}
