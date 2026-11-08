import UIKit
import XCTest
@testable import DokoWanCafe

/// `LinkPreviewService` の取得（URLSession 版）のテスト。通信は URLProtocol のスタブで差し替え、実ネットワークには出ない。
final class LinkPreviewFetchTests: XCTestCase {
    // MARK: - スタブ

    private struct StubResponse {
        var status = 200
        var headers: [String: String] = [:]
        var body = Data()
        /// true のとき Content-Length を付けない（サイズを宣言しないサーバーの再現）
        var omitsContentLength = false
    }

    /// 通信を差し替える URLProtocol。URL（文字列）ごとの応答を返し、届いたリクエストを記録する。
    private final class StubURLProtocol: URLProtocol {
        static let lock = NSLock()
        nonisolated(unsafe) static var responses: [String: StubResponse] = [:]
        nonisolated(unsafe) static var requests: [URLRequest] = []

        static func reset() {
            lock.lock(); defer { lock.unlock() }
            responses = [:]
            requests = []
        }

        static var requestedURLs: [String] {
            lock.lock(); defer { lock.unlock() }
            return requests.compactMap { $0.url?.absoluteString }
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.lock.lock()
            Self.requests.append(request)
            let stub = request.url.flatMap { Self.responses[$0.absoluteString] }
            Self.lock.unlock()

            guard let url = request.url, let stub else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
                return
            }
            var headers = stub.headers
            if !stub.omitsContentLength { headers["Content-Length"] = String(stub.body.count) }
            let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private var cacheDirectory: URL!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinkPreviewFetchTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func makeService() -> LinkPreviewService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return LinkPreviewService(cacheDirectory: cacheDirectory, configuration: configuration)
    }

    private func stub(_ url: String, _ response: StubResponse) {
        StubURLProtocol.lock.lock()
        StubURLProtocol.responses[url] = response
        StubURLProtocol.lock.unlock()
    }

    private func stubHTML(_ url: String, _ html: String) {
        stub(url, StubResponse(headers: ["Content-Type": "text/html; charset=utf-8"], body: Data(html.utf8)))
    }

    private func stubImage(_ url: String, width: Int, height: Int) {
        stub(url, StubResponse(headers: ["Content-Type": "image/png"], body: Self.pngData(width: width, height: height)))
    }

    private static func pngData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.pngData { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private let pageURL = URL(string: "https://shop.example.com/cafe/")!

    // MARK: - 取得

    func test_ページのogImageを取って最大辺800pxに縮小しタイトルも返す() async throws {
        stubHTML("https://shop.example.com/cafe/", """
        <html><head><title>ページ</title>
        <meta property="og:title" content="わんこカフェ">
        <meta property="og:image" content="/img/hero.png"></head></html>
        """)
        stubImage("https://shop.example.com/img/hero.png", width: 1600, height: 1000)

        let fetched = await makeService().preview(for: pageURL)
        let preview = try XCTUnwrap(fetched)
        let cgImage = try XCTUnwrap(preview.image?.cgImage)
        XCTAssertEqual(cgImage.width, 800)
        XCTAssertEqual(cgImage.height, 500)
        XCTAssertEqual(preview.title, "わんこカフェ")
    }

    func test_小さい画像は拡大しない() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/s.png">"#)
        stubImage("https://shop.example.com/s.png", width: 320, height: 200)

        let fetched = await makeService().preview(for: pageURL)
        let preview = try XCTUnwrap(fetched)
        let cgImage = try XCTUnwrap(preview.image?.cgImage)
        XCTAssertEqual(cgImage.width, 320)
        XCTAssertEqual(cgImage.height, 200)
    }

    func test_httpの画像URLはhttpsに直して取りに行く() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="http://cdn.example.com/a.png">"#)
        stubImage("https://cdn.example.com/a.png", width: 400, height: 300)

        let fetched = await makeService().preview(for: pageURL)
        let preview = try XCTUnwrap(fetched)
        XCTAssertNotNil(preview.image)
        XCTAssertEqual(StubURLProtocol.requestedURLs, ["https://shop.example.com/cafe/", "https://cdn.example.com/a.png"])
    }

    func test_送るのはURLだけでCookieや位置情報は付けない() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/a.png">"#)
        stubImage("https://shop.example.com/a.png", width: 400, height: 300)

        _ = await makeService().preview(for: pageURL)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        for request in StubURLProtocol.requests {
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.httpBody)
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertNil(request.url?.query)
        }
    }

    func test_画像のないページはタイトルだけ返す() async throws {
        stubHTML("https://shop.example.com/cafe/", "<html><head><title>画像なし</title></head></html>")

        let fetched = await makeService().preview(for: pageURL)
        let preview = try XCTUnwrap(fetched)
        XCTAssertNil(preview.image)
        XCTAssertEqual(preview.title, "画像なし")
        // サイトのアイコンは取りに行かない
        XCTAssertEqual(StubURLProtocol.requestedURLs, ["https://shop.example.com/cafe/"])
    }

    func test_ページが取れなければnilで同じURLは再試行しない() async {
        stub("https://shop.example.com/cafe/", StubResponse(status: 404))
        let service = makeService()

        let first = await service.preview(for: pageURL)
        let second = await service.preview(for: pageURL)
        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(StubURLProtocol.requestedURLs.count, 1)
    }

    func test_通信エラーならnil() async {
        // スタブ未登録のURLは通信エラーになる
        let preview = await makeService().preview(for: pageURL)
        XCTAssertNil(preview)
    }

    func test_画像が5MBを超えるときは取らず失敗扱いでディスクにも残さない() async throws {
        stubHTML("https://shop.example.com/cafe/", """
        <meta property="og:title" content="大きい">
        <meta property="og:image" content="https://shop.example.com/huge.png">
        """)
        stub("https://shop.example.com/huge.png", StubResponse(headers: ["Content-Type": "image/png"], body: Data(count: 5 * 1024 * 1024 + 1)))
        let service = makeService()

        let fetched = await service.preview(for: pageURL)
        let preview = try XCTUnwrap(fetched)
        XCTAssertNil(preview.image)
        XCTAssertEqual(preview.title, "大きい")
        // 一時的な失敗かもしれないので、ディスクには残さない（新しいインスタンスは通信を許せば取り直す）
        let reopened = makeService()
        let offline = await reopened.preview(for: pageURL, allowNetwork: false)
        XCTAssertNil(offline)
    }

    func test_サイズを宣言しない画像も5MBを超えたら失敗扱い() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/huge.png">"#)
        stub("https://shop.example.com/huge.png", StubResponse(body: Data(count: 5 * 1024 * 1024 + 1), omitsContentLength: true))

        let fetched = await makeService().preview(for: pageURL)
        let preview = try XCTUnwrap(fetched)
        XCTAssertNil(preview.image)
    }

    func test_httpのページURLもhttpsに直して取りに行く() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/a.png">"#)
        stubImage("https://shop.example.com/a.png", width: 400, height: 300)

        let fetched = await makeService().preview(for: URL(string: "http://shop.example.com/cafe/")!)
        XCTAssertNotNil(fetched?.image)
        XCTAssertEqual(StubURLProtocol.requestedURLs.first, "https://shop.example.com/cafe/")
    }

    func test_デスクトップ版Safariを名乗りスマホ版へ転送されないようにする() async {
        stubHTML("https://shop.example.com/cafe/", "<title>x</title>")
        _ = await makeService().preview(for: pageURL)
        let userAgent = StubURLProtocol.requests.first?.value(forHTTPHeaderField: "User-Agent") ?? ""
        XCTAssertTrue(userAgent.contains("Macintosh"))
        XCTAssertFalse(userAgent.contains("iPhone"))
        XCTAssertFalse(userAgent.contains("Mobile"))
    }

    func test_画像なしの結果は1日たつとディスクから読まない() async throws {
        stubHTML("https://shop.example.com/cafe/", "<title>画像なし</title>")
        _ = await makeService().preview(for: pageURL)

        // 作ったばかり（新鮮）なら次の起動のディスクから返る
        let fresh = await makeService().preview(for: pageURL, allowNetwork: false)
        XCTAssertEqual(fresh?.title, "画像なし")

        // メタの fetchedAt を2日前に書き換えると、画像なしは古いので読まない
        let key = LinkPreviewService.PureLogic.cacheKey(for: pageURL.absoluteString)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).json")
        let old = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-2 * 24 * 60 * 60))
        try Data(#"{"title":"画像なし","hasImage":false,"fetchedAt":"\#(old)"}"#.utf8).write(to: metaURL)
        let stale = await makeService().preview(for: pageURL, allowNetwork: false)
        XCTAssertNil(stale)
    }

    func test_画像ありの結果は2日たってもディスクから読める() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/a.png">"#)
        stubImage("https://shop.example.com/a.png", width: 400, height: 300)
        _ = await makeService().preview(for: pageURL)

        let key = LinkPreviewService.PureLogic.cacheKey(for: pageURL.absoluteString)
        let metaURL = cacheDirectory.appendingPathComponent("\(key).json")
        let old = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-2 * 24 * 60 * 60))
        try Data(#"{"hasImage":true,"fetchedAt":"\#(old)"}"#.utf8).write(to: metaURL)
        let cached = await makeService().preview(for: pageURL, allowNetwork: false)
        XCTAssertNotNil(cached?.image)
    }

    func test_画像として読めないデータは失敗扱い() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/bad.png">"#)
        stub("https://shop.example.com/bad.png", StubResponse(body: Data("not an image".utf8)))

        let fetched = await makeService().preview(for: pageURL)
        let preview = try XCTUnwrap(fetched)
        XCTAssertNil(preview.image)
    }

    func test_HTMLは先頭の512KBまでしか読まない() async throws {
        let filler = String(repeating: "x", count: LinkPreviewService.PureLogic.maxHTMLBytes + 1000)
        stubHTML("https://shop.example.com/cafe/", filler + #"<meta property="og:image" content="https://shop.example.com/late.png">"#)
        stubImage("https://shop.example.com/late.png", width: 400, height: 300)

        let fetched = await makeService().preview(for: pageURL)
        let preview = try XCTUnwrap(fetched)
        XCTAssertNil(preview.image)
        XCTAssertEqual(StubURLProtocol.requestedURLs, ["https://shop.example.com/cafe/"])
    }

    func test_同じURLの同時の要求は1回の取得にまとまる() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/a.png">"#)
        stubImage("https://shop.example.com/a.png", width: 400, height: 300)
        let service = makeService()
        let url = pageURL

        async let first = service.preview(for: url)
        async let second = service.preview(for: url)
        let results = await [first, second]

        XCTAssertNotNil(results[0]?.image)
        XCTAssertNotNil(results[1]?.image)
        XCTAssertEqual(StubURLProtocol.requestedURLs.filter { $0 == "https://shop.example.com/cafe/" }.count, 1)
    }

    // MARK: - 通信しない方針（allowNetwork: false）

    func test_allowNetworkがfalseでキャッシュがなければ通信せずnil() async {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/a.png">"#)
        stubImage("https://shop.example.com/a.png", width: 400, height: 300)

        let preview = await makeService().preview(for: pageURL, allowNetwork: false)
        XCTAssertNil(preview)
        XCTAssertTrue(StubURLProtocol.requestedURLs.isEmpty)
    }

    func test_取得済みの写真はallowNetworkがfalseでもメモリから返る() async throws {
        stubHTML("https://shop.example.com/cafe/", #"<meta property="og:image" content="https://shop.example.com/a.png">"#)
        stubImage("https://shop.example.com/a.png", width: 400, height: 300)
        let service = makeService()
        _ = await service.preview(for: pageURL)
        let requestCount = StubURLProtocol.requestedURLs.count

        let cached = await service.preview(for: pageURL, allowNetwork: false)
        XCTAssertNotNil(cached?.image)
        XCTAssertEqual(StubURLProtocol.requestedURLs.count, requestCount)
    }

    func test_取得済みの写真は次の起動のディスクキャッシュからallowNetworkがfalseでも返る() async throws {
        stubHTML("https://shop.example.com/cafe/", """
        <meta property="og:title" content="わんこカフェ">
        <meta property="og:image" content="https://shop.example.com/a.png">
        """)
        stubImage("https://shop.example.com/a.png", width: 400, height: 300)
        _ = await makeService().preview(for: pageURL)
        let requestCount = StubURLProtocol.requestedURLs.count

        let nextLaunch = makeService()
        let cached = await nextLaunch.preview(for: pageURL, allowNetwork: false)
        XCTAssertNotNil(cached?.image)
        XCTAssertEqual(cached?.title, "わんこカフェ")
        XCTAssertEqual(StubURLProtocol.requestedURLs.count, requestCount)
    }

    // MARK: - 縮小デコード

    func test_downsampledImageは最大辺を800pxに縮める() throws {
        let image = try XCTUnwrap(LinkPreviewService.downsampledImage(from: Self.pngData(width: 2000, height: 3000)))
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(max(cgImage.width, cgImage.height), 800)
        XCTAssertEqual(cgImage.width, 533, accuracy: 1)
    }

    func test_downsampledImageは上限以下なら拡大しない() throws {
        let image = try XCTUnwrap(LinkPreviewService.downsampledImage(from: Self.pngData(width: 300, height: 160)))
        XCTAssertEqual(image.cgImage?.width, 300)
        XCTAssertEqual(image.cgImage?.height, 160)
    }

    func test_downsampledImageは画像でないデータならnil() {
        XCTAssertNil(LinkPreviewService.downsampledImage(from: Data("hello".utf8)))
        XCTAssertNil(LinkPreviewService.downsampledImage(from: Data()))
    }
}
