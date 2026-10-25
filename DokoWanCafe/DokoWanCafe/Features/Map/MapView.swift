import MapKit
import SwiftUI
import UIKit

/// 地図画面（T026/T028・再設計 段階1a: 形と色で分かるピン・徒歩圏の縮尺）。
///
/// UIKit 使用理由（憲章 原則V に基づく明記）:
/// ピンの重なり対策として MKMapView 標準の displayPriority による衝突間引きが必要であり、
/// SwiftUI 標準 `Map` ではそれらの細かな制御ができないため、
/// `UIViewRepresentable` による橋渡しで MKMapView を使用する（research.md R2）。
struct CafeMapView: UIViewRepresentable {
    let items: [CafeWithDistance]
    /// `items` を計算し直した回数（`CafeListViewModel.displayRevision`）。変わったときだけピンの見た目を計算し直す。
    let itemsRevision: Int
    let center: CLLocationCoordinate2D?
    /// 保存済み店の視覚区別に使う
    let favoriteIDs: Set<UUID>
    /// 営業中かどうかの判定時刻（営業時間外の店のピンを薄くする）
    let now: Date
    /// タップ選択中のカフェ（一覧シートがその店のカードに変わる）。×やマップタップで nil に戻る双方向バインディング。
    @Binding var selectedItem: CafeWithDistance?
    /// インクリメントすると現在地（center）へ再センタリングする（現在地ボタンから使用）
    let recenterRequestID: Int

    private static let cafeReuseID = "cafe"

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        // アプリ全体のブランド色（緑）ではなく標準の青にする。現在地の点が店内OKの緑のピンと紛らわしくなるため。
        mapView.tintColor = .systemBlue
        mapView.pointOfInterestFilter = .excludingAll
        mapView.register(
            MKAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Self.cafeReuseID
        )
        mapView.accessibilityLabel = String(localized: "周辺の犬同伴OKカフェの地図")
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // 検索の起点が変わった時だけ表示領域を再設定する（ユーザーのパン操作を尊重）。
        // 座標は丸めて比較し、GPSの微小な揺れで毎回カメラがリセットされないようにする。
        if let center {
            let roundedLat = (center.latitude * 10_000).rounded() / 10_000
            let roundedLng = (center.longitude * 10_000).rounded() / 10_000
            let regionKey = "\(roundedLat),\(roundedLng)"
            if coordinator.lastRegionKey != regionKey {
                let isFirst = coordinator.lastRegionKey == nil
                coordinator.lastRegionKey = regionKey
                mapView.setRegion(MapViewModel.walkingRegion(center: center), animated: !isFirst)
            }
        }

        // 現在地ボタンからの明示的な再センタリング要求。パン保持ロジックとは独立して常に反映する。
        if recenterRequestID != coordinator.lastRecenterRequestID {
            coordinator.lastRecenterRequestID = recenterRequestID
            if let center {
                mapView.setRegion(MapViewModel.walkingRegion(center: center), animated: true)
            }
        }

        coordinator.syncAnnotations(on: mapView)

        // ×ボタン等、地図の外からの選択解除をマップ側にも反映する
        if selectedItem == nil, let selected = mapView.selectedAnnotations.first {
            mapView.deselectAnnotation(selected, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CafeMapView
        var lastRegionKey: String?
        var lastRecenterRequestID = 0
        /// 直近に反映した（データの版, 保存済みID）。変わらなければ注釈の見た目を計算し直さない。
        private var lastSyncKey: SyncKey?
        private struct SyncKey: Equatable {
            let revision: Int
            let favoriteIDs: Set<UUID>
        }
        private var annotationsByID: [UUID: CafeAnnotation] = [:]

        init(parent: CafeMapView) {
            self.parent = parent
        }

        /// 表示結果との差分だけを反映する。残る注釈は作り直さず値を更新するので、選択中のピンの選択が外れない。
        func syncAnnotations(on mapView: MKMapView) {
            let key = SyncKey(revision: parent.itemsRevision, favoriteIDs: parent.favoriteIDs)
            guard key != lastSyncKey else { return }
            lastSyncKey = key
            let items = parent.items
            let styles = MapViewModel.styles(for: items, favoriteIDs: parent.favoriteIDs, at: parent.now)
            let priorities = MapViewModel.displayPriorities(for: items)
            let itemsByID = Dictionary(items.map { ($0.cafe.id, $0) }, uniquingKeysWith: { first, _ in first })

            // 座標が変わった店は作り直す（MKMapView は coordinate の変化を追わないため）
            var removedIDs = MapViewModel.diff(existingIDs: Set(annotationsByID.keys), newIDs: Set(itemsByID.keys)).removed
            for (id, annotation) in annotationsByID {
                if let item = itemsByID[id],
                   item.cafe.latitude != annotation.item.cafe.latitude || item.cafe.longitude != annotation.item.cafe.longitude {
                    removedIDs.insert(id)
                }
            }
            if !removedIDs.isEmpty {
                mapView.removeAnnotations(removedIDs.compactMap { annotationsByID[$0] })
                for id in removedIDs { annotationsByID[id] = nil }
            }

            var added: [CafeAnnotation] = []
            for (id, item) in itemsByID {
                let style = styles[id] ?? MapPinStyle.make(for: item.cafe, isFavorite: false, at: parent.now)
                let priority = priorities[id] ?? .defaultLow
                if let existing = annotationsByID[id] {
                    guard existing.item != item || existing.style != style || existing.displayPriority != priority else { continue }
                    existing.item = item
                    existing.style = style
                    existing.displayPriority = priority
                    if let view = mapView.view(for: existing) {
                        configure(view, for: existing, isSelected: mapView.selectedAnnotations.contains { $0 === existing })
                    }
                } else {
                    let annotation = CafeAnnotation(item: item, displayPriority: priority, style: style)
                    annotationsByID[id] = annotation
                    added.append(annotation)
                }
            }
            if !added.isEmpty { mapView.addAnnotations(added) }
        }

        private func configure(_ view: MKAnnotationView, for annotation: CafeAnnotation, isSelected: Bool) {
            let style = annotation.style
            let image = MapPinRenderer.image(for: style, isSelected: isSelected)
            view.image = image
            view.centerOffset = MapPinRenderer.centerOffset(for: style, image: image)
            // 営業時間が分かっていて今は時間外の店は薄く（選択中は見失わないよう通常の濃さ）
            view.alpha = isSelected ? 1 : style.alpha
            view.zPriority = isSelected ? .max : .defaultUnselected
            view.displayPriority = annotation.displayPriority
            view.canShowCallout = false
            view.clusteringIdentifier = nil
            view.accessibilityLabel = CafePresentation.accessibilityLabel(for: annotation.item, at: parent.now)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: CafeMapView.cafeReuseID,
                for: cafeAnnotation
            )
            configure(view, for: cafeAnnotation, isSelected: parent.selectedItem?.cafe.id == cafeAnnotation.item.cafe.id)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return }
            parent.selectedItem = cafeAnnotation.item
            if let view = mapView.view(for: annotation) {
                configure(view, for: cafeAnnotation, isSelected: true)
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return }
            if let view = mapView.view(for: annotation) {
                configure(view, for: cafeAnnotation, isSelected: false)
            }
            if parent.selectedItem?.cafe.id == cafeAnnotation.item.cafe.id {
                parent.selectedItem = nil
            }
        }
    }
}

/// MapPinCategory の小バッジ（詳細画面で使用）
struct MapPinCategoryBadge: View {
    let category: MapPinCategory

    var body: some View {
        Text(category.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch category {
        case .indoorOK: return .green
        case .terraceOnly: return .teal
        case .checkDetail: return .orange
        case .unverified: return .gray
        }
    }
}

/// 現在地（手動エリア選択中はその地点）へ再センタリングするFAB
struct CurrentLocationButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.body.bold())
                .frame(width: 44, height: 44)
        }
        .background(.regularMaterial, in: Circle())
        .foregroundStyle(Color.brand)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
        .accessibilityLabel(Text("現在地に戻る"))
    }
}
