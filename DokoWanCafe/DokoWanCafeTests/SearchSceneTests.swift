import XCTest
@testable import DokoWanCafe

/// 検索画面「場面から探す」の場面→条件の対応（純ロジック, 原則I: データに明記された事実だけで絞る）
final class SearchSceneTests: XCTestCase {
    private func tokyo(hour: Int, minute: Int = 0, day: Int = 6) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    func test_場面は5つで順番が決まっている() {
        XCTAssertEqual(SearchScene.allCases, [.rainy, .terrace, .largeDog, .night, .dogMenu])
        XCTAssertEqual(
            SearchScene.allCases.map(\.title),
            ["雨の日でも", "テラスでのんびり", "大型犬と一緒に", "夜も開いている", "犬メニューがある"]
        )
    }

    func test_席と犬の場面は対応する条件だけを入れる() {
        let now = tokyo(hour: 12)
        XCTAssertEqual(SearchScene.rainy.conditions(now: now), .init(amenities: AmenityFilter(indoorOnly: true)))
        XCTAssertEqual(SearchScene.terrace.conditions(now: now), .init(amenities: AmenityFilter(terraceOnly: true)))
        XCTAssertEqual(SearchScene.largeDog.conditions(now: now), .init(amenities: AmenityFilter(largeDogOnly: true)))
        XCTAssertEqual(SearchScene.dogMenu.conditions(now: now), .init(amenities: AmenityFilter(dogMenuOnly: true)))
    }

    func test_雨の日でもは天気を見ない_今の時刻に関わらず同じ条件() {
        XCTAssertEqual(SearchScene.rainy.conditions(now: tokyo(hour: 3)), SearchScene.rainy.conditions(now: tokyo(hour: 23)))
    }

    func test_夜も開いているは今日の20時_過ぎていたら今() {
        let morning = SearchScene.night.conditions(now: tokyo(hour: 9))
        XCTAssertTrue(morning.openNowOnly)
        XCTAssertTrue(morning.amenities.isEmpty)
        XCTAssertEqual(morning.targetTime, tokyo(hour: 20))

        XCTAssertEqual(SearchScene.night.conditions(now: tokyo(hour: 20)).targetTime, tokyo(hour: 20), "ちょうど20時はまだ今日の20時")
        XCTAssertNil(SearchScene.night.conditions(now: tokyo(hour: 20, minute: 1)).targetTime)
        XCTAssertNil(SearchScene.night.conditions(now: tokyo(hour: 23, minute: 30)).targetTime)
        XCTAssertTrue(SearchScene.night.conditions(now: tokyo(hour: 23, minute: 30)).openNowOnly)
    }

    func test_夜の20時は日付をまたぐ直前でも今日() {
        // 東京の日付で数える（UTC では前日・翌日になる時刻でも）
        XCTAssertEqual(SearchScene.night.conditions(now: tokyo(hour: 0, minute: 30)).targetTime, tokyo(hour: 20))
    }
}
