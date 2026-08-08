import XCTest
@testable import DokoWanCafe

/// 経路チューザー機能: `RouteLauncher.googleMapsURL` のユニットテスト（純ロジック, 憲章 原則IV）
final class RouteLauncherTests: XCTestCase {
    func test_appInstalledがtrueならcomgooglemapsスキームになる() {
        let url = RouteLauncher.googleMapsURL(latitude: 35.681236, longitude: 139.767125, appInstalled: true)
        XCTAssertEqual(url.absoluteString, "comgooglemaps://?daddr=35.681236,139.767125")
    }

    func test_appInstalledがfalseならWeb版のユニバーサルURLになる() {
        let url = RouteLauncher.googleMapsURL(latitude: 35.681236, longitude: 139.767125, appInstalled: false)
        XCTAssertEqual(
            url.absoluteString,
            "https://www.google.com/maps/dir/?api=1&destination=35.681236,139.767125"
        )
    }

    func test_座標フォーマットは緯度経度をカンマ区切りで結合する() {
        let appURL = RouteLauncher.googleMapsURL(latitude: -35.5, longitude: 139.0, appInstalled: true)
        XCTAssertTrue(appURL.absoluteString.contains("daddr=-35.5,139.0"))

        let webURL = RouteLauncher.googleMapsURL(latitude: -35.5, longitude: 139.0, appInstalled: false)
        XCTAssertTrue(webURL.absoluteString.contains("destination=-35.5,139.0"))
    }
}
