import Foundation

/// Supabase 接続設定（T007）。
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
