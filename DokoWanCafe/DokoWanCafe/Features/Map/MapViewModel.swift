import MapKit
import UIKit

/// 地図用アノテーション。一覧と同一の `CafeWithDistance` を保持する（FR-003）。
/// ピンの見た目（`style`）や距離・優先度が変わったときは、作り直さず同じ注釈の値を更新する
/// （選択中のピンを選択解除させないため）。
final class CafeAnnotation: NSObject, MKAnnotation {
    var item: CafeWithDistance
    /// 数字クラスタの代わりにMapKitの衝突間引きへ渡す表示優先度（近い店ほど高い）
    var displayPriority: MKFeatureDisplayPriority
    var style: MapPinStyle
    /// VoiceOver で読む文（対象時刻・保存の状態が変わったら作り直す）
    var spokenLabel: String

    init(item: CafeWithDistance, displayPriority: MKFeatureDisplayPriority, style: MapPinStyle, spokenLabel: String) {
        self.item = item
        self.displayPriority = displayPriority
        self.style = style
        self.spokenLabel = spokenLabel
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: item.cafe.latitude, longitude: item.cafe.longitude)
    }

    var title: String? { item.cafe.name }
}

/// 地図表示の純粋なプレゼンテーションロジック（T027）。
/// 一覧側と同じ `displayedResults` からアノテーションを構築することで乖離を防ぐ。
enum MapViewModel {
    /// 起動時・検索地点変更時の表示範囲（一辺・メートル）。検索地点を中心に半径約800mが見える程度＝徒歩圏。
    static let walkingSpanMeters: Double = 1_600

    /// 検索地点を中心にした徒歩圏の表示領域
    static func walkingRegion(center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            latitudinalMeters: walkingSpanMeters,
            longitudinalMeters: walkingSpanMeters
        )
    }

    /// ピンの下に店名を出す縮尺の上限（地図の表示範囲の縦・横がどちらもこれ未満のとき。メートル）。
    /// 広い縮尺では名前を出さず（ごちゃつく）、ズームインしたときだけ店名で見分けられるようにする。
    static let pinNameMaxSpanMeters: Double = 600

    /// 緯度1度あたりのメートル（概算）
    private static let metersPerDegree = 111_320.0

    /// ズームしているとき（表示範囲が縦横とも `pinNameMaxSpanMeters` 未満）だけ、ピンの下に店名を出す。
    /// 重なりの間引きは MapKit の衝突回避に任せる。
    static func showsPinNames(span: MKCoordinateSpan, centerLatitude: Double) -> Bool {
        let heightMeters = span.latitudeDelta * metersPerDegree
        let widthMeters = span.longitudeDelta * metersPerDegree * cos(centerLatitude * .pi / 180)
        return heightMeters < pinNameMaxSpanMeters && widthMeters < pinNameMaxSpanMeters
    }

    /// 数字クラスタ廃止の代替: 距離順の上位何件目までを
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

    /// 表示結果から、各店のピンの見た目（形・色・お気に入り・薄さ）を決める。
    static func styles(
        for items: [CafeWithDistance],
        favoriteIDs: Set<UUID>,
        at date: Date
    ) -> [UUID: MapPinStyle] {
        Dictionary(
            items.map { ($0.cafe.id, MapPinStyle.make(for: $0.cafe, isFavorite: favoriteIDs.contains($0.cafe.id), at: date)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 各店のピンの VoiceOver ラベル。営業は `date`（対象時刻があればその時刻）の言い方で読み、
    /// 保存の状態（行きたいに登録済み／行った）も含める。「情報が古い可能性」は今（`clock`）で判定する。
    static func spokenLabels(
        for items: [CafeWithDistance],
        savedPlaces: SavedPlaces,
        at date: Date,
        isTargetTime: Bool,
        clock: Date,
        dog: DogProfile? = nil
    ) -> [UUID: String] {
        Dictionary(
            items.map {
                (
                    $0.cafe.id,
                    CafePresentation.accessibilityLabel(
                        for: $0,
                        savedStatus: savedPlaces.status(of: $0.cafe.id),
                        at: date,
                        isTargetTime: isTargetTime,
                        clock: clock,
                        dog: dog
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 現在表示中の注釈集合との差分（追加・削除）を求める純ロジック。
    /// 既存の注釈は消さずに値だけ更新するため、選択中のピンが選択解除されない。
    static func diff(existingIDs: Set<UUID>, newIDs: Set<UUID>) -> (added: Set<UUID>, removed: Set<UUID>) {
        (newIDs.subtracting(existingIDs), existingIDs.subtracting(newIDs))
    }
}
