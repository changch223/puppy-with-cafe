import Foundation

/// 詳細の先頭の小さな地図（スナップショット）のキャッシュキー。店×外観（ライト/ダーク）×幅で作り直す。
/// 幅は画面の回転・分割で細かく変わっても作り直しすぎないよう、整数にそろえる。
struct MapSnapshotKey: Hashable, Sendable {
    let cafeID: UUID
    let isDark: Bool
    let width: Int
    /// 座標（10万分の1度に丸め）。データの更新で同じ店の座標が変わったら作り直す
    let latitudeE5: Int
    let longitudeE5: Int

    init(cafeID: UUID, isDark: Bool, width: Double, latitude: Double = 0, longitude: Double = 0) {
        self.cafeID = cafeID
        self.isDark = isDark
        self.width = Int(width.rounded())
        self.latitudeE5 = Int((latitude * 100_000).rounded())
        self.longitudeE5 = Int((longitude * 100_000).rounded())
    }
}
