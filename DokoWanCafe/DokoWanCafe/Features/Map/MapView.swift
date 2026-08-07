import MapKit
import SwiftUI
import UIKit

/// 地図画面（T026/T028 / UI/UXブラッシュアップ設計書2: 数字クラスタ廃止・Google風ピン・下部コンパクトカード）。
///
/// UIKit 使用理由（憲章 原則V に基づく明記）:
/// ピンの重なり対策として MKMapView 標準の displayPriority による衝突間引きが必要であり、
/// SwiftUI 標準 `Map`（iOS 16 時点）ではそれらの細かな制御ができないため、
/// `UIViewRepresentable` による橋渡しで MKMapView を使用する（research.md R2）。
struct CafeMapView: UIViewRepresentable {
    let items: [CafeWithDistance]
    let center: CLLocationCoordinate2D?
    /// お気に入り店の視覚区別に使う（UI/UXブラッシュアップ設計書2）
    let favoriteIDs: Set<UUID>
    /// タップ選択中のカフェ（下部コンパクトカードに表示）。×やマップタップで nil に戻る双方向バインディング。
    @Binding var selectedItem: CafeWithDistance?
    /// インクリメントすると現在地（center）へ再センタリングする（右下の現在地ボタンから使用, 設計書2）
    let recenterRequestID: Int

    private static let cafeReuseID = "cafe"

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
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
        mapView.accessibilityLabel = String(localized: "周辺の犬同伴OKカフェの地図")
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        // 検索の起点が変わった時、またはその起点で初めて実データが揃った時だけ
        // 表示領域を再設定する（ユーザーのパン操作を尊重）。
        // 座標は丸めて比較し、GPSの微小な揺れで毎回カメラがリセットされないようにする。
        // 「items の有無」もキーに含めることで、起点確定直後(items未取得)のフォールバック表示から、
        // 実データが揃った時点の適切なズームへ1回だけ更新されるようにする（以降は再設定しない）。
        if let center {
            let roundedLat = (center.latitude * 10_000).rounded() / 10_000
            let roundedLng = (center.longitude * 10_000).rounded() / 10_000
            let regionKey = "\(roundedLat),\(roundedLng),\(items.isEmpty ? "0" : "1")"
            if context.coordinator.lastRegionKey != regionKey {
                context.coordinator.lastRegionKey = regionKey
                mapView.setRegion(
                    MapViewModel.initialCameraRegion(center: center, items: items),
                    animated: true
                )
            }
        }

        // 現在地ボタンからの明示的な再センタリング要求（設計書2）。パン保持ロジックとは独立して常に反映する。
        if recenterRequestID != context.coordinator.lastRecenterRequestID {
            context.coordinator.lastRecenterRequestID = recenterRequestID
            if let center {
                mapView.setRegion(
                    MapViewModel.initialCameraRegion(center: center, items: items),
                    animated: true
                )
            }
        }

        // アノテーション差分更新（同一データなら再描画しない）
        let newSignature = MapViewModel.signature(of: items, favoriteIDs: favoriteIDs)
        if context.coordinator.lastSignature != newSignature {
            context.coordinator.lastSignature = newSignature
            let existing = mapView.annotations.compactMap { $0 as? CafeAnnotation }
            mapView.removeAnnotations(existing)
            mapView.addAnnotations(MapViewModel.annotations(for: items))
        }

        // ×ボタン等、地図の外からの選択解除をマップ側にも反映する
        if selectedItem == nil, let selected = mapView.selectedAnnotations.first {
            mapView.deselectAnnotation(selected, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CafeMapView
        var lastRegionKey: String?
        var lastSignature: Set<String> = []
        var lastRecenterRequestID = 0

        init(parent: CafeMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: CafeMapView.cafeReuseID,
                for: cafeAnnotation
            ) as? MKMarkerAnnotationView

            let cafe = cafeAnnotation.item.cafe
            let category = MapPinCategory.category(for: cafe)
            let isFavorite = parent.favoriteIDs.contains(cafe.id)

            // 数字クラスタは廃止し、displayPriority による衝突間引きに委ねる（設計書2）
            view?.clusteringIdentifier = nil
            view?.canShowCallout = false
            view?.displayPriority = cafeAnnotation.displayPriority
            view?.titleVisibility = .adaptive
            view?.markerTintColor = MapViewModel.markerTintColor(for: category)
            // お気に入り店は肉球アイコンを丸枠付きにして視覚的に区別する
            view?.glyphImage = UIImage(systemName: isFavorite ? "pawprint.circle.fill" : "pawprint.fill")
            view?.accessibilityLabel = [
                cafe.name,
                category.displayName,
                MapViewModel.distanceText(meters: cafeAnnotation.item.distanceMeters),
            ].joined(separator: "、")
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return }
            parent.selectedItem = cafeAnnotation.item
            // 選択ピンを強調する（設計書2）
            if let view = mapView.view(for: annotation) {
                UIView.animate(withDuration: 0.15) {
                    view.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
                }
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return }
            if let view = mapView.view(for: annotation) {
                UIView.animate(withDuration: 0.15) {
                    view.transform = .identity
                }
            }
            if parent.selectedItem?.cafe.id == cafeAnnotation.item.cafe.id {
                parent.selectedItem = nil
            }
        }
    }
}

// MARK: - 下部コンパクトカード（Googleマップのプレイスカード風, UI/UXブラッシュアップ設計書2）

/// ピンタップ時に地図下部へ表示するコンパクトカード。callout の代替。
struct MapPlaceCardView: View {
    let item: CafeWithDistance
    let onShowDetail: () -> Void
    let onOpenRoute: () -> Void
    let onClose: () -> Void

    @State private var thumbnail: UIImage?

    private var cafe: Cafe { item.cafe }
    private var category: MapPinCategory { MapPinCategory.category(for: cafe) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(cafe.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(Text("閉じる"))
                }

                HStack(spacing: 6) {
                    MapPinCategoryBadge(category: category)
                    Text(MapViewModel.distanceText(meters: item.distanceMeters))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 構造化営業時間があり判定可能な場合のみ（判定不能な店で嘘をつかない, 設計書2）
                if let closingTime = OpeningHoursEvaluator.closingTimeIfOpen(hours: cafe.hours) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("営業中・\(closingTime)まで")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Button(action: onShowDetail) {
                        Label(String(localized: "詳細"), systemImage: "info.circle")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(action: onOpenRoute) {
                        Label(String(localized: "経路"), systemImage: "arrow.triangle.turn.up.right.diamond")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .task(id: cafe.id) {
            thumbnail = nil
            guard let url = PhotoSourceResolver.previewSourceURL(for: cafe) else { return }
            let preview = await LinkPreviewService.shared.preview(for: url)
            thumbnail = preview?.image
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 56, height: 56)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)
    }
}

/// MapPinCategory の小バッジ（下部コンパクトカードで使用）
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

// MARK: - 凡例・現在地ボタン（右下, UI/UXブラッシュアップ設計書2）

/// 地図右下の犬目線ピン凡例カード
struct MapLegendView: View {
    /// 未確認ピン（灰）を表示中かどうか（既定は非表示。表示中の店が実際にある時のみ凡例に足す）
    var showsUnverified = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            entry(color: .green, label: MapPinCategory.indoorOK.displayName)
            entry(color: .teal, label: MapPinCategory.terraceOnly.displayName)
            entry(color: .orange, label: MapPinCategory.checkDetail.displayName)
            if showsUnverified {
                entry(color: .gray, label: MapPinCategory.unverified.displayName)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("地図の凡例"))
    }

    private func entry(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
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
        .foregroundStyle(.tint)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
        .accessibilityLabel(Text("現在地に戻る"))
    }
}
