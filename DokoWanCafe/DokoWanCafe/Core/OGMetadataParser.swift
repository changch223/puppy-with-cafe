import Foundation

/// ページの HTML から OGP の画像 URL・タイトルを取り出す純ロジック（ネットワーク非依存、憲章 原則IV）。
/// `LinkPreviewService` が先頭の約512KBだけ読んだ HTML を渡す。壊れた HTML でもクラッシュせず、取れたものだけ返す。
enum OGMetadataParser {
    struct Result: Equatable {
        /// 画像の URL（相対 URL は解決済み。http / https のみ）。見つからなければ nil
        let imageURL: URL?
        let title: String?
    }

    /// 画像 URL を探す `<meta>` のキー（優先順）
    private static let imageKeys = ["og:image", "og:image:secure_url", "twitter:image"]

    // `<meta ...>`（属性値の引用符の中の `>` は終端とみなさない）
    private static let metaTagRegex = try! NSRegularExpression(
        pattern: #"<meta\b(?:"[^"]*"|'[^']*'|[^>"'])*>"#,
        options: [.caseInsensitive]
    )
    // `name = "value"` / `name = 'value'` / `name = value`
    private static let attributeRegex = try! NSRegularExpression(
        pattern: #"([^\s"'<>/=]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))"#,
        options: []
    )
    private static let titleTagRegex = try! NSRegularExpression(
        pattern: #"<title\b[^>]*>(.*?)</title\s*>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    /// HTML から画像 URL・タイトルを取り出す。
    /// - Parameter baseURL: 相対 URL を解決する基準（ページの URL。リダイレクト後の最終 URL を渡す）
    static func parse(html: String, baseURL: URL) -> Result {
        var metas: [String: String] = [:]
        let range = NSRange(html.startIndex..., in: html)
        for match in metaTagRegex.matches(in: html, options: [], range: range) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let attributes = parseAttributes(String(html[tagRange]))
            guard let key = (attributes["property"] ?? attributes["name"])?
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !key.isEmpty,
                  let content = attributes["content"]
            else { continue }
            let value = decodeEntities(content).trimmingCharacters(in: .whitespacesAndNewlines)
            // 同じキーが複数あるときは、中身のある最初のものを使う
            if !value.isEmpty, metas[key] == nil { metas[key] = value }
        }

        var imageURL: URL?
        for key in imageKeys {
            if let value = metas[key], let url = resolve(value, against: baseURL) {
                imageURL = url
                break
            }
        }

        var title = metas["og:title"]
        if title == nil, let raw = titleTagContent(in: html) {
            let collapsed = decodeEntities(raw)
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
            if !collapsed.isEmpty { title = collapsed }
        }
        return Result(imageURL: imageURL, title: title)
    }

    /// 相対 URL を基準 URL で解決する。http / https 以外（data: など）は nil。
    static func resolve(_ string: String, against baseURL: URL) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        guard url.host?.isEmpty == false else { return nil }
        return url
    }

    /// `http://` を `https://` に直す（ATS で http は読めないため）。https などはそのまま。
    static func httpsUpgraded(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        components.scheme = "https"
        // 明示的な :80 は https では意味が変わるので外す
        if components.port == 80 { components.port = nil }
        return components.url ?? url
    }

    /// 取得した HTML のバイト列を文字列にする。HTTP ヘッダーの文字コード → HTML 先頭の `charset=` → UTF-8 の順。
    /// 先頭だけ読んだデータは末尾が文字の途中で切れていることがあるので、変換できない部分は読み飛ばす。
    static func decode(data: Data, headerEncodingName: String?) -> String {
        var encoding: String.Encoding?
        if let name = headerEncodingName { encoding = stringEncoding(ianaName: name) }
        if encoding == nil {
            let head = String(decoding: data.prefix(2048), as: UTF8.self)
            if let match = firstCapture(in: head, pattern: #"charset\s*=\s*["']?\s*([A-Za-z0-9_\-:.]+)"#) {
                encoding = stringEncoding(ianaName: match)
            }
        }
        if let encoding, encoding != .utf8 {
            // 先頭で切れたデータの末尾の不完全な文字は、数バイト削って変換し直す
            for drop in 0...3 where data.count > drop {
                if let text = String(data: data.dropLast(drop), encoding: encoding) { return text }
            }
        }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - 内部

    private static func parseAttributes(_ tag: String) -> [String: String] {
        var result: [String: String] = [:]
        let range = NSRange(tag.startIndex..., in: tag)
        for match in attributeRegex.matches(in: tag, options: [], range: range) {
            guard let nameRange = Range(match.range(at: 1), in: tag) else { continue }
            let name = tag[nameRange].lowercased()
            let value = (2...4).lazy
                .compactMap { Range(match.range(at: $0), in: tag) }
                .map { String(tag[$0]) }
                .first
            if let value, result[name] == nil { result[name] = value }
        }
        return result
    }

    private static func titleTagContent(in html: String) -> String? {
        firstCapture(in: html, regex: titleTagRegex)
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        return firstCapture(in: text, regex: regex)
    }

    private static func firstCapture(in text: String, regex: NSRegularExpression) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let captured = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[captured])
    }

    private static func stringEncoding(ianaName: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(ianaName as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
    ]

    /// HTML エンティティ（`&amp;` `&#39;` `&#x27;` など）を戻す。知らないものはそのまま残す。
    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            guard char == "&",
                  let semicolon = text[index...].prefix(12).firstIndex(of: ";")
            else {
                result.append(char)
                index = text.index(after: index)
                continue
            }
            let body = text[text.index(after: index)..<semicolon]
            if let decoded = decodeEntityBody(String(body)) {
                result.append(decoded)
                index = text.index(after: semicolon)
            } else {
                result.append(char)
                index = text.index(after: index)
            }
        }
        return result
    }

    private static func decodeEntityBody(_ body: String) -> String? {
        if body.hasPrefix("#") {
            let digits = body.dropFirst()
            let value: UInt32?
            if let first = digits.first, first == "x" || first == "X" {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits, radix: 10)
            }
            guard let value, let scalar = Unicode.Scalar(value) else { return nil }
            return String(Character(scalar))
        }
        return namedEntities[body.lowercased()]
    }
}
