import XCTest
@testable import DokoWanCafe

/// T069: 静的データリポジトリのユニットテスト（FR-029/032, 構成B）
/// バンドルされた cafes.json（tools/export_cafes.py の出力）を読み、
/// nearby_cafes と同じ契約（半径・可否フィルタ・距離昇順・閉店除外）を検証する。
final class StaticCafeRepositoryTests: XCTestCase {
    private var repository: StaticCafeRepository!

    // 東京駅
    private let lat = 35.6812
    private let lng = 139.7671

    override func setUp() {
        super.setUp()
        // remoteURL なし → 固定フィクスチャ（テストバンドル同梱の架空サンプル7件）で決定論的に検証。
        // アプリ本体のバンドル cafes.json は実データに置き換わったため、テストは凍結フィクスチャを使う。
        repository = StaticCafeRepository(remoteURL: nil, bundle: Bundle(for: StaticCafeRepositoryTests.self))
    }

    func test_バンドルデータが読み込まれメタ情報を持つ() {
        XCTAssertTrue(repository.isSampleData, "同梱データはサンプルフラグつきのはず")
        XCTAssertNotNil(repository.generatedAt, "生成日時（鮮度, FR-032）を持つはず")
    }

    func test_周辺検索_犬OKのみ_半径3km() async throws {
        let results = try await repository.nearbyCafes(
            latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: true
        )
        // サンプル7件中: unverified(神田)・not_allowed(有楽町) を除く5件
        XCTAssertEqual(results.count, 5)
        XCTAssertFalse(results.contains { $0.cafe.dogPolicyStatus == .notAllowed })
        XCTAssertFalse(results.contains { $0.cafe.dogPolicyStatus == .unverified })
    }

    func test_周辺検索_全ステータス_距離昇順() async throws {
        let results = try await repository.nearbyCafes(
            latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: false
        )
        XCTAssertEqual(results.count, 7)
        let distances = results.map(\.distanceMeters)
        XCTAssertEqual(distances, distances.sorted(), "距離昇順で返る契約（SC-005）")
        XCTAssertTrue(results.allSatisfy { $0.distanceMeters <= 3_000 })
    }

    func test_半径で絞られる() async throws {
        let results = try await repository.nearbyCafes(
            latitude: lat, longitude: lng, radiusMeters: 300, onlyDogOK: false
        )
        XCTAssertTrue(results.count < 7, "半径300mでは一部のみのはず")
    }

    func test_詳細に出典と代表根拠が含まれる() async throws {
        let nearby = try await repository.nearbyCafes(
            latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: true
        )
        let first = try XCTUnwrap(nearby.first)
        let detail = try await repository.cafeDetail(id: first.cafe.id)
        XCTAssertEqual(detail.cafe.id, first.cafe.id)
        XCTAssertFalse(detail.sources.isEmpty, "犬OK表示のカフェは出典を持つ（FR-008/009）")
        XCTAssertNotNil(detail.cafe.representativeSourceID, "採用根拠をたどれる（FR-013）")
    }

    func test_矛盾フラグがエクスポートで導出されている() async throws {
        let results = try await repository.nearbyCafes(
            latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: false
        )
        // サンプルには矛盾ケース（日本橋: 公式=可 vs ブログ=不可）が1件含まれる
        XCTAssertEqual(results.filter { $0.cafe.hasConflict }.count, 1)
    }

    func test_存在しないIDの詳細はエラー() async {
        do {
            _ = try await repository.cafeDetail(id: UUID())
            XCTFail("存在しないIDは失敗するはず")
        } catch {
            // expected
        }
    }
}
