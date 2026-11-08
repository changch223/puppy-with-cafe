import Foundation

/// 同じ場所（5m 以内）の店を1つの組にまとめる純ロジック（UI非依存, 憲章 原則IV）。
/// 同じ建物の店は座標が完全に同じ（または数m差）で、地図のピンが重なって1店しか選べなくなる。
/// 座標をずらすと位置を偽る（原則I）ので、1本のピン＋数のバッジにまとめ、カードで店を切り替えられるようにする。
enum SameSpotGrouping {
    /// 同じ場所とみなす距離（メートル）。最大ズームでピン（幅30pt）が重なる約4mを覆う
    static let thresholdMeters: Double = 5

    /// カードで組を求めるとき、選択中の店からこの距離（メートル）以内の店だけを調べる（5m の連結が100mを超えることは実際にはない）
    static let cardSearchRadiusMeters: Double = 100

    /// 緯度1度あたりのメートル（格子の大きさ用。実際の約111.2km より小さめにして、格子を5m以上に保つ）
    private static let metersPerDegree = 111_000.0

    private struct Cell: Hashable {
        let x: Int
        let y: Int
    }

    /// 表示中の店を同じ場所ごとの組に分ける。単独の店も要素1つの組として返す。
    /// 5m 以内は連結でまとめる（A–B 4m・B–C 4m なら A・B・C で1組）。
    /// 各組の先頭が代表（ピンの見た目に使う店）: ①行きたい ②営業時間外で薄くない ③可否の分類 ④店名 ⑤id の順。
    /// 組同士は代表の距離順。緯度経度を約5mの格子に入れ、隣の9マスだけ比べるので全組合せは比べない。
    static func groups(
        for items: [CafeWithDistance],
        favoriteIDs: Set<UUID>,
        at date: Date
    ) -> [[CafeWithDistance]] {
        guard !items.isEmpty else { return [] }

        // 緯度経度が非有限・範囲外の店は格子に入れず、単独の組にする（Int への変換で落ちない・ほかの店と誤ってまとめない）
        let validIndices = items.indices.filter { isValidCoordinate(items[$0]) }

        // 経度方向の格子は、いちばん北（cos が最小＝経度1度が最短）の緯度で決める。どの店でも格子が5m以上になる
        let maxLatitude = validIndices.map { abs(items[$0].cafe.latitude) }.max() ?? 0
        let cosLatitude = max(cos(maxLatitude * .pi / 180), 0.01)
        let cellLatitude = thresholdMeters / metersPerDegree
        let cellLongitude = thresholdMeters / (metersPerDegree * cosLatitude)

        var cells: [Cell: [Int]] = [:]
        var cellOfItem: [Int: Cell] = [:]
        for index in validIndices {
            let item = items[index]
            let cell = Cell(
                x: Int((item.cafe.longitude / cellLongitude).rounded(.down)),
                y: Int((item.cafe.latitude / cellLatitude).rounded(.down))
            )
            cells[cell, default: []].append(index)
            cellOfItem[index] = cell
        }

        // union-find で連結成分にまとめる
        var parent = Array(0..<items.count)
        func find(_ index: Int) -> Int {
            var root = index
            while parent[root] != root { root = parent[root] }
            var current = index
            while parent[current] != root {
                let next = parent[current]
                parent[current] = root
                current = next
            }
            return root
        }
        for index in validIndices {
            let item = items[index]
            guard let cell = cellOfItem[index] else { continue }
            for dx in -1...1 {
                for dy in -1...1 {
                    guard let neighbors = cells[Cell(x: cell.x + dx, y: cell.y + dy)] else { continue }
                    for other in neighbors where other > index {
                        let distance = DistanceCalculator.distanceMeters(
                            fromLatitude: item.cafe.latitude, fromLongitude: item.cafe.longitude,
                            toLatitude: items[other].cafe.latitude, toLongitude: items[other].cafe.longitude
                        )
                        if distance <= thresholdMeters {
                            let a = find(index), b = find(other)
                            if a != b { parent[b] = a }
                        }
                    }
                }
            }
        }

        var members: [Int: [CafeWithDistance]] = [:]
        for (index, item) in items.enumerated() {
            members[find(index), default: []].append(item)
        }

        let ranked: [[CafeWithDistance]] = members.values.map { group in
            guard group.count > 1 else { return group }
            let keyed = group.map { item -> (item: CafeWithDistance, key: SortKey) in
                let isFavorite = favoriteIDs.contains(item.cafe.id)
                let style = MapPinStyle.make(for: item.cafe, isFavorite: isFavorite, at: date)
                return (item, SortKey(
                    notFavorite: !isFavorite,
                    isDimmed: style.isDimmed,
                    categoryOrder: categoryOrder(style.category),
                    name: item.cafe.name,
                    id: item.cafe.id.uuidString
                ))
            }
            return keyed.sorted { $0.key < $1.key }.map(\.item)
        }
        return ranked.sorted { lhs, rhs in
            let l = lhs[0], r = rhs[0]
            if l.distanceMeters != r.distanceMeters { return l.distanceMeters < r.distanceMeters }
            return l.cafe.id.uuidString < r.cafe.id.uuidString
        }
    }

    /// 緯度経度が有限で、緯度 ±90・経度 ±180 の範囲内か
    private static func isValidCoordinate(_ item: CafeWithDistance) -> Bool {
        let latitude = item.cafe.latitude, longitude = item.cafe.longitude
        return latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
    }

    /// 組の中での代表の並び順の鍵（小さいほど先頭）
    private struct SortKey: Comparable {
        let notFavorite: Bool
        let isDimmed: Bool
        let categoryOrder: Int
        let name: String
        let id: String

        static func < (lhs: SortKey, rhs: SortKey) -> Bool {
            if lhs.notFavorite != rhs.notFavorite { return !lhs.notFavorite }
            if lhs.isDimmed != rhs.isDimmed { return !lhs.isDimmed }
            if lhs.categoryOrder != rhs.categoryOrder { return lhs.categoryOrder < rhs.categoryOrder }
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.id < rhs.id
        }
    }

    /// 可否の分類の並び（店内OK → テラスのみ → 条件を確認 → 未確認）
    private static func categoryOrder(_ category: MapPinCategory) -> Int {
        switch category {
        case .indoorOK: return 0
        case .terraceOnly: return 1
        case .checkDetail: return 2
        case .unverified: return 3
        }
    }

    /// カードの「同じ場所」の列に使う、選択中の店と同じ組。全件ではなく選択中の店から `cardSearchRadiusMeters` 以内の店だけに絞ってから
    /// `groups` で組を求める（並びは地図と同じ関数で決まる）。選択中の店が入っていなければ nil。
    static func group(
        of selected: CafeWithDistance,
        in items: [CafeWithDistance],
        favoriteIDs: Set<UUID>,
        at date: Date
    ) -> [CafeWithDistance]? {
        let nearby = items.filter {
            $0.cafe.id == selected.cafe.id || DistanceCalculator.distanceMeters(
                fromLatitude: selected.cafe.latitude, fromLongitude: selected.cafe.longitude,
                toLatitude: $0.cafe.latitude, toLongitude: $0.cafe.longitude
            ) <= cardSearchRadiusMeters
        }
        return group(containing: selected.cafe.id, in: groups(for: nearby, favoriteIDs: favoriteIDs, at: date))
    }

    /// 指定した店が入っている組（無ければ nil）。カードの「同じ場所」の列に使う。
    static func group(containing id: UUID, in groups: [[CafeWithDistance]]) -> [CafeWithDistance]? {
        groups.first { group in group.contains { $0.cafe.id == id } }
    }
}
