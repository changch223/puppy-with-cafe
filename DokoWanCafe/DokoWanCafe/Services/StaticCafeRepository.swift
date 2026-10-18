import Foundation

/// 配信データファイル（tools/export_cafes.py が生成する cafes.json, FR-032）
struct CafeDataFile: Decodable {
    let formatVersion: Int
    let generatedAt: Date?
    let isSampleData: Bool
    let cafes: [CafeDetail]

    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"
        case generatedAt = "generated_at"
        case isSampleData = "is_sample_data"
        case cafes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
        isSampleData = try container.decodeIfPresent(Bool.self, forKey: .isSampleData) ?? false
        cafes = try container.decode([CafeDetail].self, forKey: .cafes)
    }
}

/// 静的データのリポジトリ（構成B: research.md R11, FR-029/032）。
///
/// データ源の優先順:
///   1. 静的URL（設定時）から取得した最新データ（ディスクにキャッシュ）
///   2. 直近のディスクキャッシュ
///   3. アプリにバンドルされた cafes.json
/// 検索・フィルタ・距離計算はすべて端末内で完結する（位置情報をどこにも送信しない: 憲章 原則III）。
///
/// stale-while-revalidate: `nearbyCafes` / `allCafes` はローカルにある最新データ（2 or 3）から即座に返し、
/// リモート取得は待たない。リモート取得は `refreshRemote(force:)` を呼び出し側が裏で実行する。
final class StaticCafeRepository: CafeRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var details: [CafeDetail] = []
    private var _generatedAt: Date?
    private var _isSampleData = false
    private var lastRemoteFetch: Date?
    /// 直近の取得失敗時刻（失敗直後の連続再取得を防ぐ）
    private var lastRemoteFailure: Date?
    /// 実行中のリモート取得（同時に2本走らせず、後から来た呼び出しは同じ結果に相乗りする）
    private var inFlightRefresh: Task<Bool, Never>?
    /// 実行中の取得に相乗りした回数（テスト観測用: 相乗りを遅延に頼らず決定的に検証する）
    private var _coalescedRefreshCount = 0
    var coalescedRefreshCount: Int { lock.withLock { _coalescedRefreshCount } }

    private let remoteURL: URL?
    private let session: URLSession
    private let cacheFileURL: URL
    private let failureRetryInterval: TimeInterval

    /// リモート再取得の最小間隔
    private static let refreshInterval: TimeInterval = 15 * 60
    /// 取得失敗後の再取得抑止時間（オフライン時に毎回待たされないため）
    static let defaultFailureRetryInterval: TimeInterval = 5 * 60
    /// リモート取得のタイムアウト（秒）
    static let requestTimeout: TimeInterval = 15

    /// リモート取得用の既定セッション（15秒タイムアウト・接続待機なし・Cookie不保持）。
    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    var generatedAt: Date? {
        lock.withLock { _generatedAt }
    }

    var isSampleData: Bool {
        lock.withLock { _isSampleData }
    }

    /// - Parameters:
    ///   - cacheDirectory: リモート取得キャッシュの保存先（nil なら Application Support。テストで隔離する用途）
    ///   - failureRetryInterval: 取得失敗後に再取得しない時間
    init(
        remoteURL: URL?,
        bundle: Bundle = .main,
        session: URLSession = StaticCafeRepository.makeDefaultSession(),
        cacheDirectory: URL? = nil,
        failureRetryInterval: TimeInterval = StaticCafeRepository.defaultFailureRetryInterval
    ) {
        self.remoteURL = remoteURL
        self.session = session
        self.failureRetryInterval = failureRetryInterval

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = cacheDirectory ?? base.appendingPathComponent("DokoWanCafe", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.cacheFileURL = directory.appendingPathComponent("cafes-remote.json")

        // 1) 直近のリモート取得キャッシュ → 2) バンドル版 の順で初期ロード。
        // ただしリモートURLが未設定（nil）の場合はリモートキャッシュを信頼せずバンドルを読む。
        // リモートを配線しない構成（テスト・凍結フィクスチャ利用時）で、実アプリ起動が
        // 共有の applicationSupport に書いたキャッシュを誤って拾わないための独立性ガード。
        if remoteURL != nil,
           let cached = try? Data(contentsOf: cacheFileURL), apply(data: cached) != .invalid {
            return
        }
        if let url = bundle.url(forResource: "cafes", withExtension: "json"),
           let bundled = try? Data(contentsOf: url) {
            _ = apply(data: bundled)
        }
    }

    // MARK: - CafeRepository

    func nearbyCafes(
        latitude: Double,
        longitude: Double,
        radiusMeters: Int,
        onlyDogOK: Bool
    ) async throws -> [CafeWithDistance] {
        // ローカルの最新データから即返す（リモート取得は待たない）
        let snapshot = lock.withLock { details }

        // nearby_cafes RPC と同じ契約（半径・可否フィルタ・距離昇順・閉店除外）を端末内で実現
        var results: [CafeWithDistance] = []
        let radius = Double(radiusMeters)
        for detail in snapshot {
            let cafe: Cafe = detail.cafe
            if cafe.isClosed { continue }
            if onlyDogOK && cafe.dogPolicyStatus != .allowed && cafe.dogPolicyStatus != .conditional {
                continue
            }
            let distance = DistanceCalculator.distanceMeters(
                fromLatitude: latitude, fromLongitude: longitude,
                toLatitude: cafe.latitude, toLongitude: cafe.longitude
            )
            if distance <= radius {
                results.append(CafeWithDistance(cafe: cafe, distanceMeters: distance))
            }
        }
        results.sort { $0.distanceMeters < $1.distanceMeters }
        return results
    }

    func cafeDetail(id: UUID) async throws -> CafeDetail {
        let found = lock.withLock { details.first { $0.cafe.id == id } }
        guard let found else { throw SupabaseError.emptyResponse }
        return found
    }

    /// お気に入り専用画面向け（機能4）: 検索エリア・半径に関わらず、ロード済みの全カフェ（閉店除く）を返す。
    func allCafes() async throws -> [Cafe] {
        let snapshot = lock.withLock { details }

        return snapshot.map(\.cafe).filter { !$0.isClosed }
    }

    // MARK: - Remote refresh（FR-032: 静的URLから最新データを取得）

    /// 静的URLから最新データを取得して差し替える。データが変わったときだけ true を返す。
    ///
    /// - `force == false`: 取得間隔（15分）と失敗後の抑止（既定5分）を守る。起動直後などに裏で呼ぶ想定。
    /// - `force == true`: 間隔・抑止を無視して取得する（ユーザーが明示的に「再読み込み」した場合）。
    /// 取得は同時に1本だけ走り、実行中に呼ばれた場合はその結果に相乗りする。
    /// 失敗・不正データ・リモート未設定のときは false（ローカルデータで継続: FR-029）。
    func refreshRemote(force: Bool) async -> Bool {
        guard let remoteURL else { return false }

        let task: Task<Bool, Never> = lock.withLock {
            if let inFlightRefresh {
                _coalescedRefreshCount += 1
                return inFlightRefresh
            }
            if !force {
                if let lastRemoteFetch, Date().timeIntervalSince(lastRemoteFetch) < Self.refreshInterval {
                    return Task { false }
                }
                // 失敗直後は一定時間再取得しない（バンドル/キャッシュで即表示を維持）
                if let lastRemoteFailure, Date().timeIntervalSince(lastRemoteFailure) < failureRetryInterval {
                    return Task { false }
                }
            }
            let newTask = Task { [self] in
                let changed = await fetchRemote(from: remoteURL)
                lock.withLock { inFlightRefresh = nil }
                return changed
            }
            inFlightRefresh = newTask
            return newTask
        }
        return await task.value
    }

    private func fetchRemote(from remoteURL: URL) async -> Bool {
        do {
            let (data, response) = try await session.data(from: remoteURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                recordRemoteFailure()
                return false
            }
            let outcome = apply(data: data)
            guard outcome != .invalid else {
                recordRemoteFailure()
                return false
            }
            try? data.write(to: cacheFileURL, options: .atomic)
            lock.withLock {
                lastRemoteFetch = Date()
                lastRemoteFailure = nil
            }
            return outcome == .changed
        } catch {
            // 取得失敗はローカルデータ（キャッシュ/バンドル）で継続（FR-029）
            recordRemoteFailure()
            return false
        }
    }

    private func recordRemoteFailure() {
        lock.withLock { lastRemoteFailure = Date() }
    }

    private enum ApplyOutcome {
        /// デコード・検証に失敗（差し替えなし）
        case invalid
        /// 検証成功・内容は現在のデータと同じ
        case unchanged
        /// 検証成功・内容が変わったため差し替えた
        case changed
    }

    /// デコード・検証に成功した場合のみ差し替える（不正データで壊さない）
    @discardableResult
    private func apply(data: Data) -> ApplyOutcome {
        guard let file = try? SupabaseGateway.decoder.decode(CafeDataFile.self, from: data),
              file.formatVersion == 1 else {
            return .invalid
        }
        return lock.withLock {
            let unchanged = details == file.cafes
                && _generatedAt == file.generatedAt
                && _isSampleData == file.isSampleData
            details = file.cafes
            _generatedAt = file.generatedAt
            _isSampleData = file.isSampleData
            return unchanged ? .unchanged : .changed
        }
    }
}
