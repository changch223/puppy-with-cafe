import CoreLocation
import Foundation

/// 検索の起点（現在地 or 手動指定エリア, FR-017）
enum SearchOrigin: Equatable {
    case currentLocation
    case manual(ManualArea)

    var displayName: String {
        switch self {
        case .currentLocation: return String(localized: "現在地")
        case .manual(let area): return area.name
        }
    }
}

/// 周辺検索の共有 ViewModel（T022）。
/// 地図・一覧の両方がこの ViewModel の `displayedResults` を参照する（FR-003）。
@MainActor
final class CafeListViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        /// 0件（FR-020: 範囲拡大・地域変更を案内）
        case empty
        /// 対象エリア外（FR-022: 「該当0件」と誤認させない）
        case outOfArea
        /// 位置情報の許可なし（FR-017: 手動地域指定へ誘導）
        case locationDenied
        /// 通信不可・直近キャッシュを表示中（FR-029: 鮮度を明示）
        case offline(fetchedAt: Date)
        case error(String)
    }

    /// データ取得用の安全上限（UI向けの意味は持たない）。
    /// データはローカル（StaticCafeRepository）に全件保持されており、絞り込みコストは実質ゼロのため、
    /// 事実上「東京都内は無制限」とみなせる大きな値を使う（実測: 全268件の最大ペア間距離 約52.4km）。
    /// 地図の初期表示ズームは別途 `MapViewModel.initialCameraRegion` が距離分布から算出する。
    private static let fetchSafetyRadiusMeters = 60_000

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var allResults: [CafeWithDistance] = []
    /// 可否ステータスの絞り込み（FR-004）。既定は「可・条件付き」
    @Published var statusFilter: Set<DogPolicyStatus> = [.allowed, .conditional]
    @Published var origin: SearchOrigin = .currentLocation
    @Published private(set) var searchCenter: CLLocationCoordinate2D?

    private let repository: any CafeRepository
    private let locationService: LocationService
    private let cacheStore: CacheStore

    init(repository: any CafeRepository, locationService: LocationService, cacheStore: CacheStore) {
        self.repository = repository
        self.locationService = locationService
        self.cacheStore = cacheStore
    }

    /// 一覧・地図で共有する表示用の結果（絞り込み＋距離昇順, FR-004/005）
    var displayedResults: [CafeWithDistance] {
        CafeFilter.apply(statusFilter, to: allResults)
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    /// 周辺検索を実行（contracts/api-contracts.md #1 の利用側）
    func refresh() async {
        phase = .loading

        // 1) 起点を解決（現在地 or 手動エリア）
        let coordinate: CLLocationCoordinate2D
        switch origin {
        case .currentLocation:
            do {
                coordinate = try await locationService.currentLocation()
            } catch LocationError.denied {
                phase = .locationDenied
                return
            } catch {
                phase = .error(LocationError.unavailable.localizedDescription)
                return
            }
        case .manual(let area):
            coordinate = CLLocationCoordinate2D(latitude: area.latitude, longitude: area.longitude)
        }
        searchCenter = coordinate

        // 2) 提供エリア判定（FR-022: 対象外を 0件と誤認させない）
        guard SupportedArea.area(
            containingLatitude: coordinate.latitude,
            longitude: coordinate.longitude
        ) != nil else {
            allResults = []
            phase = .outOfArea
            return
        }

        // 3) 取得。失敗時は直近キャッシュにフォールバック（FR-029）
        do {
            let results = try await repository.nearbyCafes(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMeters: Self.fetchSafetyRadiusMeters,
                onlyDogOK: false
            )
            allResults = results
            cacheStore.save(results)
            phase = results.isEmpty ? .empty : .loaded
        } catch {
            if let cached = cacheStore.load(), !cached.cafes.isEmpty {
                allResults = cached.cafes
                phase = .offline(fetchedAt: cached.fetchedAt)
            } else {
                phase = .error(error.localizedDescription)
            }
        }
    }

    /// 地域を変更して再検索
    func changeOrigin(_ newOrigin: SearchOrigin) async {
        origin = newOrigin
        await refresh()
    }
}
