import MapKit
import SwiftUI
import UIKit

/// 写真がない店の先頭の帯: 店の場所の小さな地図（静止画）に、店のピンを中央に重ねる。
/// 地図は装飾なので VoiceOver からは隠し、タップしても何も起きない。
/// スナップショットができるまで・失敗したときは、無地の帯にピン画像だけを置く。
struct CafeDetailMapBand: View {
    let cafe: Cafe

    static let height: CGFloat = 120
    /// 地図に映す範囲（一辺のメートル数。店の周り数ブロックが見える広さ）
    private static let spanMeters: CLLocationDistance = 450

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var snapshot: UIImage?

    var body: some View {
        GeometryReader { geometry in
            let key = MapSnapshotKey(
                cafeID: cafe.id, isDark: colorScheme == .dark, width: geometry.size.width,
                latitude: cafe.latitude, longitude: cafe.longitude
            )
            ZStack {
                Color(.secondarySystemBackground)
                if let snapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
                pin
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.2), value: snapshot != nil)
            .task(id: key) { await loadSnapshot(key: key, size: geometry.size) }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// 店のピン（地図上のピンと同じ形・色）。しずく形は先端が店の位置に来るよう持ち上げる。
    private var pin: some View {
        let style = MapPinStyle(category: MapPinCategory.category(for: cafe), isFavorite: false, isDimmed: false)
        let image = MapPinRenderer.image(for: style)
        let offset = MapPinRenderer.centerOffset(for: style, image: image)
        return Image(uiImage: image)
            .offset(x: offset.x, y: offset.y)
    }

    private func loadSnapshot(key: MapSnapshotKey, size: CGSize) async {
        guard size.width > 0 else { return }
        if let cached = CafeDetailMapSnapshotCache.image(for: key) {
            snapshot = cached
            return
        }
        // 外観や幅が変わったときは、新しい地図ができるまで古い地図を出さない
        snapshot = nil
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: cafe.latitude, longitude: cafe.longitude),
            latitudinalMeters: Self.spanMeters,
            longitudinalMeters: Self.spanMeters
        )
        options.size = size
        options.traitCollection = UITraitCollection { traits in
            traits.userInterfaceStyle = key.isDark ? .dark : .light
            traits.displayScale = displayScale
        }
        options.showsBuildings = false
        guard let result = try? await MKMapSnapshotter(options: options).start() else { return }
        guard !Task.isCancelled else { return }
        CafeDetailMapSnapshotCache.store(result.image, for: key)
        snapshot = result.image
    }
}

/// 地図スナップショットの端末内メモリキャッシュ（店ID＋外観＋幅。ディスクには残さない）。
@MainActor
enum CafeDetailMapSnapshotCache {
    private static let cache: NSCache<WrappedKey, UIImage> = {
        let cache = NSCache<WrappedKey, UIImage>()
        cache.countLimit = 40
        return cache
    }()

    static func image(for key: MapSnapshotKey) -> UIImage? {
        cache.object(forKey: WrappedKey(key))
    }

    static func store(_ image: UIImage, for key: MapSnapshotKey) {
        cache.setObject(image, forKey: WrappedKey(key))
    }

    /// NSCache のキーにするための薄い包み
    private final class WrappedKey: NSObject {
        let key: MapSnapshotKey
        init(_ key: MapSnapshotKey) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            (object as? WrappedKey)?.key == key
        }
    }
}
