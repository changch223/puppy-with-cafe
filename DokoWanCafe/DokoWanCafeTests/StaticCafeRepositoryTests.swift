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

    // MARK: - リモート取得（タイムアウト設定・失敗後の再取得抑止）

    func test_既定セッションは15秒タイムアウト() {
        let configuration = StaticCafeRepository.makeDefaultSession().configuration
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 15)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 15)
        XCTAssertFalse(configuration.waitsForConnectivity)
    }

    private func makeRemoteRepository(
        failureRetryInterval: TimeInterval
    ) -> StaticCafeRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("repo-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: cacheDirectory) }
        return StaticCafeRepository(
            remoteURL: URL(string: "https://example.invalid/cafes.json"),
            bundle: Bundle(for: StaticCafeRepositoryTests.self),
            session: URLSession(configuration: configuration),
            cacheDirectory: cacheDirectory,
            failureRetryInterval: failureRetryInterval
        )
    }

    func test_取得失敗後は一定時間再取得せずバンドルで即表示を維持する() async throws {
        StubURLProtocol.reset(.failure(URLError(.notConnectedToInternet)))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        for _ in 0..<3 {
            _ = await repo.refreshRemote(force: false)
            let results = try await repo.nearbyCafes(
                latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: false
            )
            XCTAssertEqual(results.count, 7, "失敗してもバンドルデータで表示できる")
        }
        XCTAssertEqual(StubURLProtocol.requestCount, 1, "失敗後の5分間は再取得しない")
    }

    func test_再取得抑止の時間が過ぎれば再取得する() async throws {
        StubURLProtocol.reset(.failure(URLError(.timedOut)))
        let repo = makeRemoteRepository(failureRetryInterval: 0)

        _ = await repo.refreshRemote(force: false)
        _ = await repo.refreshRemote(force: false)
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func test_HTTPエラーも失敗として扱い再取得を抑止する() async throws {
        StubURLProtocol.reset(.status(503))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        let first = await repo.refreshRemote(force: false)
        let second = await repo.refreshRemote(force: false)
        XCTAssertFalse(first)
        XCTAssertFalse(second)
        _ = try await repo.allCafes()
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func test_取得成功後は通常間隔で再取得しない() async throws {
        let url = try XCTUnwrap(Bundle(for: StaticCafeRepositoryTests.self).url(forResource: "cafes", withExtension: "json"))
        StubURLProtocol.reset(.success(try Data(contentsOf: url)))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        _ = await repo.refreshRemote(force: false)
        let results = try await repo.nearbyCafes(latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: false)
        XCTAssertEqual(results.count, 7)
        _ = await repo.refreshRemote(force: false)
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    // MARK: - stale-while-revalidate（検索はネットワークを待たない / refreshRemote）

    /// フィクスチャの cafes.json から末尾1件を除いた「更新後データ」（件数7→6）
    private func updatedFixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: StaticCafeRepositoryTests.self).url(forResource: "cafes", withExtension: "json"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var cafes = try XCTUnwrap(object["cafes"] as? [[String: Any]])
        cafes.removeLast()
        object["cafes"] = cafes
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: StaticCafeRepositoryTests.self).url(forResource: "cafes", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func test_取得が実行中でも検索はすぐ返る() async throws {
        StubURLProtocol.reset(.gated(try updatedFixtureData()))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        // 応答を止めたまま、遅い取得を実際に走らせる
        let refresh = Task { await repo.refreshRemote(force: false) }
        await waitForRequestCount(1)

        // 取得が実行中（ゲート閉）でも、検索は待たずにローカルデータで返る
        let searched = expectation(description: "検索が取得を待たずに返る")
        let search = Task { () -> (nearby: Int, all: Int) in
            let nearby = try await repo.nearbyCafes(latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: false)
            let all = try await repo.allCafes()
            searched.fulfill()
            return (nearby.count, all.count)
        }
        await fulfillment(of: [searched], timeout: 2)
        StubURLProtocol.openGate()  // 失敗時もタスクが残らないよう必ず開放する

        let counts = try await search.value
        XCTAssertEqual(counts.nearby, 7, "取得中は取得前のバンドルデータ")
        XCTAssertEqual(counts.all, 7)
        let changed = await refresh.value
        XCTAssertTrue(changed)
        XCTAssertEqual(StubURLProtocol.requestCount, 1, "検索自体はリモート取得を起こさない")
    }

    /// StubURLProtocol が指定回数のリクエストを受け付けるまで待つ（ポーリング。最大5秒）
    private func waitForRequestCount(_ count: Int) async {
        let deadline = Date().addingTimeInterval(5)
        while StubURLProtocol.requestCount < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertGreaterThanOrEqual(StubURLProtocol.requestCount, count)
    }

    func test_refreshRemote_変更があればtrueで以後の検索に反映される() async throws {
        StubURLProtocol.reset(.success(try updatedFixtureData()))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        let changed = await repo.refreshRemote(force: false)
        XCTAssertTrue(changed)
        let nearby = try await repo.nearbyCafes(latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: false)
        XCTAssertEqual(nearby.count, 6, "取得後は新しいデータ")
    }

    func test_refreshRemote_変更がなければfalse() async throws {
        StubURLProtocol.reset(.success(try fixtureData()))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        let changed = await repo.refreshRemote(force: false)
        XCTAssertFalse(changed, "バンドルと同一内容なら変更なし")
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func test_refreshRemote_失敗はfalseでバックオフが効きforceは無視する() async throws {
        StubURLProtocol.reset(.failure(URLError(.notConnectedToInternet)))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        let first = await repo.refreshRemote(force: false)
        let second = await repo.refreshRemote(force: false)
        XCTAssertFalse(first)
        XCTAssertFalse(second)
        XCTAssertEqual(StubURLProtocol.requestCount, 1, "失敗後の5分間は非forceで再取得しない")

        _ = await repo.refreshRemote(force: true)
        XCTAssertEqual(StubURLProtocol.requestCount, 2, "force は抑止を無視して取得する")
    }

    func test_refreshRemote_成功後は取得間隔内なら非forceで再取得しないがforceは取得する() async throws {
        StubURLProtocol.reset(.success(try updatedFixtureData()))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        let first = await repo.refreshRemote(force: false)
        let second = await repo.refreshRemote(force: false)
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(StubURLProtocol.requestCount, 1, "15分間隔内は再取得しない")

        let forced = await repo.refreshRemote(force: true)
        XCTAssertFalse(forced, "同じ内容なら force でも変更なし")
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func test_refreshRemote_不正なデータは差し替えずfalse() async throws {
        StubURLProtocol.reset(.success(Data("not json".utf8)))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        let changed = await repo.refreshRemote(force: false)
        XCTAssertFalse(changed)
        let nearby = try await repo.nearbyCafes(latitude: lat, longitude: lng, radiusMeters: 3_000, onlyDogOK: false)
        XCTAssertEqual(nearby.count, 7, "不正データでバンドルを壊さない")
    }

    func test_refreshRemote_同時呼び出しは1本の取得に相乗りする() async throws {
        StubURLProtocol.reset(.gated(try updatedFixtureData()))
        let repo = makeRemoteRepository(failureRetryInterval: 300)

        let first = Task { await repo.refreshRemote(force: false) }
        await waitForRequestCount(1)  // 1本目はゲートで止まっている
        let second = Task { await repo.refreshRemote(force: true) }
        // 2本目が実行中の取得に相乗りしたことを確認してから開放する（遅延に頼らない）
        let deadline = Date().addingTimeInterval(5)
        while repo.coalescedRefreshCount < 1, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(repo.coalescedRefreshCount, 1)
        StubURLProtocol.openGate()

        let results = await [first.value, second.value]
        XCTAssertEqual(StubURLProtocol.requestCount, 1, "同時に2本走らない")
        XCTAssertEqual(results, [true, true])
    }

    func test_リモートURL未設定ならrefreshRemoteは何もしない() async {
        let changed = await repository.refreshRemote(force: true)
        XCTAssertFalse(changed)
    }
}

/// リモート取得テスト用のスタブ（ネットワークに出ない）。テストは直列実行のため static 状態を使う。
final class StubURLProtocol: URLProtocol {
    enum Behavior {
        case failure(URLError)
        case status(Int)
        case success(Data)
        /// `openGate()` が呼ばれるまで応答を止め、開放後に成功レスポンスを返す（遅延を時間に頼らず再現）
        case gated(Data)
    }

    nonisolated(unsafe) static var behavior: Behavior = .failure(URLError(.notConnectedToInternet))
    nonisolated(unsafe) static var requestCount = 0

    private nonisolated(unsafe) static var gateOpen = false
    private nonisolated(unsafe) static var pending: [(StubURLProtocol, Data)] = []
    private static let gateLock = NSLock()

    static func reset(_ behavior: Behavior) {
        self.behavior = behavior
        requestCount = 0
        gateLock.withLock {
            gateOpen = false
            pending = []
        }
    }

    /// `.gated` で止めていた応答をすべて返し、以後のリクエストは即応答する
    static func openGate() {
        let waiting = gateLock.withLock { () -> [(StubURLProtocol, Data)] in
            gateOpen = true
            defer { pending = [] }
            return pending
        }
        for (loader, data) in waiting { loader.deliverSuccess(data) }
    }

    private func deliverSuccess(_ data: Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        let url = request.url!
        switch Self.behavior {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .status(let code):
            let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .success(let data):
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .gated(let data):
            let open = Self.gateLock.withLock { () -> Bool in
                if !Self.gateOpen { Self.pending.append((self, data)) }
                return Self.gateOpen
            }
            if open { deliverSuccess(data) }
        }
    }

    override func stopLoading() {}
}
