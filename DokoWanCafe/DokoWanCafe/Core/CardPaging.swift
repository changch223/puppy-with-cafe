import CoreGraphics
import Foundation

/// 店のカードを横にめくるときの判定（純ロジック・UI非依存, 憲章 原則IV）。
/// めくる順は一覧（`displayedResults`）の並びそのもの。端では止まる（輪にしない）。
enum CardPaging {
    enum Direction: Equatable, Sendable {
        case previous
        case next
    }

    /// 一覧の中で何店目か（1始まり）と全部で何店か
    struct Position: Equatable, Sendable {
        let number: Int
        let total: Int

        /// 控えめな手がかり「2 / 12」
        var text: String { "\(number) / \(total)" }
        var hasPrevious: Bool { number > 1 }
        var hasNext: Bool { number < total }
    }

    static func index(of id: UUID, in items: [CafeWithDistance]) -> Int? {
        items.firstIndex { $0.cafe.id == id }
    }

    static func position(of id: UUID, in items: [CafeWithDistance]) -> Position? {
        guard let index = index(of: id, in: items) else { return nil }
        return Position(number: index + 1, total: items.count)
    }

    /// 指定の向きの隣の店。端（先頭で前へ・末尾で次へ）または一覧にいないときは nil
    static func neighbor(of id: UUID, direction: Direction, in items: [CafeWithDistance]) -> CafeWithDistance? {
        guard let index = index(of: id, in: items) else { return nil }
        let target = direction == .next ? index + 1 : index - 1
        guard items.indices.contains(target) else { return nil }
        return items[target]
    }

    /// 絞り込みや起点の変更のあとも、表示中の店がまだ一覧にいるか（いなければカードを閉じる）
    static func isStillListed(_ id: UUID, in items: [CafeWithDistance]) -> Bool {
        index(of: id, in: items) != nil
    }
}

/// めくった先のピンが、上の検索バー・チップと下のカードに隠れない範囲の外なら、地図を動かす判定（純ロジック）。
/// 座標は地図の View 上の点（pt）。ズームは変えず、中心だけを動かす。
enum MapReveal {
    /// ピンが見える範囲の端から空ける余白（ピンの大きさのぶん）
    static let margin: CGFloat = 32

    /// ピンの点が見える範囲（上を `coveredTop`・下を `coveredBottom` でふさがれた地図）の外なら、地図の中心にすべき点を返す。
    /// 見えているときは nil（地図は動かさない）。返す点は「今の画面での座標」で、`convert(_:toCoordinateFrom:)` で座標にして `setCenter` に渡す。
    /// 動かすときは、ピンが見える範囲の真ん中に来るようにする。
    static func centerPoint(
        pin: CGPoint, mapSize: CGSize, coveredTop: CGFloat, coveredBottom: CGFloat, margin: CGFloat = margin
    ) -> CGPoint? {
        guard mapSize.width > 0, mapSize.height > 0, pin.x.isFinite, pin.y.isFinite else { return nil }
        let top = max(coveredTop, 0), bottom = max(coveredBottom, 0)
        let isVisible = pin.x >= margin && pin.x <= mapSize.width - margin
            && pin.y >= top + margin && pin.y <= mapSize.height - bottom - margin
        guard !isVisible else { return nil }
        let bandCenter = CGPoint(x: mapSize.width / 2, y: (top + mapSize.height - bottom) / 2)
        return CGPoint(
            x: mapSize.width / 2 + (pin.x - bandCenter.x),
            y: mapSize.height / 2 + (pin.y - bandCenter.y)
        )
    }
}
