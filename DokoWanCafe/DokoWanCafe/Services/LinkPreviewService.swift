import CryptoKit
import Foundation
import LinkPresentation
import UIKit

/// リンク先の OGP プレビュー（画像・タイトル）取得サービス（写真・雰囲気機能）。
/// `LPMetadataProvider` で端末が直接リンク先へアクセスして取得するのみで、画像の転載・再ホストは行わない
/// （憲章 原則III: プライバシー — 位置情報等は送らず、ユーザーがリンクを開くのと同種の直接アクセスのみ）。
actor LinkPreviewService {
    static let shared = LinkPreviewService()

    /// 取得結果（画像は端末内で縮小済み）
    struct Preview: Sendable {
        let image: UIImage?
        let title: String?
    }

    /// キャッシュキー生成・TTL判定・画像縮小サイズ計算などの純ロジック（ネットワーク非依存・XCTest対象）
    enum PureLogic {
        /// ディスクキャッシュのTTL（14日）
        static let ttlSeconds: TimeInterval = 14 * 24 * 60 * 60
        /// 保存する画像の最大辺（px）
        static let maxImageDimension: CGFloat = 800
        /// 同時ネットワーク取得数の上限
        static let maxConcurrentFetches = 3

        /// URL文字列からディスクキャッシュのファイル名に使う一意なキー（SHA256の16進文字列）を生成する
        static func cacheKey(for urlString: String) -> String {
            let digest = SHA256.hash(data: Data(urlString.utf8))
            return digest.map { String(format: "%02x", $0) }.joined()
        }

        /// `fetchedAt` が TTL 内（新鮮）かどうかを判定する。ファイルの mtime API は使わず、
        /// JSON内に保存した `fetchedAt` のみで判定する（required-reason API 追加回避）。
        static func isFresh(fetchedAt: Date, now: Date = Date(), ttl: TimeInterval = ttlSeconds) -> Bool {
            now.timeIntervalSince(fetchedAt) < ttl
        }

        /// 元画像サイズから、最大辺 `maxDimension` に収まる縮小後サイズを計算する。
        /// アスペクト比は維持し、既に上限以下なら拡大はしない（等倍のまま返す）。
        static func resizedSize(originalSize: CGSize, maxDimension: CGFloat = maxImageDimension) -> CGSize {
            let longestSide = max(originalSize.width, originalSize.height)
            guard longestSide > maxDimension, longestSide > 0 else { return originalSize }
            let scale = maxDimension / longestSide
            return CGSize(
                width: (originalSize.width * scale).rounded(),
                height: (originalSize.height * scale).rounded()
            )
        }
    }

    /// メモリキャッシュの値（NSCacheはクラス値のみ保持できるためのラッパー）
    private final class CachedPreviewBox {
        let image: UIImage?
        let title: String?
        init(image: UIImage?, title: String?) {
            self.image = image
            self.title = title
        }
    }

    /// ディスク保存用メタデータ（画像本体はJPEGとして別ファイルに保存）
    private struct CachedMeta: Codable {
        let title: String?
        let fetchedAt: Date
        let hasImage: Bool
    }

    private let memoryCache = NSCache<NSString, CachedPreviewBox>()
    private let fileManager: FileManager
    private let cacheDirectory: URL

    /// 同時ネットワーク取得数の制御
    private var activeFetchCount = 0
    private var waitQueue: [CheckedContinuation<Void, Never>] = []
    /// 同一URLの重複要求の合流先
    private var inFlightTasks: [String: Task<Preview?, Never>] = [:]
    /// 取得失敗URLの同一起動内 negative cache（再試行しない）
    private var failedKeys: Set<String> = []

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

    /// メモリキャッシュの上限（目安50MB。cost はピクセル数×4バイトの概算で設定する）
    private static let memoryCacheCostLimit = 50 * 1024 * 1024

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("LinkPreviews", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.cacheDirectory = directory
        self.memoryCache.totalCostLimit = Self.memoryCacheCostLimit
    }

    /// 画像のメモリキャッシュcost概算（ピクセル数×4バイト = RGBA1ピクセルあたりのバイト数）
    private static func memoryCost(for image: UIImage?) -> Int {
        guard let cgImage = image?.cgImage else { return 0 }
        return cgImage.width * cgImage.height * 4
    }

    /// URLのOGPプレビューを取得する（メモリ→ディスク→ネットワークの順）。
    /// 取得失敗・URL不正の場合は nil（呼び出し側は次の表示手段へフォールバックする）。
    func preview(for url: URL) async -> Preview? {
        let key = PureLogic.cacheKey(for: url.absoluteString)

        if let cached = memoryCache.object(forKey: key as NSString) {
            return Preview(image: cached.image, title: cached.title)
        }
        if let existing = inFlightTasks[key] {
            return await existing.value
        }
        if failedKeys.contains(key) {
            return nil
        }
        if let disked = loadFromDisk(key: key) {
            memoryCache.setObject(
                CachedPreviewBox(image: disked.image, title: disked.title),
                forKey: key as NSString,
                cost: Self.memoryCost(for: disked.image)
            )
            return disked
        }

        let task = Task<Preview?, Never> { [weak self] in
            await self?.fetchAndCache(url: url, key: key)
        }
        inFlightTasks[key] = task
        let result = await task.value
        inFlightTasks[key] = nil
        return result
    }

    // MARK: - ネットワーク取得（最大3並列）

    private func fetchAndCache(url: URL, key: String) async -> Preview? {
        await acquireSlot()
        defer { releaseSlot() }

        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            let title = metadata.title
            let rawImage = await Self.loadImage(from: metadata.imageProvider ?? metadata.iconProvider)
            let resized = rawImage.map { Self.resizedImage($0, maxDimension: PureLogic.maxImageDimension) }

            saveToDisk(key: key, title: title, image: resized)
            memoryCache.setObject(
                CachedPreviewBox(image: resized, title: title),
                forKey: key as NSString,
                cost: Self.memoryCost(for: resized)
            )
            return Preview(image: resized, title: title)
        } catch {
            // 取得失敗は同一起動内では再試行しない（negative cache）
            failedKeys.insert(key)
            return nil
        }
    }

    private func acquireSlot() async {
        if activeFetchCount < PureLogic.maxConcurrentFetches {
            activeFetchCount += 1
            return
        }
        await withCheckedContinuation { continuation in
            waitQueue.append(continuation)
        }
    }

    private func releaseSlot() {
        if waitQueue.isEmpty {
            activeFetchCount -= 1
            return
        }
        let next = waitQueue.removeFirst()
        next.resume()
    }

    // MARK: - 画像読み込み・縮小

    private static func loadImage(from itemProvider: NSItemProvider?) async -> UIImage? {
        guard let itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    /// `newSize` は px 単位（= 保存後のピクセルサイズ）として扱うため、レンダラーの scale は 1 に固定する。
    /// 既定（画面スケール）のままだと Retina 端末では `newSize ×画面スケール` のピクセル数で保存されてしまい、
    /// 「最大辺800px」の意図に反してしまう。
    private static func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let newSize = PureLogic.resizedSize(originalSize: image.size, maxDimension: maxDimension)
        guard newSize != image.size, newSize.width > 0, newSize.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - ディスクキャッシュ

    private func metaFileURL(key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).json")
    }

    private func imageFileURL(key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).jpg")
    }

    private func loadFromDisk(key: String) -> Preview? {
        guard let metaData = try? Data(contentsOf: metaFileURL(key: key)),
              let meta = try? Self.decoder.decode(CachedMeta.self, from: metaData),
              PureLogic.isFresh(fetchedAt: meta.fetchedAt)
        else { return nil }

        var image: UIImage?
        if meta.hasImage, let imageData = try? Data(contentsOf: imageFileURL(key: key)) {
            image = UIImage(data: imageData)
        }
        return Preview(image: image, title: meta.title)
    }

    private func saveToDisk(key: String, title: String?, image: UIImage?) {
        let meta = CachedMeta(title: title, fetchedAt: Date(), hasImage: image != nil)
        if let metaData = try? Self.encoder.encode(meta) {
            try? metaData.write(to: metaFileURL(key: key), options: .atomic)
        }
        if let image, let jpegData = image.jpegData(compressionQuality: 0.8) {
            try? jpegData.write(to: imageFileURL(key: key), options: .atomic)
        } else {
            try? fileManager.removeItem(at: imageFileURL(key: key))
        }
    }
}
