import Foundation

/// カフェの「写真・雰囲気」表示チェーンで使う純ロジック（憲章 原則IV、UI非依存）。
/// 画像そのものは保存・転載せず、リンク先（OGP/IG投稿埋め込み）を端末側で直接取得・表示するための
/// URL解決・HTML生成のみを担う。
enum PhotoSourceResolver {
    /// OGP写真カードに使うリンクを `cafe.links` から選ぶ。優先順は website → tabelog → instagram。
    /// 該当リンクが無い・URLとして不正な場合は次点にフォールバックし、全滅なら nil。
    static func previewSourceURL(for cafe: Cafe) -> URL? {
        guard let links = cafe.links else { return nil }
        let priority: [CafeLinkType] = [.website, .tabelog, .instagram]
        for type in priority {
            if let url = links.first(where: { $0.type == type })?.resolvedURL {
                return url
            }
        }
        return nil
    }

    /// リンクが無いカフェ向けの「地図で写真を見る」フォールバック用 Google マップ検索URL。
    /// `店名 + 住所`（住所nilなら店名のみ）をパーセントエンコードして `query` パラメータに載せる。
    static func mapsPhotoSearchURL(name: String, address: String?) -> URL? {
        let query = [name, address]
            .compactMap { $0 }
            .joined(separator: " ")
        guard !query.isEmpty else { return nil }

        // query パラメータの値なので、区切り文字として意味を持つ記号（&, +, =, ? など）も含めてエンコードする
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&+=?#")
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else {
            return nil
        }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)")
    }

    /// Instagram投稿の定型埋め込みHTML（`blockquote.instagram-media` + `embed.js`）を生成する。
    /// `instagram.com` の `/p/<code>/` または `/reel/<code>/` 形式（ユーザー名プレフィックス・クエリ付き可）
    /// の投稿URLのみ受理し、`/p/<code>/`（または `/reel/<code>/`）に正規化する。
    /// それ以外（プロフィールURL・他ドメイン等）は nil。
    static func instagramEmbedHTML(postURL: String) -> String? {
        guard let permalink = normalizedInstagramPermalink(from: postURL) else { return nil }
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>body { margin: 0; padding: 0; background-color: transparent; }</style>
        </head>
        <body>
        <blockquote class="instagram-media" data-instgrm-permalink="\(permalink)" data-instgrm-version="14" style="margin: 0; width: 100%;"></blockquote>
        <script async src="https://www.instagram.com/embed.js"></script>
        </body>
        </html>
        """
    }

    /// 投稿URLを `https://www.instagram.com/(p|reel)/<code>/` へ正規化する。受理できなければ nil。
    private static func normalizedInstagramPermalink(from urlString: String) -> String? {
        guard let components = URLComponents(string: urlString),
              let host = components.host?.lowercased(),
              host == "instagram.com" || host == "www.instagram.com"
        else { return nil }

        let pathParts = components.path.split(separator: "/").map(String.init)
        guard let typeIndex = pathParts.firstIndex(where: { $0 == "p" || $0 == "reel" }),
              typeIndex + 1 < pathParts.count
        else { return nil }

        let type = pathParts[typeIndex]
        let code = pathParts[typeIndex + 1]
        guard !code.isEmpty else { return nil }
        return "https://www.instagram.com/\(type)/\(code)/"
    }
}
