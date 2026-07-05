import Foundation

/// 提供エリア判定（FR-022: 対象範囲外を「該当0件」と誤認させない。
/// 純ロジック・UI非依存, 憲章 原則IV）。
///
/// 注: 境界ボックスによる概算判定（クライアント側のヒント用途）。
/// 東京都の本土をおおむね覆うが、県境付近では誤差があり、島嶼部（伊豆・小笠原）は対象外。
/// 正式な提供対象はサーバ側の `cafes.area` カラムで管理する。
struct SupportedArea: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    func contains(latitude: Double, longitude: Double) -> Bool {
        (minLatitude...maxLatitude).contains(latitude)
            && (minLongitude...maxLongitude).contains(longitude)
    }

    /// v1 の提供エリア: 東京（本土）
    static let tokyo = SupportedArea(
        id: "tokyo",
        displayName: "東京",
        minLatitude: 35.50,
        maxLatitude: 35.90,
        minLongitude: 138.94,
        maxLongitude: 139.92
    )

    /// 提供中のエリア一覧（段階拡大, FR-022）
    static let all: [SupportedArea] = [.tokyo]

    /// 座標を含む提供エリアを返す（どこにも含まれなければ nil = 対象範囲外）
    static func area(containingLatitude latitude: Double, longitude: Double) -> SupportedArea? {
        all.first { $0.contains(latitude: latitude, longitude: longitude) }
    }
}
