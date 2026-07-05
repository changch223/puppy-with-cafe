import MapKit
import SwiftUI

/// 地図画面（T026/T028）。
///
/// UIKit 使用理由（憲章 原則V に基づく明記）:
/// ピンの重なり対策として MKMapView 標準のアノテーションクラスタリングが必要であり、
/// SwiftUI 標準 `Map`（iOS 16 時点）ではクラスタリング等の細かな制御ができないため、
/// `UIViewRepresentable` による橋渡しで MKMapView を使用する（research.md R2）。
struct CafeMapView: UIViewRepresentable {
    let items: [CafeWithDistance]
    let center: CLLocationCoordinate2D?
    let radiusMeters: Int
    let onSelect: (Cafe) -> Void

    private static let cafeReuseID = "cafe"

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Self.cafeReuseID
        )
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
        mapView.accessibilityLabel = String(localized: "周辺の犬同伴OKカフェの地図")
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onSelect = onSelect

        // 検索の起点・半径が変わったときだけ表示領域を再設定（ユーザーのパン操作を尊重）
        if let center {
            let regionKey = "\(center.latitude),\(center.longitude),\(radiusMeters)"
            if context.coordinator.lastRegionKey != regionKey {
                context.coordinator.lastRegionKey = regionKey
                mapView.setRegion(MapViewModel.region(center: center, radiusMeters: radiusMeters), animated: true)
            }
        }

        // アノテーション差分更新（同一データなら再描画しない）
        let newSignature = MapViewModel.signature(of: items)
        if context.coordinator.lastSignature != newSignature {
            context.coordinator.lastSignature = newSignature
            let existing = mapView.annotations.compactMap { $0 as? CafeAnnotation }
            mapView.removeAnnotations(existing)
            mapView.addAnnotations(MapViewModel.annotations(for: items))
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSelect: (Cafe) -> Void
        var lastRegionKey: String?
        var lastSignature: Set<String> = []

        init(onSelect: @escaping (Cafe) -> Void) {
            self.onSelect = onSelect
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            // クラスタ（複数ピンの集約）
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                    for: cluster
                ) as? MKMarkerAnnotationView
                view?.markerTintColor = .systemBrown
                view?.glyphText = "\(cluster.memberAnnotations.count)"
                view?.accessibilityLabel = String(localized: "カフェ\(cluster.memberAnnotations.count)件のまとまり")
                return view
            }

            guard let cafeAnnotation = annotation as? CafeAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: CafeMapView.cafeReuseID,
                for: cafeAnnotation
            ) as? MKMarkerAnnotationView

            view?.clusteringIdentifier = "cafe"
            view?.canShowCallout = true
            view?.markerTintColor = MapViewModel.markerTintColor(for: cafeAnnotation.item.cafe.dogPolicyStatus)
            view?.glyphText = "🐶"
            view?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            view?.accessibilityLabel = [
                cafeAnnotation.item.cafe.name,
                cafeAnnotation.item.cafe.dogPolicyStatus.displayName,
                MapViewModel.distanceText(meters: cafeAnnotation.item.distanceMeters),
            ].joined(separator: "、")
            return view
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            calloutAccessoryControlTapped control: UIControl
        ) {
            guard let cafeAnnotation = view.annotation as? CafeAnnotation else { return }
            onSelect(cafeAnnotation.item.cafe)
        }
    }
}
