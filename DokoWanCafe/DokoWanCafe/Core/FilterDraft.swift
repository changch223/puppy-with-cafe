import Foundation

/// 「絞り込み」シートの下書きと、0件のときの「外すと増える条件」の純ロジック（憲章 原則IV）。
/// 下書きは ViewModel の条件（店内OK・テラス・大型犬OK・犬メニュー・営業中・うちの子OK・未確認も表示）と同じ項目を持ち、
/// 「◯件を表示」で反映するまで ViewModel には触れない。「いつ行く？」の対象時刻は下書きに含めない（別のシートで決める）。
struct FilterDraft: Equatable, Sendable {
    var amenities = AmenityFilter()
    var openNowOnly = false
    var myDogOnly = false
    var includeUnverified = false

    /// 条件1つ。宣言の並びが「外す影響が小さい順」（`relaxationOrder`）。
    enum Condition: Hashable, Sendable {
        case includeUnverified
        case dogMenu
        case largeDog
        case terrace
        case indoor
        case openNow
        case myDog

        /// 条件の名前（チップ・行と同じ言い方）。営業中は、対象時刻があるときは「その時間に営業」
        func title(isTargetTime: Bool = false) -> String {
            switch self {
            case .includeUnverified: return String(localized: "未確認も表示")
            case .dogMenu: return String(localized: "犬メニュー")
            case .largeDog: return String(localized: "大型犬OK")
            case .terrace: return String(localized: "テラス")
            case .indoor: return String(localized: "店内OK")
            case .openNow: return isTargetTime ? String(localized: "その時間に営業") : String(localized: "営業中")
            case .myDog: return String(localized: "うちの子OK")
            }
        }
    }

    /// 件数が同じときに先に外す条件の順（外す影響が小さい順）。
    /// - 未確認も表示: 店の特徴は変えず、可否が確かめられていない店を足すだけ（外しても利用者の目的は変わらない）
    /// - 犬メニュー → 大型犬OK → テラス → 店内OK: あれば嬉しい付加条件から、過ごす席という犬連れの根幹に近い条件へ
    /// - 営業中: 行く時間という前提（「いつ行く？」で決めた時刻も含む）。外すと「今すぐ行ける店」でなくなる
    /// - うちの子OK: その子が入れるかという最も根幹の条件なので、最後まで外さない
    /// 件数が増えるもの同士が並んだとき、この順で前にあるものを提案する（提案の根拠が「外しても困らないものから」になる）。
    static let relaxationOrder: [Condition] = [
        .includeUnverified, .dogMenu, .largeDog, .terrace, .indoor, .openNow, .myDog,
    ]

    func isOn(_ condition: Condition) -> Bool {
        switch condition {
        case .includeUnverified: return includeUnverified
        case .dogMenu: return amenities.dogMenuOnly
        case .largeDog: return amenities.largeDogOnly
        case .terrace: return amenities.terraceOnly
        case .indoor: return amenities.indoorOnly
        case .openNow: return openNowOnly
        case .myDog: return myDogOnly
        }
    }

    /// 条件を1つ外した下書き
    func removing(_ condition: Condition) -> FilterDraft {
        var copy = self
        switch condition {
        case .includeUnverified: copy.includeUnverified = false
        case .dogMenu: copy.amenities.dogMenuOnly = false
        case .largeDog: copy.amenities.largeDogOnly = false
        case .terrace: copy.amenities.terraceOnly = false
        case .indoor: copy.amenities.indoorOnly = false
        case .openNow: copy.openNowOnly = false
        case .myDog: copy.myDogOnly = false
        }
        return copy
    }

    /// オンの条件（`relaxationOrder` の並び）
    var activeConditions: [Condition] {
        Self.relaxationOrder.filter(isOn)
    }

    /// オンの条件の数（「絞り込み」チップのバッジ）
    var activeCount: Int { activeConditions.count }

    // MARK: - 外すと増える条件

    /// 条件を1つ外したときの件数
    struct Relaxation: Equatable, Sendable {
        let condition: Condition
        let count: Int

        /// 「「大型犬OK」を外すと12件」
        func title(isTargetTime: Bool = false) -> String {
            String(localized: "「\(condition.title(isTargetTime: isTargetTime))」を外すと\(count)件")
        }
    }

    /// オンの条件を1つずつ外したときの件数（`relaxationOrder` の並び）。
    /// - Parameter count: 下書きの条件で数える関数（テストでは偽の数え方を渡せる）
    func relaxations(count: (FilterDraft) -> Int) -> [Relaxation] {
        activeConditions.map { Relaxation(condition: $0, count: count(removing($0))) }
    }

    /// 外すと今より件数がいちばん増える条件。件数が同じなら `relaxationOrder` で前にあるもの。
    /// どれを外しても増えない（または何もオンでない）ときは nil。
    func bestRelaxation(count: (FilterDraft) -> Int) -> Relaxation? {
        let current = count(self)
        var best: Relaxation?
        for relaxation in relaxations(count: count) where relaxation.count > max(current, best?.count ?? 0) {
            best = relaxation
        }
        return best
    }

    // MARK: - 文言

    /// シートの下のボタン。0件のときは理由を言う（ボタンは無効にする）
    /// 「◯件を表示」のボタンの文言。`hasAnyResult` が false（条件をすべて外しても0件＝対象エリア外・読み込み前など）のときは、
    /// 0件の理由が条件ではないので「この条件では」と言わず「条件を反映」にする（押せる）
    static func applyButtonTitle(count: Int, hasAnyResult: Bool = true) -> String {
        if !hasAnyResult { return String(localized: "条件を反映") }
        return count > 0 ? String(localized: "\(count)件を表示") : String(localized: "この条件では0件")
    }

    /// 「絞り込み」チップの VoiceOver 読み上げ（「絞り込み、2件オン」。オンがなければ「絞り込み」）
    static func chipAccessibilityLabel(activeCount: Int) -> String {
        activeCount > 0 ? String(localized: "絞り込み、\(activeCount)件オン") : String(localized: "絞り込み")
    }
}
