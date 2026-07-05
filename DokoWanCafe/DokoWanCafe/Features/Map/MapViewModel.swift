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
