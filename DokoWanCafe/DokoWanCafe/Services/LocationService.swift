import CoreLocation
import Foundation

enum LocationError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied:
            return String(localized: "位置情報の利用が許可されていません。")
        case .unavailable:
            return String(localized: "現在地を取得できませんでした。")
        }
    }
}

/// 手動指定エリア（FR-017: 位置情報が使えない場合の代替導線）
struct ManualArea: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    /// v1（東京）の主要エリアプリセット
    static let tokyoPresets: [ManualArea] = [
        ManualArea(id: "tennoz", name: "天王洲アイル", latitude: 35.6229, longitude: 139.7496),
        ManualArea(id: "tokyo-station", name: "東京駅周辺", latitude: 35.6812, longitude: 139.7671),
        ManualArea(id: "shibuya", name: "渋谷", latitude: 35.6580, longitude: 139.7016),
        ManualArea(id: "shinjuku", name: "新宿", latitude: 35.6896, longitude: 139.7006),
        ManualArea(id: "ikebukuro", name: "池袋", latitude: 35.7295, longitude: 139.7109),
        ManualArea(id: "kichijoji", name: "吉祥寺", latitude: 35.7033, longitude: 139.5797),
        ManualArea(id: "jiyugaoka", name: "自由が丘", latitude: 35.6072, longitude: 139.6690),
        ManualArea(id: "nakameguro", name: "中目黒", latitude: 35.6440, longitude: 139.6982),
        ManualArea(id: "tachikawa", name: "立川", latitude: 35.6977, longitude: 139.4137),
    ]
}

/// 位置情報サービス（憲章 原則III / FR-016）。
/// - 「使用中のみ (WhenInUse)」でのみ権限を要求する。
/// - 取得した座標は周辺検索の入力にのみ使い、永続保存しない。
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var authorizationContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []
    private var locationContinuations: [CheckedContinuation<CLLocationCoordinate2D, Error>] = []

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// WhenInUse 権限を確認し、未決定ならリクエストして結果を待つ
    func ensureAuthorization() async -> CLAuthorizationStatus {
        switch manager.authorizationStatus {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuations.append(continuation)
                manager.requestWhenInUseAuthorization()
            }
        default:
            return manager.authorizationStatus
        }
    }

    /// 現在地をワンショットで取得（保存しない）
    func currentLocation() async throws -> CLLocationCoordinate2D {
        let status = await ensureAuthorization()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw LocationError.denied
        }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuations.append(continuation)
            manager.requestLocation()
        }
    }

    private func resumeAuthorization(with status: CLAuthorizationStatus) {
        authorizationStatus = status
        guard status != .notDetermined else { return }
        let continuations = authorizationContinuations
        authorizationContinuations = []
        continuations.forEach { $0.resume(returning: status) }
    }

    private func resumeLocation(with result: Result<CLLocationCoordinate2D, Error>) {
        let continuations = locationContinuations
        locationContinuations = []
        switch result {
        case .success(let coordinate):
            continuations.forEach { $0.resume(returning: coordinate) }
        case .failure(let error):
            continuations.forEach { $0.resume(throwing: error) }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.resumeAuthorization(with: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.resumeLocation(with: .success(coordinate))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resumeLocation(with: .failure(LocationError.unavailable))
        }
    }
}
