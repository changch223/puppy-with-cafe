import MapKit
import SwiftUI
import UIKit

/// 「この座標へ寄せる」要求。`id` が変わったときだけ地図をそこへ動かす（検索画面から店を開いたとき）。
/// 起点（`center`）は変えない。地図の動きはプログラムによるものなので `onRegionSettled` の byUser は false になる。
struct MapFocusRequest {
    let id: Int
    let coordinate: CLLocationCoordinate2D
}

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
    /// 保存の状態（行きたいの店は縁取りで区別し、行きたい／行ったは読み上げにも含める）
    let savedPlaces: SavedPlaces
    /// 営業中かどうかの判定時刻（営業時間外の店のピンを薄くする）。対象時刻があればその時刻
    let now: Date
    /// `now` が「いつ行く？」で決めた対象時刻か（ピンの読み上げの言い方が変わる）
    let isTargetTime: Bool
    /// 今の時刻（「情報が古い可能性」の判定。対象時刻ではなく今で判定する）
    let clock: Date
    /// うちの子の設定（ピンの読み上げに「うちの子OK」「うちの子は不可」を含める）。未設定は nil
    var dog: DogProfile?
    /// タップ選択中のカフェ（一覧シートがその店のカードに変わる）。×やマップタップで nil に戻る双方向バインディング。
    @Binding var selectedItem: CafeWithDistance?
    /// インクリメントすると現在地（center）へ再センタリングする（現在地ボタンから使用）
    let recenterRequestID: Int
    /// この座標へ寄せる要求（`id` が変わったときだけ動かす。起点は変えない）。なければ nil
    var focusRequest: MapFocusRequest?
    /// `center` が変わったときに地図をそこへ動かすか。「このあたりで探す」で起点が地図の中心になったときは false
    /// （検索地点を今見ている場所に合わせるだけで、地図は動かさない・ズームも変えない）
    var movesToCenterOnChange = true
    /// 地図の動きが止まったときに、地図の中心・見えている範囲の幅（メートル）・ユーザーが動かしたか（false はプログラムの setRegion）を伝える。
    /// 動いている間は呼ばない
    var onRegionSettled: ((_ center: CLLocationCoordinate2D, _ widthMeters: Double, _ byUser: Bool) -> Void)?

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
                if movesToCenterOnChange {
                    mapView.setRegion(MapViewModel.walkingRegion(center: center), animated: !isFirst)
                }
            }
        }

        // 現在地ボタンからの明示的な再センタリング要求。パン保持ロジックとは独立して常に反映する。
        if recenterRequestID != coordinator.lastRecenterRequestID {
            coordinator.lastRecenterRequestID = recenterRequestID
            if let center {
                mapView.setRegion(MapViewModel.walkingRegion(center: center), animated: true)
            }
        }

        // 検索画面から店を開いたときの「この座標へ寄せる」要求。起点は変えず、地図だけを動かす。
        if let focusRequest, focusRequest.id != coordinator.lastFocusRequestID {
            coordinator.lastFocusRequestID = focusRequest.id
            mapView.setRegion(MapViewModel.walkingRegion(center: focusRequest.coordinate), animated: true)
        }

        coordinator.syncAnnotations(on: mapView)
        // 地図の外（検索画面など）でカードの店が変わったときも、地図の選択をその店のピンに合わせる
        coordinator.reconcileSelectionFromOutside(on: mapView)

        // ×ボタン等、地図の外からの選択解除をマップ側にも反映する
        if selectedItem == nil, let selected = mapView.selectedAnnotations.first {
            mapView.deselectAnnotation(selected, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CafeMapView
        var lastRegionKey: String?
        var lastRecenterRequestID = 0
        var lastFocusRequestID = 0
        /// 直近に反映した（データの版, 保存の状態, 対象時刻）。変わらなければ注釈の見た目と読み上げを計算し直さない。
        /// 見た目が同じピンでも、対象時刻や保存の状態が変わったら読み上げ文は作り直す。
        private var lastSyncKey: SyncKey?
        private struct SyncKey: Equatable {
            let revision: Int
            let savedPlaces: SavedPlaces
            let isTargetTime: Bool
            let time: Date
            let dog: DogProfile?
        }
        private var annotationsByID: [UUID: CafeAnnotation] = [:]
        /// 今の縮尺での店名の出し方（大きく寄せたら全部、少し寄せたら起点に近い3店と選んだ店だけ）
        private var nameMode: MapViewModel.PinNameMode = .none
        /// いま見えている範囲の中で起点から近い先頭3店の id（表示結果が変わったら・地図が動き終わったら作り直す）
        private var nearestNameIDs: Set<UUID> = []
        private static let nameLabelTag = 7_001
        /// `syncAnnotations` が注釈を付け外ししている間は true。MKMapView は選択中の注釈を外すと同期で didDeselect を呼ぶので、
        /// その間はカードの選択（`parent.selectedItem`）を消さない（代表が変わっただけでカードが閉じないように）。
        private var isSyncingAnnotations = false
        /// 今の地図の動きがユーザーの操作（パン・ピンチ・回転など）によるものか。動き始めに判定し、止まったときに使う
        private var regionChangeIsByUser = false

        init(parent: CafeMapView) {
            self.parent = parent
        }

        /// 表示結果との差分だけを反映する。残る注釈は作り直さず値を更新するので、選択中のピンの選択が外れない。
        func syncAnnotations(on mapView: MKMapView) {
            let key = SyncKey(
                revision: parent.itemsRevision,
                savedPlaces: parent.savedPlaces,
                isTargetTime: parent.isTargetTime,
                time: parent.now,
                dog: parent.dog
            )
            guard key != lastSyncKey else { return }
            lastSyncKey = key
            let items = parent.items
            let nearest = nameMode == .nearby ? computeNearestNameIDs(on: mapView) : []
            let nearestChanged = nearest != nearestNameIDs
            nearestNameIDs = nearest
            let favoriteIDs = parent.savedPlaces.wantToGoIDs
            let styles = MapViewModel.styles(for: items, favoriteIDs: favoriteIDs, at: parent.now)
            let spokenLabels = MapViewModel.spokenLabels(
                for: items, savedPlaces: parent.savedPlaces,
                at: parent.now, isTargetTime: parent.isTargetTime, clock: parent.clock,
                dog: parent.dog
            )
            let priorities = MapViewModel.displayPriorities(for: items)
            // 同じ場所（5m 以内）の店は1つの注釈（ピン）にまとめる。注釈のキーは代表（組の先頭）の店の id
            let groups = SameSpotGrouping.groups(for: items, favoriteIDs: favoriteIDs, at: parent.now)
            let groupsByID = Dictionary(groups.map { ($0[0].cafe.id, $0) }, uniquingKeysWith: { first, _ in first })

            // 座標が変わった店・代表が変わった組は作り直す（MKMapView は coordinate の変化を追わないため）
            var removedIDs = MapViewModel.diff(existingIDs: Set(annotationsByID.keys), newIDs: Set(groupsByID.keys)).removed
            for (id, annotation) in annotationsByID {
                if let group = groupsByID[id],
                   group[0].cafe.latitude != annotation.item.cafe.latitude || group[0].cafe.longitude != annotation.item.cafe.longitude {
                    removedIDs.insert(id)
                }
            }
            isSyncingAnnotations = true
            defer { isSyncingAnnotations = false }
            if !removedIDs.isEmpty {
                mapView.removeAnnotations(removedIDs.compactMap { annotationsByID[$0] })
                for id in removedIDs { annotationsByID[id] = nil }
            }

            var added: [CafeAnnotation] = []
            for (id, group) in groupsByID {
                let item = group[0]
                let representativeStyle = styles[id] ?? MapPinStyle.make(for: item.cafe, isFavorite: false, at: parent.now)
                // 組の誰か1店でも薄くなければ薄くしない（行きたいの店が代表で時間外でも、ほかの店が営業中なら濃いまま）
                let isDimmed = group.allSatisfy { styles[$0.cafe.id]?.isDimmed ?? false }
                let style = MapPinStyle(category: representativeStyle.category, isFavorite: representativeStyle.isFavorite, isDimmed: isDimmed)
                let priority = MapViewModel.displayPriority(for: group, priorities: priorities)
                let spoken = MapViewModel.spokenLabel(for: group, representative: spokenLabels[id] ?? item.cafe.name)
                if let existing = annotationsByID[id] {
                    guard existing.item != item || existing.members != group || existing.style != style
                            || existing.displayPriority != priority || existing.spokenLabel != spoken else { continue }
                    existing.item = item
                    existing.members = group
                    existing.style = style
                    existing.spokenLabel = spoken
                    existing.displayPriority = priority
                    if let view = mapView.view(for: existing) {
                        configure(view, for: existing, isSelected: mapView.selectedAnnotations.contains { $0 === existing })
                    }
                } else {
                    let annotation = CafeAnnotation(
                        item: item, members: group, displayPriority: priority, style: style, spokenLabel: spoken
                    )
                    annotationsByID[id] = annotation
                    added.append(annotation)
                }
            }
            if !added.isEmpty { mapView.addAnnotations(added) }
            // 起点に近い3店が入れ替わったら、表示中のピンの店名を付け直す
            if nearestChanged, nameMode == .nearby { refreshVisibleAnnotationViews(on: mapView) }
            reconcileSelection(on: mapView)
        }

        /// いま地図に見えている範囲の中で、起点から近い順の先頭3店の id
        private func computeNearestNameIDs(on mapView: MKMapView) -> Set<UUID> {
            let visibleRect = mapView.visibleMapRect
            let visible = Set(parent.items.filter {
                visibleRect.contains(MKMapPoint(CLLocationCoordinate2D(latitude: $0.cafe.latitude, longitude: $0.cafe.longitude)))
            }.map(\.cafe.id))
            return MapViewModel.nearestIDs(of: parent.items, visibleIDs: visible)
        }

        /// 表示中のピンの見た目を作り直す（店名の出し方が変わったとき）
        private func refreshVisibleAnnotationViews(on mapView: MKMapView) {
            for case let annotation as CafeAnnotation in mapView.annotations(in: mapView.visibleMapRect) {
                guard let view = mapView.view(for: annotation) else { continue }
                configure(view, for: annotation, isSelected: isSelected(annotation))
            }
        }

        /// 地図の外でカードの店が変わったとき（`syncAnnotations` が早く戻る場合も含む）に、地図の選択を合わせる。
        /// 付け外しではないので、カードの選択は消さない（古いピンの選択解除は `isSelected` が false で何もしない）。
        func reconcileSelectionFromOutside(on mapView: MKMapView) {
            reconcileSelection(on: mapView)
        }

        /// 地図の選択を「選択中の店がいる組」のピン1つに合わせる（カードの店は変えない）。
        /// 代表が変わって作り直したときだけでなく、組がつながる・分かれるときも、選択中の店が別のピンへ移るため。
        /// 付け外しの間は didDeselect が選択を消さないので、ここで選択中の店がまだ残っている。
        /// 選択中の店が表示から消えたときは SearchTabView が選択を外すので、ここでは何もしない。
        private func reconcileSelection(on mapView: MKMapView) {
            guard parent.selectedItem != nil,
                  let target = annotationsByID.values.first(where: { isSelected($0) }) else { return }
            for case let annotation as CafeAnnotation in mapView.selectedAnnotations where annotation !== target {
                mapView.deselectAnnotation(annotation, animated: false)
            }
            if !mapView.selectedAnnotations.contains(where: { $0 === target }) {
                mapView.selectAnnotation(target, animated: false)
            }
        }

        /// 選択中の店がこの組（ピン）にいるか。カードで同じ場所の別の店に切り替えても、地図のピンは選択のまま
        private func isSelected(_ annotation: CafeAnnotation) -> Bool {
            guard let selected = parent.selectedItem else { return false }
            return annotation.members.contains { $0.cafe.id == selected.cafe.id }
        }

        private func configure(_ view: MKAnnotationView, for annotation: CafeAnnotation, isSelected: Bool) {
            let style = annotation.style
            let image = MapPinRenderer.image(for: style, isSelected: isSelected, count: annotation.members.count)
            view.image = image
            view.centerOffset = MapPinRenderer.centerOffset(for: style, image: image, count: annotation.members.count)
            // 営業時間が分かっていて今は時間外の店は薄く（選択中は見失わないよう通常の濃さ）
            view.alpha = isSelected ? 1 : style.alpha
            view.zPriority = isSelected ? .max : .defaultUnselected
            view.displayPriority = annotation.displayPriority
            view.canShowCallout = false
            view.clusteringIdentifier = nil
            view.accessibilityLabel = annotation.spokenLabel
            let isNearest = annotation.members.contains { nearestNameIDs.contains($0.cafe.id) }
            configureNameLabel(
                on: view, name: MapViewModel.nameLabel(for: annotation.members),
                shows: MapViewModel.showsName(mode: nameMode, isNearest: isNearest, isSelected: isSelected)
            )
        }

        /// ピンの下の店名（寄せているときだけ。`MapViewModel.showsName`）。読み上げはピン本体が担うので、ラベルは VoiceOver から隠す。
        private func configureNameLabel(on view: MKAnnotationView, name: String, shows: Bool) {
            let existing = view.viewWithTag(Self.nameLabelTag) as? UILabel
            guard shows else {
                existing?.isHidden = true
                return
            }
            let label: UILabel
            if let existing {
                label = existing
            } else {
                label = UILabel()
                label.tag = Self.nameLabelTag
                label.numberOfLines = 1
                label.lineBreakMode = .byTruncatingTail
                label.textAlignment = .center
                label.isAccessibilityElement = false
                view.clipsToBounds = false
                view.addSubview(label)
            }
            label.isHidden = false
            // 地図の上でも読めるよう、文字色の反対色で縁取る（ライト・ダークどちらでも）
            label.attributedText = NSAttributedString(string: name, attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.label,
                .strokeColor: UIColor.systemBackground,
                .strokeWidth: -4,
            ])
            let maxWidth: CGFloat = 130
            let size = label.sizeThatFits(CGSize(width: maxWidth, height: 20))
            let width = min(size.width, maxWidth)
            label.frame = CGRect(
                x: (view.bounds.width - width) / 2, y: view.bounds.height - 2,
                width: width, height: size.height
            )
        }

        /// 地図の動き始め。ユーザーの指の操作によるものか（プログラムの setRegion ではないか）を覚えておく。
        /// MKMapView の中身のジェスチャが操作中（began / ended）かで判定する。
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            let recognizers = mapView.subviews.first?.gestureRecognizers ?? []
            regionChangeIsByUser = recognizers.contains { $0.state == .began || $0.state == .changed || $0.state == .ended }
        }

        /// 地図の動きが止まったとき（動いている間は呼ばれない）。中心と見えている幅を SearchTabView へ伝える。
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let byUser = regionChangeIsByUser
            regionChangeIsByUser = false
            // 動き終わったら、見えている範囲の中の「起点に近い3店」を取り直す（ピンの付け外しはしないので選択は外れない）
            if nameMode == .nearby {
                let nearest = computeNearestNameIDs(on: mapView)
                if nearest != nearestNameIDs {
                    nearestNameIDs = nearest
                    refreshVisibleAnnotationViews(on: mapView)
                }
            }
            guard let onRegionSettled = parent.onRegionSettled else { return }
            let region = mapView.region
            guard CLLocationCoordinate2DIsValid(region.center) else { return }
            let width = MapRecenterLogic.visibleWidthMeters(
                longitudeDelta: region.span.longitudeDelta, latitude: region.center.latitude
            )
            // updateUIView の中（setRegion 直後）で呼ばれても、SwiftUI の状態を描画中に変えないよう次の周期に回す
            DispatchQueue.main.async { onRegionSettled(region.center, width, byUser) }
        }

        /// 縮尺が変わったとき、店名の出し方が切り替わるなら表示中のピンを更新する
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            let region = mapView.region
            let mode = MapViewModel.pinNameMode(span: region.span, centerLatitude: region.center.latitude)
            guard mode != nameMode else { return }
            nameMode = mode
            nearestNameIDs = mode == .nearby ? computeNearestNameIDs(on: mapView) : []
            refreshVisibleAnnotationViews(on: mapView)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: CafeMapView.cafeReuseID,
                for: cafeAnnotation
            )
            configure(view, for: cafeAnnotation, isSelected: isSelected(cafeAnnotation))
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return }
            // 代表が変わって作り直した直後など、選択中の店がすでにこの組にいるときは、カードの店を変えない
            if !isSelected(cafeAnnotation) {
                parent.selectedItem = cafeAnnotation.item
            }
            if let view = mapView.view(for: annotation) {
                configure(view, for: cafeAnnotation, isSelected: true)
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            guard let cafeAnnotation = annotation as? CafeAnnotation else { return }
            if let view = mapView.view(for: annotation) {
                configure(view, for: cafeAnnotation, isSelected: false)
            }
            // 注釈の付け外しや選択の合わせ直し（代表の入れ替え・組のつながり／分かれ）による選択解除は、
            // ユーザー操作ではないのでカードを閉じない
            guard !isSyncingAnnotations else { return }
            if isSelected(cafeAnnotation) {
                parent.selectedItem = nil
            }
        }
    }
}

/// 現在地へ戻るFAB（起点が現在地でなければ現在地に戻して探し直す。SearchTabView 側で切り替える）
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
