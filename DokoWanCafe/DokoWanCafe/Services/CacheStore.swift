import Foundation

/// 直近取得スナップショット（FR-029）。取得時点（鮮度）を必ず保持する。
///
/// 現在地・検索起点からの距離は保存しない（憲章 原則III: 位置由来の情報を端末内にも残さない）。
/// 店データ（`Cafe`）のみを保持し、距離は表示時に呼び出し側が計算する。
struct CachedSnapshot: Codable, Sendable {
    let fetchedAt: Date
    let cafes: [Cafe]

    init(fetchedAt: Date, cafes: [Cafe]) {
        self.fetchedAt = fetchedAt
        self.cafes = cafes
    }

    private enum CodingKeys: String, CodingKey {
        case fetchedAt, cafes
    }

    /// 旧形式（`[{cafe, distance_m}]`）のキャッシュも壊さず読み込む（距離は捨てて店データだけ採用）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        if let cafes = try? container.decode([Cafe].self, forKey: .cafes) {
            self.cafes = cafes
        } else {
            self.cafes = try container.decode([CafeWithDistance].self, forKey: .cafes).map(\.cafe)
        }
    }
}

/// 直近取得データの軽量ディスクキャッシュ（FR-029, research.md R3）。
/// オフライン時にも直近の検索結果を閲覧できるようにする。
/// フルオフライン同期は行わない（要件外）。
final class CacheStore: @unchecked Sendable {
    let fileURL: URL

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(filename: String = "nearby-cache.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("DokoWanCafe", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(filename)
    }

    func save(_ cafes: [Cafe], fetchedAt: Date = Date()) {
        let snapshot = CachedSnapshot(fetchedAt: fetchedAt, cafes: cafes)
        guard let data = try? Self.encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func load() -> CachedSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder.decode(CachedSnapshot.self, from: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
