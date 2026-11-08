import CryptoKit
import Foundation
import ImageIO
import UIKit

/// リンク先の OGP プレビュー（画像・タイトル）取得サービス（写真・雰囲気機能）。
/// `URLSession` で端末が直接リンク先へアクセスして取得するのみで、画像の転載・再ホストは行わない
/// （憲章 原則III: プライバシー — 送るのはページと画像の URL だけ。位置情報等は付けず、ユーザーがリンクを開くのと同種の直接アクセスのみ）。
/// 以前の `LPMetadataProvider` は写真1枚ごとに WebKit のプロセスを起動して一覧のスクロールが重かったため、
/// HTML の先頭だけ読んで `og:image` を取り出し、画像は ImageIO で縮小デコードする方式に替えた。
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
        /// 画像なしの結果（ページは取れたが og:image が無い等）のディスクでの鮮度（1日）。
        /// 14日残すと、サイト側が直ったあとも利用者の端末で回復しないため短くする
        static let noImageTTLSeconds: TimeInterval = 24 * 60 * 60
        /// 同時ネットワーク取得数の上限
        static let maxConcurrentFetches = 3
        /// ページの HTML を読む上限（先頭からこのバイト数まで。OGP は `<head>` にあるので全部は読まない）
        static let maxHTMLBytes = 512 * 1024
        /// 画像をダウンロードする上限
        static let maxImageBytes = 5 * 1024 * 1024
        /// 1リクエストのタイムアウト（秒）
        static let requestTimeout: TimeInterval = 10
        /// 通信時の User-Agent。デスクトップ版 Safari を名乗る。
        /// iPhone の Safari を名乗ると、食べログなどがスマホ版（og:image の無いページ）へ転送するため、それを避ける。
        static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

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

        /// ディスクキャッシュの鮮度の長さ。画像ありは14日、画像なしは1日
        static func ttl(hasImage: Bool) -> TimeInterval {
            hasImage ? ttlSeconds : noImageTTLSeconds
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
    private let session: URLSession
    private let downloader: BoundedDownloader

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

    /// - Parameters:
    ///   - cacheDirectory: ディスクキャッシュの置き場（既定は Caches/LinkPreviews。テストで差し替える）
    ///   - configuration: 通信の設定（既定は Cookie を残さない ephemeral。テストで URLProtocol を差し込むために差し替える）
    init(fileManager: FileManager = .default, cacheDirectory: URL? = nil, configuration: URLSessionConfiguration? = nil) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = cacheDirectory ?? base.appendingPathComponent("LinkPreviews", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.cacheDirectory = directory
        let downloader = BoundedDownloader()
        self.downloader = downloader
        self.session = URLSession(
            configuration: configuration ?? Self.makeConfiguration(), delegate: downloader, delegateQueue: nil
        )
        self.memoryCache.totalCostLimit = Self.memoryCacheCostLimit
    }

    deinit {
        // セッションはデリゲートを強参照するので、使い終わったら解放する
        session.finishTasksAndInvalidate()
    }

    /// Cookie・URL キャッシュを残さない ephemeral の設定（タイムアウトは約10秒）
    static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = PureLogic.requestTimeout
        configuration.timeoutIntervalForResource = PureLogic.requestTimeout * 3
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }

    /// 画像のメモリキャッシュcost概算（ピクセル数×4バイト = RGBA1ピクセルあたりのバイト数）
    private static func memoryCost(for image: UIImage?) -> Int {
        guard let cgImage = image?.cgImage else { return 0 }
        return cgImage.width * cgImage.height * 4
    }

    /// URLのOGPプレビューを取得する（メモリ→ディスク→ネットワークの順）。
    /// 取得失敗・URL不正の場合は nil（呼び出し側は次の表示手段へフォールバックする）。
    func preview(for url: URL) async -> Preview? {
        await preview(for: url, allowNetwork: true)
    }

    /// 取得の方針を選べる版。`allowNetwork: false` のときはメモリ・ディスクにあるものだけを返し、通信しない
    /// （一覧のスクロール中に写真の通信を走らせないため。カード・詳細で取得した写真は次から一覧にも出る）。
    func preview(for url: URL, allowNetwork: Bool) async -> Preview? {
        let key = PureLogic.cacheKey(for: url.absoluteString)

        if let cached = memoryCache.object(forKey: key as NSString) {
            return Preview(image: cached.image, title: cached.title)
        }
        if allowNetwork, let existing = inFlightTasks[key] {
            return await existing.value
        }
        if allowNetwork, failedKeys.contains(key) {
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
        guard allowNetwork else { return nil }

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

        guard let page = await fetchPage(url: url) else {
            // 取得失敗は同一起動内では再試行しない（negative cache）
            failedKeys.insert(key)
            return nil
        }
        let metadata = OGMetadataParser.parse(html: page.html, baseURL: page.finalURL)

        var image: UIImage?
        if let imageURL = metadata.imageURL {
            image = await fetchImage(url: OGMetadataParser.httpsUpgraded(imageURL))
            if image == nil {
                // 画像の取得・デコードに失敗。一時的な失敗かもしれないのでディスクには残さず、同一起動内だけ再試行しない
                failedKeys.insert(key)
                return Preview(image: nil, title: metadata.title)
            }
        }

        saveToDisk(key: key, title: metadata.title, image: image)
        memoryCache.setObject(
            CachedPreviewBox(image: image, title: metadata.title),
            forKey: key as NSString,
            cost: Self.memoryCost(for: image)
        )
        return Preview(image: image, title: metadata.title)
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

    // MARK: - 通信（URLSession）

    private struct Page {
        let html: String
        /// リダイレクト後の最終 URL（相対 URL の解決に使う）
        let finalURL: URL
    }

    /// 送るのはリクエストする URL だけ（位置情報などは付けない, 原則III）。Cookie も送らない。
    private func makeRequest(url: URL, accept: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: PureLogic.requestTimeout)
        request.httpShouldHandleCookies = false
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(PureLogic.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("ja-JP,ja;q=0.9", forHTTPHeaderField: "Accept-Language")
        return request
    }

    /// ページの HTML を先頭の `maxHTMLBytes` まで読む（上限に達したら通信を止める）。
    /// `http://` のページは ATS で読めないので `https://` に直して取る。失敗は nil
    private func fetchPage(url: URL) async -> Page? {
        let target = OGMetadataParser.httpsUpgraded(url)
        let request = makeRequest(url: target, accept: "text/html,application/xhtml+xml;q=0.9,*/*;q=0.5")
        guard let output = await downloader.download(request, session: session, limit: PureLogic.maxHTMLBytes, overLimit: .truncate),
              !output.data.isEmpty
        else { return nil }
        let html = OGMetadataParser.decode(data: output.data, headerEncodingName: output.response.textEncodingName)
        return Page(html: html, finalURL: output.response.url ?? target)
    }

    /// 画像を `maxImageBytes` を上限にダウンロードし、最大辺 `maxImageDimension` に縮小してデコードする。
    /// 上限を超える画像は通信を止めて失敗にする。失敗は nil
    private func fetchImage(url: URL) async -> UIImage? {
        let request = makeRequest(url: url, accept: "image/*,*/*;q=0.5")
        guard let output = await downloader.download(request, session: session, limit: PureLogic.maxImageBytes, overLimit: .fail)
        else { return nil }
        return Self.downsampledImage(from: output.data, maxDimension: PureLogic.maxImageDimension)
    }

    /// 上限つきのダウンロード。まとまった単位（`didReceive data`）で受け取り、上限に達したら通信を止める。
    /// 非2xx・通信エラー・（`.fail` のとき）上限超えは nil。Swift のタスクがキャンセルされたら通信も止める。
    private final class BoundedDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        enum OverLimit {
            /// 上限までを返す（HTML の先頭だけ読む）
            case truncate
            /// 失敗にする（途中までの画像は使えない）
            case fail
        }

        struct Output {
            let response: HTTPURLResponse
            let data: Data
        }

        private final class State {
            let limit: Int
            let overLimit: OverLimit
            var data = Data()
            var response: HTTPURLResponse?
            var continuation: CheckedContinuation<Output?, Never>?
            init(limit: Int, overLimit: OverLimit, continuation: CheckedContinuation<Output?, Never>) {
                self.limit = limit
                self.overLimit = overLimit
                self.continuation = continuation
            }
        }

        private let lock = NSLock()
        private var states: [Int: State] = [:]

        func download(_ request: URLRequest, session: URLSession, limit: Int, overLimit: OverLimit) async -> Output? {
            let task = session.dataTask(with: request)
            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    lock.lock()
                    states[task.taskIdentifier] = State(limit: limit, overLimit: overLimit, continuation: continuation)
                    lock.unlock()
                    if Task.isCancelled {
                        finish(task, output: nil)
                    } else {
                        task.resume()
                    }
                }
            } onCancel: {
                task.cancel()
            }
        }

        /// 結果を1回だけ返し、通信を止める
        private func finish(_ task: URLSessionTask, output: Output?) {
            lock.lock()
            let state = states.removeValue(forKey: task.taskIdentifier)
            lock.unlock()
            guard let continuation = state?.continuation else { return }
            state?.continuation = nil
            task.cancel()
            continuation.resume(returning: output)
        }

        private func state(for task: URLSessionTask) -> State? {
            lock.lock(); defer { lock.unlock() }
            return states[task.taskIdentifier]
        }

        func urlSession(
            _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
            completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
        ) {
            guard let state = state(for: dataTask) else { completionHandler(.cancel); return }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                finish(dataTask, output: nil)
                completionHandler(.cancel)
                return
            }
            // 宣言された大きさがすでに上限超えなら、読み始めずに止める
            if state.overLimit == .fail, http.expectedContentLength > Int64(state.limit) {
                finish(dataTask, output: nil)
                completionHandler(.cancel)
                return
            }
            state.response = http
            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let state = state(for: dataTask) else { return }
            state.data.append(data)
            guard state.data.count >= state.limit else { return }
            switch state.overLimit {
            case .truncate:
                if let response = state.response {
                    finish(dataTask, output: Output(response: response, data: Data(state.data.prefix(state.limit))))
                } else {
                    finish(dataTask, output: nil)
                }
            case .fail:
                // ちょうど上限は許し、超えたら失敗
                if state.data.count > state.limit { finish(dataTask, output: nil) }
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            guard let state = state(for: task) else { return }
            if error == nil, let response = state.response {
                finish(task, output: Output(response: response, data: state.data))
            } else {
                finish(task, output: nil)
            }
        }
    }

    // MARK: - 画像の縮小デコード

    /// ImageIO で最大辺 `maxDimension` に縮小してデコードする（巨大な画像を丸ごとデコードしない）。
    /// 元が上限以下なら拡大しない。向き（EXIF）は反映する。デコードできなければ nil。
    static func downsampledImage(from data: Data, maxDimension: CGFloat = PureLogic.maxImageDimension) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0
        else { return nil }
        // 小さい画像は拡大しない（縮小後サイズの長辺を上限にする）
        let target = PureLogic.resizedSize(originalSize: CGSize(width: width, height: height), maxDimension: maxDimension)
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(target.width, target.height),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
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
              PureLogic.isFresh(fetchedAt: meta.fetchedAt, ttl: PureLogic.ttl(hasImage: meta.hasImage))
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
