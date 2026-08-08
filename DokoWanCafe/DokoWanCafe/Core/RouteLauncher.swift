import CoreLocation
import MapKit
import UIKit

/// 経路案内で開く地図アプリ（経路チューザー機能）。
enum RouteApp {
    case apple
    case google
}

/// 経路案内の起動ロジック（憲章 原則IV: 純ロジックはCoreに隔離しXCTest対象）。
/// Apple マップ / Google マップ のいずれかをユーザーに選ばせ、対応するアプリ（未インストール時はWeb）を開く。
enum RouteLauncher {
    /// Googleマップの経路URLを組み立てる純関数。
    /// - `appInstalled == true`: Googleマップアプリのカスタムスキーム（`comgooglemaps://`）
    /// - `appInstalled == false`: Web版のユニバーサルURL（未インストール時のフォールバック）
    static func googleMapsURL(latitude: Double, longitude: Double, appInstalled: Bool) -> URL {
        let destination = "\(latitude),\(longitude)"
        if appInstalled {
            return URL(string: "comgooglemaps://?daddr=\(destination)")!
        } else {
            return URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(destination)")!
        }
    }

    /// 選択された地図アプリで経路案内を開く。
    /// - Apple マップ: `MKMapItem.openInMaps`（既存 `MapViewModel.openInMaps` / `CafeDetailViewModel.openInMaps` を置換）
    /// - Google マップ: `canOpenURL` でアプリの有無を判定し、未インストールならWeb版にフォールバックする
    static func open(cafe: Cafe, using app: RouteApp) {
        switch app {
        case .apple:
            let placemark = MKPlacemark(
                coordinate: CLLocationCoordinate2D(latitude: cafe.latitude, longitude: cafe.longitude)
            )
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = cafe.name
            mapItem.openInMaps(launchOptions: nil)
        case .google:
            let appInstalled = UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!)
            let url = googleMapsURL(latitude: cafe.latitude, longitude: cafe.longitude, appInstalled: appInstalled)
            UIApplication.shared.open(url)
        }
    }
}
