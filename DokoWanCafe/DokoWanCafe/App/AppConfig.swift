import Foundation

/// アプリの構成値（構成B: research.md R11）。
enum AppEnvironment {
    /// カフェデータの静的配信URL（GitHub Pages）。
    /// バンドル版をフォールバックに、起動時にここから最新データを取得する（FR-032）。
    static let defaultCafesDataURL: String? = "https://changch223.github.io/puppy-with-cafe/data/cafes.json"

    /// 誤り報告の Google フォームURLテンプレート。`{cafe_name}` `{cafe_id}` が置換される。
    /// フォーム作成後に設定する（tools/README.md 手順2）。未設定なら報告は「準備中」表示。
    static let defaultReportFormTemplate: String? = nil

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
