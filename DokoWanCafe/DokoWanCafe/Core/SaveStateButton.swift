import Foundation

/// 保存の操作（詳細画面の固定バーの「行きたい」ボタンとそのメニュー）。
/// 「行った」を「行きたい」のボタンにまとめたので、状態遷移をここで1か所に決める（純ロジック・UI非依存, 憲章 原則IV）。
enum SaveAction: Equatable, Sendable {
    /// 行きたいに入れる（未保存から）
    case addWantToGo
    /// 行ったに記録する（未保存・行きたいから。行きたいからは外れる）
    case markVisited
    /// 行きたいに戻す（行ったから。行った記録は外れる）
    case backToWantToGo
    /// 保存から外す（行きたい・行ったのどちらからも）
    case removeFromSaved

    /// メニュー項目の文言（「外す」は今の状態で言い方が変わる）
    func menuTitle(from status: SavedStatus?) -> String {
        switch self {
        case .addWantToGo: return String(localized: "行きたいに入れる")
        case .markVisited: return String(localized: "行ったに記録する")
        case .backToWantToGo: return String(localized: "行きたいに戻す（行った記録は消えます）")
        case .removeFromSaved:
            return status == .wantToGo ? String(localized: "行きたいから外す") : String(localized: "保存から外す")
        }
    }

    var systemImage: String {
        switch self {
        case .addWantToGo, .backToWantToGo: return "pawprint"
        case .markVisited: return "checkmark.circle"
        case .removeFromSaved: return "xmark.circle"
        }
    }

    var isDestructive: Bool { self == .removeFromSaved }
}

/// 保存の状態ボタン1つ分の表示と動き。
struct SaveStateButton: Equatable, Sendable {
    /// ボタンの文言（「行きたい」「行きたい ✓」「行った ✓ 11/3」）
    let title: String
    let systemImage: String
    /// VoiceOver の読み（今の状態と、タップしたときの動きが分かる文）
    let accessibilityLabel: String
    /// タップ1回の動き。nil＝タップでメニューを開く（行った記録を誤って消さない）
    let tapAction: SaveAction?
    /// 長押し（タップが nil のときはタップ）で開くメニューの項目
    let menuActions: [SaveAction]
    let status: SavedStatus?

    static func make(status: SavedStatus?, visitedDate: Date?) -> SaveStateButton {
        switch status {
        case nil:
            return SaveStateButton(
                title: String(localized: "行きたい"),
                systemImage: "pawprint",
                accessibilityLabel: String(localized: "行きたいに入れる。長押しで行ったに記録できます"),
                tapAction: .addWantToGo,
                menuActions: [.addWantToGo, .markVisited],
                status: nil
            )
        case .wantToGo?:
            return SaveStateButton(
                title: String(localized: "行きたい ✓"),
                systemImage: "pawprint.fill",
                accessibilityLabel: String(localized: "行きたいに入っています。タップで外します。長押しで行ったに記録できます"),
                tapAction: .removeFromSaved,
                menuActions: [.markVisited, .removeFromSaved],
                status: .wantToGo
            )
        case .visited?:
            let dateText = visitedDate.map(TargetTime.monthDayText)
            let title = dateText.map { String(localized: "行った ✓ \($0)") } ?? String(localized: "行った ✓")
            let label = dateText.map { String(localized: "行った記録があります、\($0)。タップで操作を選びます") }
                ?? String(localized: "行った記録があります。タップで操作を選びます")
            return SaveStateButton(
                title: title,
                systemImage: "checkmark.circle.fill",
                accessibilityLabel: label,
                tapAction: nil,
                menuActions: [.backToWantToGo, .removeFromSaved],
                status: .visited
            )
        }
    }
}

extension SavedPlaces {
    /// 保存の操作を当てる。トグルではなく結果が決まっている操作なので、すでにその状態なら何も変えない
    /// （例: 行った店に「行ったに記録する」を重ねても行った日は動かない）。
    mutating func apply(_ action: SaveAction, to id: UUID, at date: Date) {
        switch action {
        case .addWantToGo, .backToWantToGo:
            if status(of: id) != .wantToGo { toggleWantToGo(id, at: date) }
        case .markVisited:
            if status(of: id) != .visited { toggleVisited(id, at: date) }
        case .removeFromSaved:
            remove(id)
        }
    }
}
