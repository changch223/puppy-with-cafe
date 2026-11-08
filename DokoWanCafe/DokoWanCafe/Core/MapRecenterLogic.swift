import CoreLocation
import Foundation

/// 地図を動かしたあとの「このあたりで探す」ボタンを出すかの判定（純ロジック・UI非依存, 憲章 原則IV）。
/// 地図の中心は端末の中で並び順と距離に使うだけで、保存も送信もしない（原則III）。
enum MapRecenterLogic {
    /// ボタンを出す最低の距離（メートル）。ちょっとした動きでは出さない
    static let minDistanceMeters: Double = 500
    /// 見えている範囲の幅に対する割合の下限（地図の中心が検索地点から幅の半分以上離れたら出す）
    static let minWidthRatio: Double = 0.5

    /// 緯度1度あたりのメートル（概算。`MapViewModel` と同じ値）
    private static let metersPerDegree = 111_320.0

    /// 見えている範囲の幅（メートル）。経度方向の広がり（`longitudeDelta`）を緯度で補正して求める。
    static func visibleWidthMeters(longitudeDelta: Double, latitude: Double) -> Double {
        longitudeDelta * metersPerDegree * cos(latitude * .pi / 180)
    }

    /// 「このあたりで探す」を出すか。次のすべてを満たしたときだけ true。
    /// 1. ユーザーが地図を動かした（プログラムの setRegion ではない）
    /// 2. 地図の中心と検索地点の距離が、500m 以上かつ見えている範囲の幅の半分以上
    /// 3. 地図の中心が提供エリアの中（外で押すと「対象エリア外」の画面で地図が隠れるため出さない）
    /// 4. 選択中の店のカードが出ていない、かつ一覧シートが最大まで開いていない
    static func shouldOffer(
        didUserMove: Bool,
        mapCenter: CLLocationCoordinate2D,
        visibleWidthMeters: Double,
        searchCenter: CLLocationCoordinate2D?,
        hasSelectedCard: Bool,
        isSheetLarge: Bool
    ) -> Bool {
        guard didUserMove, !hasSelectedCard, !isSheetLarge, let searchCenter else { return false }
        guard CLLocationCoordinate2DIsValid(mapCenter), visibleWidthMeters.isFinite, visibleWidthMeters > 0 else { return false }
        guard SupportedArea.area(containingLatitude: mapCenter.latitude, longitude: mapCenter.longitude) != nil else { return false }
        let distance = DistanceCalculator.distanceMeters(
            fromLatitude: searchCenter.latitude, fromLongitude: searchCenter.longitude,
            toLatitude: mapCenter.latitude, toLongitude: mapCenter.longitude
        )
        return distance >= max(minDistanceMeters, visibleWidthMeters * minWidthRatio)
    }
}
