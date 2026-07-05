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
final class StaticCafeRepository: CafeRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var details: [CafeDetail] = []
    private var _generatedAt: Date?
    private var _isSampleData = false
    private var lastRemoteFetch: Date?

    private let remoteURL: URL?
    private let session: URLSession
    private let cacheFileURL: URL

    /// リモート再取得の最小間隔
    private static let refreshInterval: TimeInterval = 15 * 60

    var generatedAt: Date? {
        lock.lock(); defer { lock.unlock() }
        return _generatedAt
    }

    var isSampleData: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isSampleData
    }

    init(remoteURL: URL?, bundle: Bundle = .main, session: URLSession = .shared) {
        self.remoteURL = remoteURL
        self.session = session

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("DokoWanCafe", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.cacheFileURL = directory.appendingPathComponent("cafes-remote.json")

        // 1) 直近のリモート取得キャッシュ → 2) バンドル版 の順で初期ロード
        if let cached = try? Data(contentsOf: cacheFileURL), apply(data: cached) {
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
        await refreshFromRemoteIfNeeded()

        let snapshot: [CafeDetail]
        lock.lock()
        snapshot = details
        lock.unlock()

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
        lock.lock()
        let found = details.first { $0.cafe.id == id }
        lock.unlock()
        guard let found else { throw SupabaseError.emptyResponse }
        return found
    }

    // MARK: - Remote refresh（FR-032: 静的URLから最新データを取得）

    private func refreshFromRemoteIfNeeded() async {
        guard let remoteURL else { return }
        lock.lock()
        let last = lastRemoteFetch
        lock.unlock()
        if let last, Date().timeIntervalSince(last) < Self.refreshInterval { return }

        do {
            let (data, response) = try await session.data(from: remoteURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return
            }
            if apply(data: data) {
                try? data.write(to: cacheFileURL, options: .atomic)
                lock.lock()
                lastRemoteFetch = Date()
                lock.unlock()
            }
        } catch {
            // 取得失敗はローカルデータ（キャッシュ/バンドル）で継続（FR-029）
        }
    }

    /// デコード・検証に成功した場合のみ差し替える（不正データで壊さない）
    @discardableResult
    private func apply(data: Data) -> Bool {
        guard let file = try? SupabaseGateway.decoder.decode(CafeDataFile.self, from: data),
              file.formatVersion == 1 else {
            return false
        }
        lock.lock()
        details = file.cafes
        _generatedAt = file.generatedAt
        _isSampleData = file.isSampleData
        lock.unlock()
        return true
    }
}
