import MapKit
import SwiftUI
import XCTest
@testable import DokoWanCafe

/// 地図の選択（同じ場所の組のピンとカードの店）の結合テスト。
/// 実際の `CafeMapView`（MKMapView）をシミュレーターの UIWindow に載せて動かすので、ホストアプリ付きのシミュレーターでしか動かない。
/// 回帰: 代表が変わって注釈を作り直すとき、MKMapView が同期で didDeselect を呼び、カードが閉じていた。
final class MapSelectionTests: XCTestCase {
    private final class Model: ObservableObject {
        @Published var selected: CafeWithDistance?
        @Published var saved = SavedPlaces()
        @Published var items: [CafeWithDistance] = []
        @Published var revision = 0
    }

    private struct Host: View {
        @ObservedObject var model: Model
        let date: Date

        var body: some View {
            CafeMapView(
                items: model.items, itemsRevision: model.revision,
                center: CLLocationCoordinate2D(latitude: 35.65697, longitude: 139.79311),
                savedPlaces: model.saved, now: date, isTargetTime: false, clock: date, dog: nil,
                selectedItem: Binding(get: { self.model.selected }, set: { self.model.selected = $0 }),
                recenterRequestID: 0
            )
        }
    }

    private let date = Date()
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    /// 地図が非同期に注釈・選択を反映するのを待つ
    private func spin(_ seconds: Double = 0.6) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func makeItem(_ name: String, north: Double = 0) -> CafeWithDistance {
        CafeWithDistance(cafe: Cafe(
            id: UUID(), placeID: nil, name: name,
            latitude: 35.65697 + north / 111_195, longitude: 139.79311,
            address: nil, contact: nil, dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil, hasConflict: false, isClosed: false, area: "tokyo",
            hours: nil, dogAmenities: nil
        ), distanceMeters: 100)
    }

    private func findMap(_ view: UIView) -> MKMapView? {
        if let map = view as? MKMapView { return map }
        for subview in view.subviews { if let map = findMap(subview) { return map } }
        return nil
    }

    private func annotations(_ map: MKMapView) -> [CafeAnnotation] {
        map.annotations.compactMap { $0 as? CafeAnnotation }
    }

    private func selectedAnnotation(_ map: MKMapView) -> CafeAnnotation? {
        map.selectedAnnotations.first as? CafeAnnotation
    }

    /// 地図をウィンドウに載せ、注釈がそろうまで待つ
    private func showMap(_ model: Model) throws -> MKMapView {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: Host(model: model, date: date))
        window.makeKeyAndVisible()
        self.window = window
        spin(1.5)
        return try XCTUnwrap(findMap(window))
    }

    /// 選択中の店の組がつながったとき（あ店 0m・う店 8m の間に い店 4m が加わる）、選択はつながった組のピン1つに移る
    func test_組がつながっても選択中の店のピンが選択される() throws {
        let a = makeItem("あ店"), b = makeItem("い店", north: 4), c = makeItem("う店", north: 8)
        let model = Model()
        model.items = [a, c]
        model.revision = 1
        let map = try showMap(model)
        let single = try XCTUnwrap(annotations(map).first { $0.item.cafe.name == "う店" })
        map.selectAnnotation(single, animated: false)
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "う店")

        model.items = [a, b, c]
        model.revision = 2
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "う店", "カードの店は変わらない")
        XCTAssertEqual(map.selectedAnnotations.count, 1)
        XCTAssertEqual(selectedAnnotation(map)?.members.map(\.cafe.name), ["あ店", "い店", "う店"])

        // 空き地のタップでカードを閉じられる
        map.deselectAnnotation(try XCTUnwrap(selectedAnnotation(map)), animated: false)
        spin()
        XCTAssertNil(model.selected)
    }

    /// 選択中の店の組が分かれたとき（間の い店 が消える）、選択は選択中の店のピンへ移り、元の組のピンは選択が外れる
    func test_組が分かれても選択は選択中の店のピンだけ() throws {
        let a = makeItem("あ店"), b = makeItem("い店", north: 4), c = makeItem("う店", north: 8)
        let model = Model()
        model.items = [a, b, c]
        model.revision = 1
        let map = try showMap(model)
        let group = try XCTUnwrap(annotations(map).first { $0.members.count == 3 })
        map.selectAnnotation(group, animated: false)
        spin()
        model.selected = c
        spin()

        model.items = [a, c]
        model.revision = 2
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "う店")
        XCTAssertEqual(map.selectedAnnotations.count, 1)
        XCTAssertEqual(selectedAnnotation(map)?.members.map(\.cafe.name), ["う店"])

        map.deselectAnnotation(try XCTUnwrap(selectedAnnotation(map)), animated: false)
        spin()
        XCTAssertNil(model.selected)
    }

    func test_代表が変わっても選択中の店のカードとピンの選択を保つ() throws {
        let a = makeItem("あ店"), b = makeItem("い店"), c = makeItem("う店"), far = makeItem("遠い店", north: 300)
        let model = Model()
        model.items = [a, b, c, far]
        model.revision = 1
        let map = try showMap(model)

        // ピンをタップ: 代表（あ店）がカードの店になる
        let group = try XCTUnwrap(annotations(map).first { $0.members.count == 3 })
        map.selectAnnotation(group, animated: false)
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "あ店")

        // チップで別の店（う店）に切り替えても、地図のピンは選択のまま
        model.selected = c
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "う店")
        XCTAssertEqual(selectedAnnotation(map)?.members.count, 3)

        // (a) 代表でないう店を「行きたい」にすると代表が入れ替わるが、カードは閉じず、ピンも選択のまま
        var saved = model.saved
        saved.toggleWantToGo(c.cafe.id, at: date)
        model.saved = saved
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "う店", "代表が変わってもカードの店は変わらず、閉じない")
        XCTAssertEqual(selectedAnnotation(map)?.item.cafe.name, "う店", "新しい代表のピンが選択される")
        XCTAssertEqual(map.selectedAnnotations.count, 1)

        // 行きたいを外すと代表があ店に戻る。このときもカードとピンの選択を保つ
        saved = model.saved
        saved.toggleWantToGo(c.cafe.id, at: date)
        model.saved = saved
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "う店")
        XCTAssertEqual(selectedAnnotation(map)?.item.cafe.name, "あ店")

        // (d) フィルタで代表（あ店）だけが消えても、選択中のう店は残る
        model.items = [b, c, far]
        model.revision = 2
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "う店")
        XCTAssertEqual(selectedAnnotation(map)?.members.map(\.cafe.name), ["い店", "う店"])

        // 地図の空き地のタップ（選択解除）でカードを閉じる
        let current = try XCTUnwrap(selectedAnnotation(map))
        map.deselectAnnotation(current, animated: false)
        spin()
        XCTAssertNil(model.selected)

        // 組を選び、カードで別の店に切り替えたあと別のピンをタップすると、その店に変わる
        let pair = try XCTUnwrap(annotations(map).first { $0.members.count == 2 })
        map.selectAnnotation(pair, animated: false)
        spin()
        model.selected = c
        spin()
        let single = try XCTUnwrap(annotations(map).first { $0.members.count == 1 })
        map.selectAnnotation(single, animated: false)
        spin()
        XCTAssertEqual(model.selected?.cafe.name, "遠い店")
    }
}
