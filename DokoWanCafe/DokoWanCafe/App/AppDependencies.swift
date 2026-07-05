import Foundation

/// アプリ全体の依存を組み立てる DI コンテナ（T021）。
/// バックエンド未設定（環境変数なし）の場合はサンプルデータモードで起動し、UI 上で明示する。
@MainActor
final class AppDependencies: ObservableObject {
    let config: SupabaseConfig?
    let gateway: SupabaseGateway?
    let repository: any CafeRepository
    let locationService: LocationService
    let cacheStore: CacheStore
    let authService: AuthService
    let correctionService: CorrectionService

    /// バックエンド未設定 → 架空のサンプルデータで動作（誤認防止のためバナー表示）
    var isSampleMode: Bool { gateway == nil }

    init() {
        let config = SupabaseConfig.fromEnvironment()
        self.config = config

        let gateway = config.map { SupabaseGateway(config: $0) }
        self.gateway = gateway

        if let gateway {
            self.repository = SupabaseCafeRepository(gateway: gateway)
        } else {
            self.repository = SampleDataRepository()
        }

        self.locationService = LocationService()
        self.cacheStore = CacheStore()
        self.authService = AuthService(gateway: gateway)
        self.correctionService = CorrectionService(gateway: gateway, auth: authService)
    }
}
