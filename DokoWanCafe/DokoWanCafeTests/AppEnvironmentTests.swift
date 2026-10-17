import XCTest
@testable import DokoWanCafe

/// AppEnvironment（アプリ構成値）のユニットテスト
final class AppEnvironmentTests: XCTestCase {
    private func configured(_ template: String) -> Bool {
        AppEnvironment.isReportFormConfigured(["REPORT_FORM_URL": template])
    }

    func test_報告フォーム_正しいhttpsテンプレートは利用可() {
        XCTAssertTrue(configured("https://docs.google.com/forms/d/e/ABC/viewform?usp=pp_url&entry.1={cafe_name}&entry.2={cafe_id}"))
    }

    func test_報告フォーム_空文字は利用不可() {
        XCTAssertFalse(configured(""))
    }

    func test_報告フォーム_空白のみは利用不可() {
        XCTAssertFalse(configured("   "))
        XCTAssertFalse(configured("\n\t "))
    }

    func test_報告フォーム_不正な文字列は利用不可() {
        XCTAssertFalse(configured("not a url"))
        XCTAssertFalse(configured("form.example.com/viewform"), "scheme なしは不可")
    }

    func test_報告フォーム_非ASCIIを含むテンプレートは利用不可() {
        XCTAssertFalse(configured("https://example.com/フォーム?name={cafe_name}"))
    }

    func test_報告フォーム_httpは利用不可() {
        XCTAssertFalse(configured("http://example.com/form?name={cafe_name}"))
    }

    func test_報告フォーム_httpsの大文字schemeも利用可() {
        XCTAssertTrue(configured("HTTPS://example.com/form?name={cafe_name}"))
    }

    func test_報告フォーム_店名の非ASCIIはエンコードされURLが組み立つ() throws {
        let url = try XCTUnwrap(AppEnvironment.reportFormURL(
            cafeName: "犬カフェ", cafeID: UUID(),
            environment: ["REPORT_FORM_URL": "https://example.com/form?n={cafe_name}"]
        ))
        XCTAssertTrue(url.absoluteString.hasPrefix("https://example.com/form?n=%E7%8A%AC"))
    }

    func test_バージョンはバンドルの値を返し無ければハイフン() {
        XCTAssertEqual(AppEnvironment.appVersion(bundle: Bundle(for: AppEnvironmentTests.self)).isEmpty, false)
        XCTAssertEqual(AppEnvironment.appVersion(bundle: Bundle(path: NSTemporaryDirectory()) ?? Bundle()), "-")
    }

    func test_公開URLは固定() {
        XCTAssertEqual(AppEnvironment.privacyPolicyURL.absoluteString, "https://changch223.github.io/puppy-with-cafe/docs/privacy.html")
        XCTAssertEqual(AppEnvironment.supportURL.absoluteString, "https://changch223.github.io/puppy-with-cafe/docs/support.html")
        XCTAssertEqual(AppEnvironment.addressBaseRegistryTermsURL.absoluteString, "https://www.digital.go.jp/policies/base_registry_address_tos")
    }
}
