import Foundation

/// 詳細の先頭の小さな地図（スナップショット）のキャッシュキー。店×外観（ライト/ダーク）×幅で作り直す。
/// 幅は画面の回転・分割で細かく変わっても作り直しすぎないよう、整数にそろえる。
struct MapSnapshotKey: Hashable, Sendable {
    let cafeID: UUID
    let isDark: Bool
    let width: Int

    init(cafeID: UUID, isDark: Bool, width: Double) {
        self.cafeID = cafeID
        self.isDark = isDark
        self.width = Int(width.rounded())
    }
}
