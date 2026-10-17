import Foundation

/// アプリの構成値（構成B: research.md R11）。
enum AppEnvironment {
    /// カフェデータの静的配信URL（GitHub Pages）。
    /// バンドル版をフォールバックに、起動時にここから最新データを取得する（FR-032）。
    static let defaultCafesDataURL: String? = "https://changch223.github.io/puppy-with-cafe/data/cafes.json"

    /// 誤り報告の Google フォームURLテンプレート。`{cafe_name}` `{cafe_id}` が置換される。
    /// フォーム作成後に設定する（tools/README.md 手順2）。未設定なら店詳細の報告ボタンは表示しない。
    static let defaultReportFormTemplate: String? = nil

    /// プライバシーポリシー（GitHub Pages）
    static let privacyPolicyURL = URL(string: "https://changch223.github.io/puppy-with-cafe/docs/privacy.html")!

    /// サポート（GitHub Pages）
    static let supportURL = URL(string: "https://changch223.github.io/puppy-with-cafe/docs/support.html")!

    /// デジタル庁「アドレス・ベース・レジストリ」の公共データ利用規約（出典クレジットのリンク先）
    static let addressBaseRegistryTermsURL = URL(string: "https://www.digital.go.jp/policies/base_registry_address_tos")!

    /// 表示名（Info.plist の CFBundleDisplayName と一致）
    static let displayName = "Puppy With Cafe"

    /// アプリのバージョン（CFBundleShortVersionString）。取得できない場合は "-"。
    static func appVersion(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    /// 誤り報告フォームが利用可能か（未設定・不正なら店詳細の報告ボタン自体を出さない）。
    /// 実際に組み立てられるURLが https の場合のみ true（空白のみ・不正文字列・http は false）。
    static func isReportFormConfigured(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard let url = reportFormURL(cafeName: "x", cafeID: UUID(), environment: environment) else {
            return false
        }
        return url.scheme?.lowercased() == "https"
    }

    /// 開発時は環境変数 CAFES_DATA_URL で上書き可能
    static func cafesDataURL(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let raw = environment["CAFES_DATA_URL"] ?? defaultCafesDataURL
        guard let raw, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    /// 開発時は環境変数 REPORT_FORM_URL で上書き可能
    static func reportFormURL(
        cafeName: String,
        cafeID: UUID,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let template = environment["REPORT_FORM_URL"] ?? defaultReportFormTemplate
        guard let template, !template.isEmpty else { return nil }
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+"))
        let name = cafeName.addingPercentEncoding(withAllowedCharacters: allowed) ?? cafeName
        let filled = template
            .replacingOccurrences(of: "{cafe_name}", with: name)
            .replacingOccurrences(of: "{cafe_id}", with: cafeID.uuidString.lowercased())
        // テンプレートの生の非ASCII文字は不正とみなす（iOS 16 は nil、17+ は自動エンコードで挙動が割れるため統一）。
        // 店名は上で percent-encode 済みなので、ここで弾かれるのはテンプレート側の問題のみ。
        guard filled.allSatisfy(\.isASCII) else { return nil }
        return URL(string: filled)
    }
}

/// Supabase 接続設定（旧A案・保管。research.md R11 参照）。
///
/// 機密はリポジトリに含めない（憲章 開発ワークフロー）。
/// 注入方法: Xcode の Scheme > Run > Arguments > Environment Variables に
///   SUPABASE_URL / SUPABASE_ANON_KEY を設定する（xcuserdata は .gitignore 済み）。
/// 未設定の場合、アプリは「サンプルデータモード」で起動する（バナーで明示）。
struct SupabaseConfig: Sendable {
    let url: URL
    let anonKey: String

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SupabaseConfig? {
        guard
            let rawURL = environment["SUPABASE_URL"], !rawURL.isEmpty,
            let url = URL(string: rawURL),
            let anonKey = environment["SUPABASE_ANON_KEY"], !anonKey.isEmpty
        else {
            return nil
        }
        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}
