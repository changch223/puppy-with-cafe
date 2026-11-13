import CoreLocation
import MapKit
import UIKit
import XCTest
@testable import DokoWanCafe

/// 地図表示の純ロジック（徒歩圏の縮尺・表示優先度・ピンの見た目・注釈の差分）のユニットテスト（憲章 原則IV）。
final class MapViewModelTests: XCTestCase {
    private func makeItem(
        distanceMeters: Double,
        status: DogPolicyStatus = .allowed,
        amenities: DogAmenities? = nil,
        hours: OpeningHours? = nil
    ) -> CafeWithDistance {
        CafeWithDistance(
            cafe: Cafe(
                id: UUID(), placeID: nil, name: "テスト",
                latitude: 35.68, longitude: 139.76,
                address: nil, contact: nil,
                dogPolicyStatus: status, dogPolicyCondition: nil,
                lastVerified: nil, representativeSourceID: nil,
                hasConflict: false, isClosed: false, area: "tokyo",
                hours: hours, dogAmenities: amenities
            ),
            distanceMeters: distanceMeters
        )
    }

    // MARK: - ピンの読み上げ（対象時刻・保存の状態）

    private func tokyoDate(day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    func test_ピンの読み上げは対象時刻の言い方と保存の状態を含める() {
        // 2026-07-06 は月曜
        let hours = OpeningHours(mon: [TimeRange(open: "09:00", close: "19:00")], tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
        let item = makeItem(distanceMeters: 100, hours: hours)
        let id = item.cafe.id
        var saved = SavedPlaces()
        saved.toggleWantToGo(id, at: Date(timeIntervalSince1970: 0))
        let noon = tokyoDate(day: 6, hour: 12)

        let now = MapViewModel.spokenLabels(for: [item], savedPlaces: SavedPlaces(), at: noon, isTargetTime: false, clock: noon)[id]
        XCTAssertEqual(now, "テスト、条件を確認、営業中19時まで、徒歩約2分、情報が古い可能性があります")

        let target = MapViewModel.spokenLabels(for: [item], savedPlaces: saved, at: noon, isTargetTime: true, clock: noon)[id]
        XCTAssertEqual(target, "テスト、行きたいに登録済み、条件を確認、月 12:00 は営業中19時まで、徒歩約2分、情報が古い可能性があります")
        XCTAssertNotEqual(now, target, "見た目が同じピンでも、対象時刻・保存の状態が変われば読み上げは変わる")

        var visited = SavedPlaces()
        visited.toggleVisited(id, at: Date(timeIntervalSince1970: 0))
        let visitedLabel = MapViewModel.spokenLabels(for: [item], savedPlaces: visited, at: noon, isTargetTime: false, clock: noon)[id]
        XCTAssertTrue(visitedLabel?.hasPrefix("テスト、行った、") == true)
    }

    // MARK: - 徒歩圏の縮尺

    func test_初期の縮尺は検索地点を中心に縦横約1_6km() {
        let center = CLLocationCoordinate2D(latitude: 35.6896, longitude: 139.7006)
        let region = MapViewModel.walkingRegion(center: center)
        XCTAssertEqual(region.center.latitude, center.latitude, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, center.longitude, accuracy: 0.0001)
        // 緯度1度 ≒ 111km → 1.6km ≒ 0.0144度
        XCTAssertEqual(region.span.latitudeDelta, 1_600 / 111_000, accuracy: 0.001)
        XCTAssertGreaterThan(region.span.longitudeDelta, 0)
    }

    // MARK: - displayPriority（数字クラスタ廃止の代替）

    func test_近い順位はrequired中間はdefaultHigh遠い順位はdefaultLow() {
        XCTAssertEqual(MapViewModel.displayPriority(rank: 0), .required)
        XCTAssertEqual(MapViewModel.displayPriority(rank: MapViewModel.requiredPinRank - 1), .required)
        XCTAssertEqual(MapViewModel.displayPriority(rank: MapViewModel.requiredPinRank), .defaultHigh)
        XCTAssertEqual(MapViewModel.displayPriority(rank: MapViewModel.highPriorityPinRank - 1), .defaultHigh)
        XCTAssertEqual(MapViewModel.displayPriority(rank: MapViewModel.highPriorityPinRank), .defaultLow)
    }

    func test_displayPrioritiesは距離昇順のランクで割り当てる() {
        // 距離順ではなく元の並びを崩した入力でも、距離順にランク付けされることを確認
        let far = makeItem(distanceMeters: 9_000)
        let near = makeItem(distanceMeters: 100)
        let priorities = MapViewModel.displayPriorities(for: [far, near])
        XCTAssertEqual(priorities[near.cafe.id], .required)
        XCTAssertEqual(priorities[far.cafe.id], .required) // 2件のみなら両方 requiredPinRank 未満
    }

    // MARK: - ピンの形と色

    func test_分類ごとにピンの形が違う() {
        XCTAssertEqual(MapPinCategory.indoorOK.pinShape, .circle)
        XCTAssertEqual(MapPinCategory.terraceOnly.pinShape, .roundedSquare)
        XCTAssertEqual(MapPinCategory.checkDetail.pinShape, .teardrop)
        // 未確認は店内OKの丸（薄い店内OKも丸）と見分けるため菱形
        XCTAssertEqual(MapPinCategory.unverified.pinShape, .diamond)
        XCTAssertNotEqual(MapPinCategory.unverified.pinShape, MapPinCategory.indoorOK.pinShape)
    }

    func test_分類ごとにピンの色が違う() {
        let colors = [MapPinCategory.indoorOK, .terraceOnly, .checkDetail, .unverified].map { MapPinRenderer.fillColor(for: $0) }
        for (index, color) in colors.enumerated() {
            for other in colors[(index + 1)...] {
                XCTAssertFalse(color.isEqual(other))
            }
        }
    }

    func test_ピン画像はキャッシュされ選択中は大きい() {
        let style = MapPinStyle(category: .indoorOK, isFavorite: false, isDimmed: false)
        let normal = MapPinRenderer.image(for: style)
        XCTAssertTrue(normal === MapPinRenderer.image(for: style), "同じ見た目は描き直さずキャッシュを返す")
        let selected = MapPinRenderer.image(for: style, isSelected: true)
        XCTAssertGreaterThan(selected.size.width, normal.size.width)
        // 薄さは画像ではなく alpha で表すので、薄い・濃いで同じ画像を使う
        let dimmed = MapPinStyle(category: .indoorOK, isFavorite: false, isDimmed: true)
        XCTAssertTrue(normal === MapPinRenderer.image(for: dimmed))
    }

    func test_しずく形は先端を座標に合わせるためにoffsetが上へずれる() {
        let drop = MapPinStyle(category: .checkDetail, isFavorite: false, isDimmed: false)
        let image = MapPinRenderer.image(for: drop)
        XCTAssertLessThan(MapPinRenderer.centerOffset(for: drop, image: image).y, 0)
        let circle = MapPinStyle(category: .indoorOK, isFavorite: false, isDimmed: false)
        XCTAssertEqual(MapPinRenderer.centerOffset(for: circle, image: MapPinRenderer.image(for: circle)), .zero)
        let diamond = MapPinStyle(category: .unverified, isFavorite: false, isDimmed: false)
        XCTAssertEqual(MapPinRenderer.centerOffset(for: diamond, image: MapPinRenderer.image(for: diamond)), .zero)
    }

    // MARK: - 営業時間外のピンは薄く

    /// 2026-07-06（月曜）の東京時間
    private func monday(hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: hour))!
    }

    private var mondayHours: OpeningHours {
        OpeningHours(mon: [TimeRange(open: "09:00", close: "18:00")], tue: [], wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
    }

    func test_営業時間が分かっていて時間外なら薄くする() {
        let cafe = makeItem(distanceMeters: 100, hours: mondayHours).cafe
        let style = MapPinStyle.make(for: cafe, isFavorite: false, at: monday(hour: 20))
        XCTAssertTrue(style.isDimmed)
        XCTAssertEqual(style.alpha, 0.4, accuracy: 0.001)
    }

    func test_本日定休も薄くする() {
        let cafe = makeItem(distanceMeters: 100, hours: mondayHours).cafe
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday(hour: 12))!
        XCTAssertTrue(MapPinStyle.make(for: cafe, isFavorite: false, at: tuesday).isDimmed)
    }

    func test_営業中は薄くしない() {
        let cafe = makeItem(distanceMeters: 100, hours: mondayHours).cafe
        let style = MapPinStyle.make(for: cafe, isFavorite: false, at: monday(hour: 12))
        XCTAssertFalse(style.isDimmed)
        XCTAssertEqual(style.alpha, 1)
    }

    func test_営業時間が不明な店は薄くしない() {
        let noHours = makeItem(distanceMeters: 100, hours: nil).cafe
        XCTAssertFalse(MapPinStyle.make(for: noHours, isFavorite: false, at: monday(hour: 3)).isDimmed)
        // 該当曜日が未登録（キー欠落）も不明
        let wednesday = OpeningHours(mon: nil, tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: [])
        let unknownDay = makeItem(distanceMeters: 100, hours: wednesday).cafe
        XCTAssertFalse(MapPinStyle.make(for: unknownDay, isFavorite: false, at: monday(hour: 3)).isDimmed)
    }

    func test_保存済みと分類はピンの見た目に反映される() {
        let item = makeItem(distanceMeters: 100, amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil))
        let plain = MapPinStyle.make(for: item.cafe, isFavorite: false, at: monday(hour: 12))
        let saved = MapPinStyle.make(for: item.cafe, isFavorite: true, at: monday(hour: 12))
        XCTAssertEqual(plain.category, .terraceOnly)
        XCTAssertNotEqual(plain, saved)
        XCTAssertEqual(MapViewModel.styles(for: [item], favoriteIDs: [item.cafe.id], at: monday(hour: 12))[item.cafe.id], saved)
    }

    // MARK: - 注釈の差分

    func test_注釈の差分は追加と削除だけを返す() {
        let a = UUID(), b = UUID(), c = UUID()
        let diff = MapViewModel.diff(existingIDs: [a, b], newIDs: [b, c])
        XCTAssertEqual(diff.added, [c])
        XCTAssertEqual(diff.removed, [a])
    }

    // MARK: - ズーム時の店名ラベル

    func test_店名は大きな縮尺のときだけ出す() {
        let lat = 35.68
        func span(meters: Double) -> MKCoordinateSpan {
            MKCoordinateSpan(latitudeDelta: meters / 111_320, longitudeDelta: meters / (111_320 * cos(lat * .pi / 180)))
        }
        // 徒歩圏の初期表示（1.6km）では出さない
        XCTAssertFalse(MapViewModel.showsPinNames(span: span(meters: MapViewModel.walkingSpanMeters), centerLatitude: lat))
        XCTAssertFalse(MapViewModel.showsPinNames(span: span(meters: 600), centerLatitude: lat))
        XCTAssertTrue(MapViewModel.showsPinNames(span: span(meters: 590), centerLatitude: lat))
        XCTAssertTrue(MapViewModel.showsPinNames(span: span(meters: 200), centerLatitude: lat))
        // 縦か横のどちらかが広ければ出さない
        let wide = MKCoordinateSpan(latitudeDelta: 300 / 111_320, longitudeDelta: 0.02)
        XCTAssertFalse(MapViewModel.showsPinNames(span: wide, centerLatitude: lat))
    }


    // MARK: - ピンの絵柄・店名の出し方

    func test_ピンの絵柄は席の種類で変わる() {
        // 店内OK・テラスは絵柄を使わず2行の文字で言い切る
        XCTAssertEqual(MapPinCategory.indoorOK.pinLines, ["店内", "OK"])
        XCTAssertEqual(MapPinCategory.terraceOnly.pinLines, ["テラス", "OK"])
        XCTAssertNil(MapPinCategory.indoorOK.symbolName)
        XCTAssertNil(MapPinCategory.terraceOnly.symbolName)
        // 条件を確認・未確認は絵柄だけ（未確認は席がまだ分からないので肉球）
        XCTAssertNil(MapPinCategory.checkDetail.pinLines)
        XCTAssertNil(MapPinCategory.unverified.pinLines)
        XCTAssertEqual(MapPinCategory.checkDetail.symbolName, "questionmark")
        XCTAssertEqual(MapPinCategory.unverified.symbolName, "pawprint.fill")
        for category in [MapPinCategory.indoorOK, .terraceOnly, .checkDetail, .unverified] {
            // 文字か絵柄のどちらかは必ずある（どちらもないと中が空のピンになる）
            XCTAssertTrue(category.pinLines != nil || category.symbolName != nil)
            // iOS 17 で使える SF Symbol か（描けないと絵柄が消える）
            if let name = category.symbolName { XCTAssertNotNil(UIImage(systemName: name), name) }
        }
    }

    func test_ピンの中の文字は地の色と3対1以上() {
        func luminance(_ color: UIColor) -> CGFloat {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &a))
            let linear = [r, g, b].map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        }
        for category in [MapPinCategory.indoorOK, .terraceOnly, .checkDetail, .unverified] {
            let a = luminance(MapPinRenderer.fillColor(for: category)), b = luminance(MapPinRenderer.glyphColor(for: category))
            let ratio = (max(a, b) + 0.05) / (min(a, b) + 0.05)
            // 橙（条件を確認）は白い「？」で従来から 3:1 弱。文字を載せる店内OK・テラスは 3:1 以上を守る
            if category == .indoorOK || category == .terraceOnly {
                XCTAssertGreaterThanOrEqual(ratio, 3, "\(category)")
            }
        }
        // 店内OKは薄いピンクの地に濃い文字（白ではない）
        XCTAssertNotEqual(MapPinRenderer.glyphColor(for: .indoorOK), .white)
    }

    func test_テラスのピンの色は青で白い絵柄と3対1以上() {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(MapPinRenderer.fillColor(for: .terraceOnly).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(Int((red * 255).rounded()), 0x1F)
        XCTAssertEqual(Int((green * 255).rounded()), 0x7F)
        XCTAssertEqual(Int((blue * 255).rounded()), 0xB5)
        func linear(_ value: CGFloat) -> CGFloat { value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        XCTAssertGreaterThanOrEqual(1.05 / (luminance + 0.05), 3)
    }

    func test_寄せ具合で店名の出し方が変わる() {
        let tokyo = 35.68
        // 大きく寄せている（600m 未満）: 全部
        XCTAssertEqual(MapViewModel.pinNameMode(span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004), centerLatitude: tokyo), .all)
        // 緯度幅 0.02 度以下: 起点に近い3店と選んだ店だけ
        XCTAssertEqual(MapViewModel.pinNameMode(span: MKCoordinateSpan(latitudeDelta: 0.0144, longitudeDelta: 0.0144), centerLatitude: tokyo), .nearby)
        XCTAssertEqual(MapViewModel.pinNameMode(span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02), centerLatitude: tokyo), .nearby)
        // 広い縮尺: 出さない
        XCTAssertEqual(MapViewModel.pinNameMode(span: MKCoordinateSpan(latitudeDelta: 0.0201, longitudeDelta: 0.02), centerLatitude: tokyo), .none)
        XCTAssertEqual(MapViewModel.pinNameMode(span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1), centerLatitude: tokyo), .none)
    }

    func test_起点に近い先頭3店のidを返す() {
        let items = [900.0, 100, 500, 300, 700].map { meters -> CafeWithDistance in
            let cafe = Cafe(
                id: UUID(), placeID: nil, name: "\(Int(meters))", latitude: 35.68, longitude: 139.76,
                address: nil, contact: nil, dogPolicyStatus: .allowed, dogPolicyCondition: nil,
                lastVerified: nil, representativeSourceID: nil, hasConflict: false, isClosed: false, area: "tokyo"
            )
            return CafeWithDistance(cafe: cafe, distanceMeters: meters)
        }
        let ids = MapViewModel.nearestIDs(of: items)
        XCTAssertEqual(ids.count, 3)
        XCTAssertEqual(Set(items.filter { [100, 300, 500].contains($0.distanceMeters) }.map(\.cafe.id)), ids)
        XCTAssertEqual(MapViewModel.nearestIDs(of: Array(items.prefix(2))).count, 2)
        XCTAssertTrue(MapViewModel.nearestIDs(of: []).isEmpty)
    }

    func test_店名を出すピンの判定() {
        // 全部
        XCTAssertTrue(MapViewModel.showsName(mode: .all, isNearest: false, isSelected: false))
        // 少し寄せている: 近い3店と選んだ店だけ
        XCTAssertTrue(MapViewModel.showsName(mode: .nearby, isNearest: true, isSelected: false))
        XCTAssertTrue(MapViewModel.showsName(mode: .nearby, isNearest: false, isSelected: true))
        XCTAssertFalse(MapViewModel.showsName(mode: .nearby, isNearest: false, isSelected: false))
        // 広い縮尺は出さない
        XCTAssertFalse(MapViewModel.showsName(mode: .none, isNearest: true, isSelected: true))
    }


    func test_店名の近い3店は見えている範囲の中で数える() {
        let items = [100.0, 200, 300, 400, 5_000, 6_000].map { meters -> CafeWithDistance in
            let cafe = Cafe(
                id: UUID(), placeID: nil, name: "\(Int(meters))", latitude: 35.68, longitude: 139.76,
                address: nil, contact: nil, dogPolicyStatus: .allowed, dogPolicyCondition: nil,
                lastVerified: nil, representativeSourceID: nil, hasConflict: false, isClosed: false, area: "tokyo"
            )
            return CafeWithDistance(cafe: cafe, distanceMeters: meters)
        }
        // 起点から遠い場所（5km・6km の店）だけが見えているときも、その中の近い順で出る
        let farVisible = Set(items.suffix(2).map(\.cafe.id))
        XCTAssertEqual(MapViewModel.nearestIDs(of: items, visibleIDs: farVisible), farVisible)
        // 見えている店が多いときは、その中の起点に近い3店
        let visible = Set(items.map(\.cafe.id)).subtracting([items[0].cafe.id])
        XCTAssertEqual(
            MapViewModel.nearestIDs(of: items, visibleIDs: visible),
            Set(items[1...3].map(\.cafe.id))
        )
        // 何も見えていなければ空
        XCTAssertTrue(MapViewModel.nearestIDs(of: items, visibleIDs: []).isEmpty)
    }
}
