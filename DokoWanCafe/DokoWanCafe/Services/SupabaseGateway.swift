import Foundation

/// Supabase 関連のエラー
enum SupabaseError: LocalizedError {
    case notConfigured
    case notSignedIn
    case httpError(status: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "バックエンドが設定されていません。")
        case .notSignedIn:
            return String(localized: "サインインが必要です。")
        case .httpError(let status, let message):
            return String(localized: "通信エラー（\(status)）: \(message)")
        case .emptyResponse:
            return String(localized: "サーバーから応答がありませんでした。")
        }
    }
}

/// アクセストークンの共有ボックス。
/// MainActor 上の AuthService が更新し、バックグラウンドの Gateway が読むため NSLock で保護する。
final class TokenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func set(_ token: String?) {
        lock.lock()
        value = token
        lock.unlock()
    }

    func get() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// GoTrue（Supabase Auth）のトークンレスポンス
struct AuthTokenResponse: Decodable, Sendable {
    struct AuthUser: Decodable, Sendable {
        let id: UUID
    }

    let accessToken: String
    let refreshToken: String
    let expiresIn: Double
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

/// Supabase への軽量ゲートウェイ（URLSession ベース）。
///
/// 設計判断（plan.md からの変更・research.md R1 注記）:
/// 必要な操作は RPC / select / insert / id_token サインインの4つのみのため、
/// supabase-swift SDK ではなく URLSession で直接 PostgREST / GoTrue REST を叩く。
/// 依存を薄く保つ（憲章 原則V: YAGNI）。
final class SupabaseGateway: @unchecked Sendable {
    let config: SupabaseConfig
    let tokenBox: TokenBox
    private let session: URLSession

    init(config: SupabaseConfig, tokenBox: TokenBox = TokenBox(), session: URLSession = .shared) {
        self.config = config
        self.tokenBox = tokenBox
        self.session = session
    }

    // MARK: - JSON coding

    /// PostgREST の日付形式（date: yyyy-MM-dd / timestamptz: ISO8601）を両対応でデコード
    static let decoder: JSONDecoder = {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(identifier: "UTC")

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = isoFractional.date(from: string)
                ?? iso.date(from: string)
                ?? dayFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "日付を解釈できません: \(string)"
            )
        }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // MARK: - PostgREST

    /// RPC 呼び出し（contracts/api-contracts.md #1）
    func rpc<Body: Encodable, Response: Decodable>(_ function: String, body: Body) async throws -> Response {
        let data = try await request(
            path: "rest/v1/rpc/\(function)",
            method: "POST",
            body: try Self.encoder.encode(body)
        )
        return try Self.decoder.decode(Response.self, from: data)
    }

    /// テーブル select（contracts/api-contracts.md #2）
    func select<Response: Decodable>(_ table: String, query: [URLQueryItem]) async throws -> Response {
        let data = try await request(path: "rest/v1/\(table)", method: "GET", query: query)
        return try Self.decoder.decode(Response.self, from: data)
    }

    /// テーブル insert（認証必須。Prefer: return=representation で挿入行を返す）
    func insertReturning<Body: Encodable, Response: Decodable>(_ table: String, body: Body) async throws -> Response {
        guard tokenBox.get() != nil else { throw SupabaseError.notSignedIn }
        let data = try await request(
            path: "rest/v1/\(table)",
            method: "POST",
            body: try Self.encoder.encode(body),
            extraHeaders: ["Prefer": "return=representation"]
        )
        return try Self.decoder.decode(Response.self, from: data)
    }

    // MARK: - GoTrue (Auth)

    /// Apple の id_token を Supabase セッションへ交換（contracts/api-contracts.md #4）
    func signInWithIDToken(provider: String, idToken: String, nonce: String?) async throws -> AuthTokenResponse {
        var payload: [String: String] = ["provider": provider, "id_token": idToken]
        if let nonce { payload["nonce"] = nonce }
        let data = try await request(
            path: "auth/v1/token",
            method: "POST",
            query: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: try JSONEncoder().encode(payload),
            authenticated: false
        )
        return try Self.decoder.decode(AuthTokenResponse.self, from: data)
    }

    // MARK: - Request core

    private func request(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        extraHeaders: [String: String] = [:],
        authenticated: Bool = true
    ) async throws -> Data {
        var components = URLComponents(
            url: config.url.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw SupabaseError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if authenticated {
            // ユーザートークンがあればそれを、なければ anon key を Bearer に使う
            let bearer = tokenBox.get() ?? config.anonKey
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        extraHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.httpError(status: -1, message: "不明な応答")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.httpError(status: http.statusCode, message: message)
        }
        return data
    }
}
