import CoreLocation
import Foundation

/// 住所・駅名検索サービス（機能2: 住所・駅名で周辺のカフェを探せる）。
///
/// `CLGeocoder` はユーザーが `AreaPickerView` の検索欄に入力した検索クエリ（住所・駅名等の文字列）
/// のみをAppleへ送信する。GPS由来の現在地は送信しない（憲章 原則III: 検索座標のみ送信、に整合）。
final class GeocodingService {
    /// クエリ正規化・regionヒント生成などの純ロジック（ネットワーク非依存・XCTest対象）
    enum PureLogic {
        /// 前後の空白・改行を取り除いた検索クエリ。空文字なら nil（検索を実行しない）。
        static func normalizedQuery(_ raw: String) -> String? {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        /// 日本周辺の候補を優先させる region ヒント（v1は東京のみ対応のため、無関係な地名の誤爆を減らす）。
        /// 中心は日本のおおよその中心（岐阜県付近）、半径は北海道〜沖縄まで日本全土を包含する値。
        static func japanRegionHint() -> CLCircularRegion {
            CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                radius: 1_600_000,
                identifier: "japan"
            )
        }
    }

    private let geocoder: CLGeocoder

    init(geocoder: CLGeocoder = CLGeocoder()) {
        self.geocoder = geocoder
    }

    /// 住所・駅名・エリア名などの文字列から座標を検索する。
    /// - Parameter query: ユーザーが入力した検索クエリ（Appleへ送信されるのはこの文字列のみ）
    /// - Returns: 見つかった場所の名称と座標。空クエリ・見つからない・失敗時は nil。
    func search(_ query: String) async -> (name: String, coordinate: CLLocationCoordinate2D)? {
        guard let normalized = PureLogic.normalizedQuery(query) else { return nil }
        do {
            let placemarks = try await geocoder.geocodeAddressString(normalized, in: PureLogic.japanRegionHint())
            guard let placemark = placemarks.first, let location = placemark.location else { return nil }
            return (Self.displayName(for: placemark, fallback: normalized), location.coordinate)
        } catch {
            return nil
        }
    }

    /// プレースマークから表示用の名称を組み立てる（施設名・地名を優先、なければ入力クエリをそのまま使う）
    private static func displayName(for placemark: CLPlacemark, fallback: String) -> String {
        if let name = placemark.name, !name.isEmpty {
            return name
        }
        return fallback
    }
}
