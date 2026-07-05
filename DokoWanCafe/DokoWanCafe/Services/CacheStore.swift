import Foundation

/// 直近取得スナップショット（FR-029）。取得時点（鮮度）を必ず保持する。
struct CachedSnapshot: Codable, Sendable {
    let fetchedAt: Date
    let cafes: [CafeWithDistance]
}

/// 直近取得データの軽量ディスクキャッシュ（FR-029, research.md R3）。
/// オフライン時にも直近の検索結果を閲覧できるようにする。
/// フルオフライン同期は行わない（要件外）。
final class CacheStore: @unchecked Sendable {
    private let fileURL: URL

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

    func save(_ cafes: [CafeWithDistance], fetchedAt: Date = Date()) {
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
