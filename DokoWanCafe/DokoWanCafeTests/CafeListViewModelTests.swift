import XCTest
@testable import DokoWanCafe

/// CafeListViewModel のユニットテスト。
/// データ層（StaticCafeRepository）は全カフェをローカル保持しており取得コストが実質ゼロのため、
/// CafeListViewModel は「半径3km/10km」のような人為的な足切りをせず、実質無制限の安全半径
/// （fetchSafetyRadiusMeters）でリポジトリへ問い合わせる（地図UX設計・spec.md SC-005 参照）。
@MainActor
final class CafeListViewModelTests: XCTestCase {
    /// 距離に応じて実際にフィルタする、実リポジトリ同等の振る舞いのモック
    /// （渡された radiusMeters を正しく尊重することで、呼び出し側の半径指定を検証できる）。
    private struct DistanceFilteringMockRepository: CafeRepository {
        let cafes: [Cafe]

        func nearbyCafes(
            latitude: Double, longitude: Double, radiusMeters: Int, onlyDogOK: Bool
        ) async throws -> [CafeWithDistance] {
            var results: [CafeWithDistance] = []
            for cafe in cafes where !cafe.isClosed {
                if onlyDogOK && cafe.dogPolicyStatus != .allowed && cafe.dogPolicyStatus != .conditional {
                    continue
                }
                let distance = DistanceCalculator.distanceMeters(
                    fromLatitude: latitude, fromLongitude: longitude,
                    toLatitude: cafe.latitude, toLongitude: cafe.longitude
                )
                if distance <= Double(radiusMeters) {
                    results.append(CafeWithDistance(cafe: cafe, distanceMeters: distance))
                }
            }
            results.sort { $0.distanceMeters < $1.distanceMeters }
            return results
        }

        func cafeDetail(id: UUID) async throws -> CafeDetail {
            guard let cafe = cafes.first(where: { $0.id == id }) else { throw SupabaseError.emptyResponse }
            return CafeDetail(cafe: cafe, sources: [])
        }
    }

    private func makeCafe(name: String, latitude: Double, longitude: Double) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: name,
            latitude: latitude, longitude: longitude,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo"
        )
    }

    private func makeViewModel(cafes: [Cafe]) -> CafeListViewModel {
        CafeListViewModel(
            repository: DistanceFilteringMockRepository(cafes: cafes),
            locationService: LocationService(),
            cacheStore: CacheStore(filename: "test-cache-\(UUID().uuidString).json")
        )
    }

    func test_旧半径10kmを超える遠方カフェも取得される() async {
        // 新宿(基準点)から東西南北のどちら向きでも旧上限10kmを超える、約14.5km西の地点に1件配置
        let origin = ManualArea(id: "test-shinjuku", name: "テスト:新宿", latitude: 35.6896, longitude: 139.7006)
        let nearCafe = makeCafe(name: "近くのカフェ", latitude: 35.6900, longitude: 139.7010)
        let farCafe = makeCafe(name: "遠方カフェ(約14.5km)", latitude: 35.6528, longitude: 139.5470)

        let viewModel = makeViewModel(cafes: [nearCafe, farCafe])
        viewModel.origin = .manual(origin)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.phase, .loaded)
        let names = Set(viewModel.allResults.map(\.cafe.name))
        XCTAssertTrue(
            names.contains("遠方カフェ(約14.5km)"),
            "旧半径(既定3km/拡大10km)なら除外されていたはずの遠方カフェが、安全半径の拡大により含まれる"
        )
        XCTAssertTrue(names.contains("近くのカフェ"))
    }

    func test_displayedResultsは距離昇順() async {
        let origin = ManualArea(id: "test-shinjuku", name: "テスト:新宿", latitude: 35.6896, longitude: 139.7006)
        let far = makeCafe(name: "遠い", latitude: 35.70, longitude: 139.80)
        let near = makeCafe(name: "近い", latitude: 35.6897, longitude: 139.7007)

        let viewModel = makeViewModel(cafes: [far, near])
        viewModel.origin = .manual(origin)
        await viewModel.refresh()

        XCTAssertEqual(viewModel.displayedResults.map(\.cafe.name), ["近い", "遠い"])
    }

    func test_可否フィルタの組合せで該当がなければdisplayedResultsは空() async {
        let origin = ManualArea(id: "test-shinjuku", name: "テスト:新宿", latitude: 35.6896, longitude: 139.7006)
        let cafe = makeCafe(name: "犬OKカフェ", latitude: 35.6897, longitude: 139.7007)

        let viewModel = makeViewModel(cafes: [cafe])
        viewModel.origin = .manual(origin)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertFalse(viewModel.displayedResults.isEmpty)

        // 「犬OK」以外だけを選ぶと、唯一のカフェ(allowed)が絞り込みで除外される（FR-004）
        viewModel.statusFilter = [.notAllowed]
        XCTAssertTrue(viewModel.displayedResults.isEmpty)
    }
}
