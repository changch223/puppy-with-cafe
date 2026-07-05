import Foundation

/// 距離計算（純ロジック・UI非依存, 憲章 原則IV）。
/// ハバースイン公式による2点間の概算直線距離（メートル）。
/// 仕様上「距離」はおおよその近さで足りる（spec.md Assumptions）。
enum DistanceCalculator {
    /// 地球平均半径（メートル）
    private static let earthRadiusMeters = 6_371_000.0

    static func distanceMeters(
        fromLatitude: Double, fromLongitude: Double,
        toLatitude: Double, toLongitude: Double
    ) -> Double {
        let lat1 = fromLatitude * .pi / 180
        let lat2 = toLatitude * .pi / 180
        let dLat = (toLatitude - fromLatitude) * .pi / 180
        let dLng = (toLongitude - fromLongitude) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }
}
