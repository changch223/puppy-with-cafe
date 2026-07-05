import Foundation

/// アプリ全体の依存を組み立てる DI コンテナ（T021 / 2026-07-05 構成Bへ改訂: research.md R11）。
///
/// カフェデータはバンドル＋静的URL配信の `StaticCafeRepository` から供給する。
/// 旧A案（Supabase）のコードは `Services/Supabase*` 等に保管しているが、v1 では配線しない。
@MainActor
final class AppDependencies: ObservableObject {
    let staticRepository: StaticCafeRepository
    let repository: any CafeRepository
    let locationService: LocationService
    let cacheStore: CacheStore

    /// 架空のサンプルデータで動作中か（データファイルの is_sample_data。誤認防止バナー表示）
    var isSampleMode: Bool { staticRepository.isSampleData }

    /// 表示中データの生成日時（FR-032: 鮮度の提示）
    var dataGeneratedAt: Date? { staticRepository.generatedAt }

    init() {
        let staticRepository = StaticCafeRepository(remoteURL: AppEnvironment.cafesDataURL())
        self.staticRepository = staticRepository
        self.repository = staticRepository
        self.locationService = LocationService()
        self.cacheStore = CacheStore()
    }
}
