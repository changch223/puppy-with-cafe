import XCTest
@testable import DokoWanCafe

/// OGP（og:image / twitter:image / タイトル）の HTML パーサ（純ロジック）のユニットテスト
final class OGMetadataParserTests: XCTestCase {
    private let base = URL(string: "https://example.com/shop/cafe/index.html")!

    private func parse(_ html: String) -> OGMetadataParser.Result {
        OGMetadataParser.parse(html: html, baseURL: base)
    }

    // MARK: - 画像 URL

    func test_ogImageを取り出す() {
        let result = parse(#"<html><head><meta property="og:image" content="https://cdn.example.com/a.jpg"></head></html>"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_contentが先の属性順でも取れる() {
        let result = parse(#"<meta content="https://cdn.example.com/a.jpg" property="og:image">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_nameで書かれたogImageも取れる() {
        let result = parse(#"<meta name="og:image" content="https://cdn.example.com/a.jpg">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_シングルクォートでも取れる() {
        let result = parse("<meta property='og:image' content='https://cdn.example.com/a.jpg'>")
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_引用符なしの属性値でも取れる() {
        let result = parse("<meta property=og:image content=https://cdn.example.com/a.jpg>")
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_タグ名と属性名の大文字小文字は問わない() {
        let result = parse(#"<META PROPERTY="OG:IMAGE" CONTENT="https://cdn.example.com/a.jpg" />"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_属性の間に改行や余分な空白があっても取れる() {
        let html = "<meta\n  property = \"og:image\"\n  content = \"https://cdn.example.com/a.jpg\"\n/>"
        XCTAssertEqual(parse(html).imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_自己終了タグでも取れる() {
        let result = parse(#"<meta property="og:image" content="https://cdn.example.com/a.jpg"/>"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_他の属性が混じっていても取れる() {
        let result = parse(#"<meta data-rh="true" property="og:image" data-x='y' content="https://cdn.example.com/a.jpg" itemprop="image">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_ogImageがogImageSecureUrlより優先される() {
        let html = """
        <meta property="og:image:secure_url" content="https://cdn.example.com/secure.jpg">
        <meta name="twitter:image" content="https://cdn.example.com/tw.jpg">
        <meta property="og:image" content="https://cdn.example.com/og.jpg">
        """
        XCTAssertEqual(parse(html).imageURL?.absoluteString, "https://cdn.example.com/og.jpg")
    }

    func test_ogImageがなければsecure_urlを使う() {
        let html = """
        <meta name="twitter:image" content="https://cdn.example.com/tw.jpg">
        <meta property="og:image:secure_url" content="https://cdn.example.com/secure.jpg">
        """
        XCTAssertEqual(parse(html).imageURL?.absoluteString, "https://cdn.example.com/secure.jpg")
    }

    func test_twitterImageだけの場合も取れる() {
        let result = parse(#"<meta name="twitter:image" content="https://cdn.example.com/tw.jpg">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/tw.jpg")
    }

    func test_ogImageの中身が空なら次の候補へ進む() {
        let html = """
        <meta property="og:image" content="">
        <meta name="twitter:image" content="https://cdn.example.com/tw.jpg">
        """
        XCTAssertEqual(parse(html).imageURL?.absoluteString, "https://cdn.example.com/tw.jpg")
    }

    func test_ogがなければ画像はnil() {
        let result = parse("<html><head><title>カフェ</title><meta name=\"description\" content=\"説明\"></head></html>")
        XCTAssertNil(result.imageURL)
    }

    // MARK: - URL の解決

    func test_相対URL_ルート相対はページのホストで解決する() {
        let result = parse(#"<meta property="og:image" content="/img/a.jpg">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://example.com/img/a.jpg")
    }

    func test_相対URL_ディレクトリ相対はページのパスを基準に解決する() {
        let result = parse(#"<meta property="og:image" content="img/a.jpg">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://example.com/shop/cafe/img/a.jpg")
    }

    func test_相対URL_上の階層も解決する() {
        let result = parse(#"<meta property="og:image" content="../img/a.jpg">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://example.com/shop/img/a.jpg")
    }

    func test_プロトコル相対URLはページのスキームで解決する() {
        let result = parse(#"<meta property="og:image" content="//cdn.example.com/a.jpg">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_http画像URLはそのまま返す_https化は別処理() {
        let result = parse(#"<meta property="og:image" content="http://cdn.example.com/a.jpg">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "http://cdn.example.com/a.jpg")
    }

    func test_httpとhttps以外のスキームは使わない() {
        XCTAssertNil(parse(#"<meta property="og:image" content="data:image/png;base64,AAAA">"#).imageURL)
        XCTAssertNil(parse(#"<meta property="og:image" content="javascript:alert(1)">"#).imageURL)
        XCTAssertNil(parse(#"<meta property="og:image" content="file:///etc/passwd">"#).imageURL)
    }

    func test_httpsUpgradedはhttpをhttpsに直す() {
        let url = URL(string: "http://cdn.example.com/a.jpg?x=1")!
        XCTAssertEqual(OGMetadataParser.httpsUpgraded(url).absoluteString, "https://cdn.example.com/a.jpg?x=1")
    }

    func test_httpsUpgradedは80番ポートを外しhttpsはそのまま() {
        XCTAssertEqual(
            OGMetadataParser.httpsUpgraded(URL(string: "http://cdn.example.com:80/a.jpg")!).absoluteString,
            "https://cdn.example.com/a.jpg"
        )
        let https = URL(string: "https://cdn.example.com/a.jpg")!
        XCTAssertEqual(OGMetadataParser.httpsUpgraded(https), https)
    }

    // MARK: - HTML エンティティ

    func test_画像URLのエンティティを戻す() {
        let result = parse(#"<meta property="og:image" content="https://cdn.example.com/a.jpg?w=800&amp;h=600&#38;q=80">"#)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg?w=800&h=600&q=80")
    }

    func test_タイトルのエンティティを戻す() {
        let result = parse(#"<meta property="og:title" content="Dog &amp; Cafe &quot;わん&quot; &#x3042;&#12356; &lt;b&gt; &#39;x&#39; &apos;y&apos;">"#)
        XCTAssertEqual(result.title, #"Dog & Cafe "わん" あい <b> 'x' 'y'"#)
    }

    func test_二重にはデコードしない() {
        XCTAssertEqual(OGMetadataParser.decodeEntities("&amp;amp;"), "&amp;")
    }

    func test_知らないエンティティや壊れたエンティティはそのまま残す() {
        XCTAssertEqual(OGMetadataParser.decodeEntities("A &unknown; B & C &amp D"), "A &unknown; B & C &amp D")
        XCTAssertEqual(OGMetadataParser.decodeEntities("&#xZZ; &#99999999999;"), "&#xZZ; &#99999999999;")
    }

    // MARK: - タイトル

    func test_ogTitleを優先する() {
        let html = """
        <html><head><title>ページのタイトル</title>
        <meta property="og:title" content="OGのタイトル"></head></html>
        """
        XCTAssertEqual(parse(html).title, "OGのタイトル")
    }

    func test_ogTitleがなければtitleタグを使う() {
        XCTAssertEqual(parse("<html><head><title>  わんこカフェ\n  渋谷店 </title></head></html>").title, "わんこカフェ 渋谷店")
    }

    func test_titleタグの属性や大文字も許す() {
        XCTAssertEqual(parse(#"<TITLE lang="ja">カフェ &amp; バー</TITLE>"#).title, "カフェ & バー")
    }

    func test_タイトルがどこにもなければnil() {
        XCTAssertNil(parse("<html><body>こんにちは</body></html>").title)
        XCTAssertNil(parse("<title>   </title>").title)
    }

    // MARK: - 壊れた HTML

    func test_空文字や無関係な文字列でも落ちない() {
        XCTAssertEqual(parse(""), OGMetadataParser.Result(imageURL: nil, title: nil))
        XCTAssertEqual(parse("not html at all <<<>>> &&&"), OGMetadataParser.Result(imageURL: nil, title: nil))
    }

    func test_閉じていないタグや途中で切れたHTMLでも前の情報は取れる() {
        let html = #"<head><meta property="og:image" content="https://cdn.example.com/a.jpg"><meta property="og:ti"#
        let result = parse(html)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
        XCTAssertNil(result.title)
    }

    func test_引用符が閉じていないmetaがあっても落ちない() {
        let html = """
        <meta property="og:image" content="https://broken.example.com/a.jpg>
        <meta name="twitter:image" content="https://cdn.example.com/tw.jpg">
        """
        _ = parse(html)
    }

    func test_content属性がないmetaは無視する() {
        let html = """
        <meta property="og:image">
        <meta name="twitter:image" content="https://cdn.example.com/tw.jpg">
        """
        XCTAssertEqual(parse(html).imageURL?.absoluteString, "https://cdn.example.com/tw.jpg")
    }

    func test_contentの中に大なり記号があっても読める() {
        let result = parse(#"<meta property="og:title" content="A > B"><meta property="og:image" content="https://cdn.example.com/a.jpg">"#)
        XCTAssertEqual(result.title, "A > B")
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    func test_bodyの中にあるmetaでも読む() {
        let html = #"<body><div><meta property="og:image" content="https://cdn.example.com/a.jpg"></div></body>"#
        XCTAssertEqual(parse(html).imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }

    // MARK: - 文字コード

    func test_ヘッダーの文字コードで読む() throws {
        let html = #"<html><head><title>わんこカフェ</title></head></html>"#
        let data = try XCTUnwrap(html.data(using: .shiftJIS))
        XCTAssertTrue(OGMetadataParser.decode(data: data, headerEncodingName: "shift_jis").contains("わんこカフェ"))
    }

    func test_ヘッダーがなければmetaのcharsetで読む() throws {
        let html = #"<html><head><meta charset="Shift_JIS"><title>わんこカフェ</title></head></html>"#
        let data = try XCTUnwrap(html.data(using: .shiftJIS))
        XCTAssertTrue(OGMetadataParser.decode(data: data, headerEncodingName: nil).contains("わんこカフェ"))
    }

    func test_文字コードの指定がなければUTF8で読む() {
        let data = Data("<title>わんこカフェ</title>".utf8)
        XCTAssertEqual(OGMetadataParser.decode(data: data, headerEncodingName: nil), "<title>わんこカフェ</title>")
    }

    func test_文字の途中で切れたUTF8でも落ちず前半は読める() {
        var data = Data(#"<meta property="og:image" content="https://cdn.example.com/a.jpg"><title>わ"#.utf8)
        data.removeLast(1) // 「わ」の3バイトのうち1バイトを落とす
        let result = OGMetadataParser.parse(html: OGMetadataParser.decode(data: data, headerEncodingName: "utf-8"), baseURL: base)
        XCTAssertEqual(result.imageURL?.absoluteString, "https://cdn.example.com/a.jpg")
    }
}
