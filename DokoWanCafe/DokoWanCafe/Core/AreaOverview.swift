import Foundation

/// エリア（`Cafe.subArea` の区分）ごとの集計。地図を東京全体が見えるほど引いたとき、ピンの代わりに出す「エリア名＋件数」の元になる。
/// 純ロジック・UI非依存（憲章 原則IV）。件数は今効いている条件（`displayedResults`）で数える。
struct AreaSummary: Equatable, Identifiable, Sendable {
    let name: String
    let count: Int
    /// ラベルを置く点（そのエリアの表示中の店の座標の中央値。外れ値で大きくずれない）
    let centerLatitude: Double
    let centerLongitude: Double
    /// 表示中の店が収まる範囲
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    var id: String { name }
}

enum AreaOverview {
    /// この緯度幅（度）以上に引いたらエリア表示にする（約33km。東京の中心部がおおむね入る）
    static let enterLatitudeDelta = 0.30
    /// エリア表示のとき、この緯度幅を下回るまで寄せたらピン表示に戻す。入る値より小さくして、境目でのちらつきを防ぐ（ヒステリシス）
    static let exitLatitudeDelta = 0.24

    /// 今エリア表示にするか。いま表示中かどうか（`wasOverview`）で境目の値を変える
    static func isOverview(latitudeDelta: Double, wasOverview: Bool) -> Bool {
        guard latitudeDelta.isFinite else { return wasOverview }
        return wasOverview ? latitudeDelta >= exitLatitudeDelta : latitudeDelta >= enterLatitudeDelta
    }

    /// 表示中の店をエリアごとに数える。エリア名が空の店は数えない。件数の多い順（同数は名前順）
    static func summaries(for items: [CafeWithDistance]) -> [AreaSummary] {
        var grouped: [String: [Cafe]] = [:]
        for item in items {
            let cafe = item.cafe
            guard cafe.latitude.isFinite, cafe.longitude.isFinite,
                  let name = cafe.subArea?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            grouped[name, default: []].append(cafe)
        }
        let summaries = grouped.map { name, cafes -> AreaSummary in
            let latitudes = cafes.map(\.latitude), longitudes = cafes.map(\.longitude)
            return AreaSummary(
                name: name, count: cafes.count,
                centerLatitude: median(latitudes), centerLongitude: median(longitudes),
                minLatitude: latitudes.min() ?? 0, maxLatitude: latitudes.max() ?? 0,
                minLongitude: longitudes.min() ?? 0, maxLongitude: longitudes.max() ?? 0
            )
        }
        return summaries.sorted { lhs, rhs in
            lhs.count != rhs.count ? lhs.count > rhs.count : lhs.name < rhs.name
        }
    }

    /// 寄せる範囲（中心と緯度経度の幅）
    struct FitRegion: Equatable, Sendable {
        let centerLatitude: Double
        let centerLongitude: Double
        let latitudeDelta: Double
        let longitudeDelta: Double
    }

    /// 寄せた範囲の余白（店の広がりに対する倍率）
    static let fitPaddingFactor = 1.4
    /// 寄せる範囲の最小の幅（度）。1店だけのエリアなどで寄りすぎない
    static let fitMinDelta = 0.012
    /// 寄せる範囲の最大の幅（度）。広がったエリアでも、寄せたあとはピン表示に戻る幅（`exitLatitudeDelta` を下回る）に収める。
    /// 縦長の画面では経度の幅も縦方向に換算されて広がるので、経度の上限は緯度より小さくする
    static let fitMaxLatitudeDelta = 0.15
    static let fitMaxLongitudeDelta = 0.10

    /// そのエリアの店が収まる範囲。中心は範囲の真ん中（ラベルの点とは別。範囲に収めるため）
    static func fitRegion(for area: AreaSummary) -> FitRegion {
        let latitudeDelta = min(max((area.maxLatitude - area.minLatitude) * fitPaddingFactor, fitMinDelta), fitMaxLatitudeDelta)
        let longitudeDelta = min(max((area.maxLongitude - area.minLongitude) * fitPaddingFactor, fitMinDelta), fitMaxLongitudeDelta)
        return FitRegion(
            centerLatitude: (area.minLatitude + area.maxLatitude) / 2,
            centerLongitude: (area.minLongitude + area.maxLongitude) / 2,
            latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta
        )
    }

    /// 衝突で間引くときの優先度（0〜1。件数が多いほど高い）。ラベル同士が重なったら件数の多い方が残る
    static func priority(count: Int, maxCount: Int) -> Double {
        guard maxCount > 0 else { return 0 }
        return min(max(Double(count) / Double(maxCount), 0), 1)
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }
}
