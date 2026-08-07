import MapKit
import UIKit

/// 地図用アノテーション。一覧と同一の `CafeWithDistance` を保持する（FR-003）。
final class CafeAnnotation: NSObject, MKAnnotation {
    let item: CafeWithDistance
    /// 数字クラスタの代わりにMapKitの衝突間引きへ渡す表示優先度（近い店ほど高い, UI/UXブラッシュアップ設計書2）
    let displayPriority: MKFeatureDisplayPriority

    init(item: CafeWithDistance, displayPriority: MKFeatureDisplayPriority) {
        self.item = item
        self.displayPriority = displayPriority
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: item.cafe.latitude, longitude: item.cafe.longitude)
    }

    /// `titleVisibility = .adaptive` で低ズーム時は隠れ、ズームインすると店名ラベルとして表示される
    var title: String? { item.cafe.name }
}

/// 地図表示の純粋なプレゼンテーションロジック（T027 / UI/UXブラッシュアップ設計書2）。
/// 一覧側と同じ `displayedResults` からアノテーションを構築することで乖離を防ぐ。
enum MapViewModel {
    static func annotations(for items: [CafeWithDistance]) -> [CafeAnnotation] {
        let priorityByID = displayPriorities(for: items)
        return items.map { item in
            CafeAnnotation(item: item, displayPriority: priorityByID[item.cafe.id] ?? .defaultLow)
        }
    }

    /// アノテーション集合の同一性キー（ピン色・お気に入り区別に関わる情報が変わった時だけ再描画する）
    static func signature(of items: [CafeWithDistance], favoriteIDs: Set<UUID>) -> Set<String> {
        Set(items.map { item in
            let category = MapPinCategory.category(for: item.cafe)
            let isFavorite = favoriteIDs.contains(item.cafe.id)
            return "\(item.cafe.id.uuidString)-\(category)-\(isFavorite)"
        })
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

    /// 数字クラスタ廃止の代替（UI/UXブラッシュアップ設計書2）: 距離順の上位何件目までを
    /// 各段（必ず表示=required／中距離=defaultHigh）とするかの境界ランク。
    /// これ以降（遠い店）は defaultLow とし、MapKit標準の衝突間引きに委ねることで、
    /// Googleマップ同様「ズームインすると増える」挙動を実現する。
    static let requiredPinRank = 5
    static let highPriorityPinRank = 15

    /// 距離順ランク（0=最寄り）から displayPriority を段階設定する純ロジック。
    static func displayPriority(rank: Int) -> MKFeatureDisplayPriority {
        if rank < requiredPinRank { return .required }
        if rank < highPriorityPinRank { return .defaultHigh }
        return .defaultLow
    }

    /// 距離昇順にランク付けし、各カフェIDへ displayPriority を割り当てる。
    static func displayPriorities(for items: [CafeWithDistance]) -> [UUID: MKFeatureDisplayPriority] {
        let sortedByDistance = items.sorted { $0.distanceMeters < $1.distanceMeters }
        var result: [UUID: MKFeatureDisplayPriority] = [:]
        for (rank, item) in sortedByDistance.enumerated() {
            result[item.cafe.id] = displayPriority(rank: rank)
        }
        return result
    }

    /// 犬目線ピン分類に応じたマーカー色（旧 `markerTintColor(for: DogPolicyStatus)` を置換,
    /// UI/UXブラッシュアップ設計書1a/2）。「不可(赤)」は廃止（実データ0件・UI廃止方針）。
    static func markerTintColor(for category: MapPinCategory) -> UIColor {
        switch category {
        case .indoorOK: return .systemGreen
        case .terraceOnly: return .systemTeal
        case .checkDetail: return .systemOrange
        case .unverified: return .systemGray
        }
    }

    /// 経路案内で外部地図アプリを開く（地図の下部コンパクトカード「経路」ボタン, UI/UXブラッシュアップ設計書2）。
    static func openInMaps(cafe: Cafe) {
        let placemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: cafe.latitude, longitude: cafe.longitude)
        )
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = cafe.name
        mapItem.openInMaps(launchOptions: nil)
    }

    static func distanceText(meters: Double) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: meters)
    }
}
