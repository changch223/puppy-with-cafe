import XCTest
@testable import DokoWanCafe

/// 写真プレビュー機能: `PhotoSourceResolver` のユニットテスト（純ロジック, 憲章 原則IV）
final class PhotoSourceResolverTests: XCTestCase {
    private func makeCafe(links: [CafeLink]?) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: "テストカフェ",
            latitude: 35.68, longitude: 139.76,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo",
            links: links
        )
    }

    // MARK: - previewSourceURL: 優先順

    func test_website_tabelog_instagramが揃っている場合はwebsiteが優先される() {
        let cafe = makeCafe(links: [
            CafeLink(type: .tabelog, url: "https://tabelog.com/tokyo/A0001/A000101/12345678/"),
            CafeLink(type: .instagram, url: "https://www.instagram.com/testcafe/"),
            CafeLink(type: .website, url: "https://testcafe.example.com"),
        ])
        XCTAssertEqual(PhotoSourceResolver.previewSourceURL(for: cafe), URL(string: "https://testcafe.example.com"))
    }

    func test_websiteが無い場合はtabelogにフォールバックする() {
        let cafe = makeCafe(links: [
            CafeLink(type: .instagram, url: "https://www.instagram.com/testcafe/"),
            CafeLink(type: .tabelog, url: "https://tabelog.com/tokyo/A0001/A000101/12345678/"),
        ])
        XCTAssertEqual(
            PhotoSourceResolver.previewSourceURL(for: cafe),
            URL(string: "https://tabelog.com/tokyo/A0001/A000101/12345678/")
        )
    }

    func test_instagramのみの場合はinstagramが使われる() {
        let cafe = makeCafe(links: [
            CafeLink(type: .instagram, url: "https://www.instagram.com/testcafe/"),
        ])
        XCTAssertEqual(
            PhotoSourceResolver.previewSourceURL(for: cafe),
            URL(string: "https://www.instagram.com/testcafe/")
        )
    }

    func test_linksがnilの場合はnil() {
        XCTAssertNil(PhotoSourceResolver.previewSourceURL(for: makeCafe(links: nil)))
    }

    func test_linksが空配列の場合もnil() {
        XCTAssertNil(PhotoSourceResolver.previewSourceURL(for: makeCafe(links: [])))
    }

    func test_website以外_website_tabelog_x_googleMapなどの候補外リンクのみではnil() {
        let cafe = makeCafe(links: [
            CafeLink(type: .x, url: "https://x.com/testcafe"),
            CafeLink(type: .googleMap, url: "https://maps.google.com/?q=testcafe"),
            CafeLink(type: .other, url: "https://example.com/other"),
        ])
        XCTAssertNil(PhotoSourceResolver.previewSourceURL(for: cafe))
    }

    // MARK: - mapsPhotoSearchURL

    func test_日本語店名と住所がパーセントエンコードされる() throws {
        let url = PhotoSourceResolver.mapsPhotoSearchURL(name: "わんこカフェ", address: "東京都渋谷区1-2-3")
        let urlString = try XCTUnwrap(url?.absoluteString)
        XCTAssertTrue(urlString.hasPrefix("https://www.google.com/maps/search/?api=1&query="))
        // 生の日本語文字・スペースは含まれず、パーセントエンコードされている
        XCTAssertFalse(urlString.contains("わんこカフェ"))
        XCTAssertFalse(urlString.contains(" "))
        // デコードすると元の「店名 住所」に戻る
        let query = try XCTUnwrap(URLComponents(string: urlString)?.queryItems?.first { $0.name == "query" }?.value)
        XCTAssertEqual(query, "わんこカフェ 東京都渋谷区1-2-3")
    }

    func test_住所がnilの場合は店名のみのクエリになる() throws {
        let url = PhotoSourceResolver.mapsPhotoSearchURL(name: "わんこカフェ", address: nil)
        let urlString = try XCTUnwrap(url?.absoluteString)
        let query = try XCTUnwrap(URLComponents(string: urlString)?.queryItems?.first { $0.name == "query" }?.value)
        XCTAssertEqual(query, "わんこカフェ")
    }

    // MARK: - instagramEmbedHTML

    func test_p形式の投稿URLで埋め込みHTMLが生成される() throws {
        let html = try XCTUnwrap(PhotoSourceResolver.instagramEmbedHTML(postURL: "https://www.instagram.com/p/ABC123/"))
        XCTAssertTrue(html.contains("class=\"instagram-media\""))
        XCTAssertTrue(html.contains("data-instgrm-permalink=\"https://www.instagram.com/p/ABC123/\""))
        XCTAssertTrue(html.contains("https://www.instagram.com/embed.js"))
        XCTAssertTrue(html.contains("name=\"viewport\""))
    }

    func test_reel形式の投稿URLで埋め込みHTMLが生成される() throws {
        let html = try XCTUnwrap(PhotoSourceResolver.instagramEmbedHTML(postURL: "https://www.instagram.com/reel/XYZ789/"))
        XCTAssertTrue(html.contains("data-instgrm-permalink=\"https://www.instagram.com/reel/XYZ789/\""))
    }

    func test_ユーザー名付きp形式は正規化されクエリも除去される() throws {
        let html = try XCTUnwrap(
            PhotoSourceResolver.instagramEmbedHTML(
                postURL: "https://www.instagram.com/somecafe/p/ABC123/?utm_source=ig_embed&utm_campaign=loading"
            )
        )
        XCTAssertTrue(html.contains("data-instgrm-permalink=\"https://www.instagram.com/p/ABC123/\""))
        XCTAssertFalse(html.contains("somecafe"))
        XCTAssertFalse(html.contains("utm_source"))
    }

    func test_ユーザー名付きreel形式も正規化される() throws {
        let html = try XCTUnwrap(
            PhotoSourceResolver.instagramEmbedHTML(postURL: "https://www.instagram.com/somecafe/reel/XYZ789/")
        )
        XCTAssertTrue(html.contains("data-instgrm-permalink=\"https://www.instagram.com/reel/XYZ789/\""))
    }

    func test_プロフィールURLはnil() {
        XCTAssertNil(PhotoSourceResolver.instagramEmbedHTML(postURL: "https://www.instagram.com/somecafe/"))
    }

    func test_instagram以外のドメインはnil() {
        XCTAssertNil(PhotoSourceResolver.instagramEmbedHTML(postURL: "https://example.com/p/ABC123/"))
    }

    func test_不正な文字列はnil() {
        XCTAssertNil(PhotoSourceResolver.instagramEmbedHTML(postURL: "not a url"))
    }
}
