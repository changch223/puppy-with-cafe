import MapKit
import UIKit

/// 地図用アノテーション。一覧と同一の `CafeWithDistance` を保持する（FR-003）。
final class CafeAnnotation: NSObject, MKAnnotation {
    let item: CafeWithDistance

    init(item: CafeWithDistance) {
        self.item = item
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: item.cafe.latitude, longitude: item.cafe.longitude)
    }

    var title: String? { item.cafe.name }

    var subtitle: String? {
        let status = item.cafe.dogPolicyStatus.displayName
        let distance = MapViewModel.distanceText(meters: item.distanceMeters)
        return "\(status)・\(distance)"
    }
}

/// 地図表示の純粋なプレゼンテーションロジック（T027）。
/// 一覧側と同じ `displayedResults` からアノテーションを構築することで乖離を防ぐ。
enum MapViewModel {
    static func annotations(for items: [CafeWithDistance]) -> [CafeAnnotation] {
        items.map(CafeAnnotation.init(item:))
    }

    /// アノテーション集合の同一性キー（不要な再描画を避ける）
    static func signature(of items: [CafeWithDistance]) -> Set<String> {
        Set(items.map { "\($0.cafe.id.uuidString)-\($0.cafe.dogPolicyStatus.rawValue)" })
    }

    static func region(center: CLLocationCoordinate2D, radiusMeters: Int) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            latitudinalMeters: Double(radiusMeters) * 2.2,
            longitudinalMeters: Double(radiusMeters) * 2.2
        )
    }

    /// 地図の初期カメラ半径の下限・上限（UI専用の定数。データ取得の絞り込みには使わない）。
    /// 下限: 近すぎて周辺が見えない状態を避ける。上限: 疎な地点でも東京都内相当までしかズームアウトしない
    /// （実測: 全カフェの最大ペア間距離 約52.4km）。
    static let minInitialCameraMeters: Double = 3_000
    static let maxInitialCameraMeters: Double = 60_000
    /// 初期表示でおおむねこの順位の近さまでが視界に入ることを狙う
    static let targetVisiblePinRank = 5

    /// 実際のカフェとの距離分布から、初期カメラの半径（メートル）を算出する純ロジック（憲章 原則IV）。
    /// 近い順N件目までの距離を基準に、下限・上限でクランプすることで、
    /// 疎な地域でも「視界に1件も入らない空白の地図」を防ぐ（FR-001）。
    static func initialCameraSpanMeters(items: [CafeWithDistance]) -> Double {
        let sortedDistances = items.map(\.distanceMeters).sorted()
        // カフェが1件もない場合はバッファ倍率を掛けず、そのまま下限を返す
        guard !sortedDistances.isEmpty else { return minInitialCameraMeters }

        let target = sortedDistances.count >= targetVisiblePinRank
            ? sortedDistances[targetVisiblePinRank - 1]
            : sortedDistances[sortedDistances.count - 1]
        return min(max(target * 1.3, minInitialCameraMeters), maxInitialCameraMeters)
    }

    /// 現在地(center)と実際のカフェとの距離分布から、初期カメラの表示領域を算出する（FR-001）。
    static func initialCameraRegion(center: CLLocationCoordinate2D, items: [CafeWithDistance]) -> MKCoordinateRegion {
        region(center: center, radiusMeters: Int(initialCameraSpanMeters(items: items)))
    }

    /// 可否ステータスに応じたピン色（一覧の StatusBadge と対応）
    static func markerTintColor(for status: DogPolicyStatus) -> UIColor {
        switch status {
        case .allowed: return .systemGreen
        case .conditional: return .systemOrange
        case .notAllowed: return .systemRed
        case .unverified: return .systemGray
        }
    }

    static func distanceText(meters: Double) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: meters)
    }
}
