import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// Supabase のユーザーセッション（Keychain に保存）
struct SupabaseSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userID: UUID
    let expiresAt: Date
}

enum AuthError: LocalizedError {
    case notConfigured
    case missingIdentityToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "バックエンド未設定のため、サインインできません。")
        case .missingIdentityToken:
            return String(localized: "Apple からの認証情報を取得できませんでした。")
        case .cancelled:
            return String(localized: "サインインがキャンセルされました。")
        }
    }
}

/// 認証サービス（FR-028 / research.md R4）。
/// 閲覧は匿名。誤り報告・修正提案の送信時のみ「Appleでサインイン」を要求する。
/// Apple の id_token を Supabase Auth (GoTrue) のセッションへ交換し、Keychain に保存する。
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var session: SupabaseSession?

    var isSignedIn: Bool { session != nil && (session?.expiresAt ?? .distantPast) > Date() }

    private let gateway: SupabaseGateway?
    private let keychain = KeychainStore(service: "com.dokowancafe.app.session")
    private var currentRawNonce: String?

    init(gateway: SupabaseGateway?) {
        self.gateway = gateway
        if let stored: SupabaseSession = keychain.load(SupabaseSession.self), stored.expiresAt > Date() {
            session = stored
            gateway?.tokenBox.set(stored.accessToken)
        }
    }

    /// SwiftUI `SignInWithAppleButton` の onRequest で呼ぶ（リプレイ攻撃対策の nonce を設定）
    func configure(request: ASAuthorizationAppleIDRequest) {
        let rawNonce = Self.randomNonce()
        currentRawNonce = rawNonce
        request.requestedScopes = []
        request.nonce = Self.sha256(rawNonce)
    }

    /// SwiftUI `SignInWithAppleButton` の onCompletion で呼ぶ
    func handleCompletion(_ result: Result<ASAuthorization, Error>) async throws {
        guard let gateway else { throw AuthError.notConfigured }

        switch result {
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                throw AuthError.cancelled
            }
            throw error
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                throw AuthError.missingIdentityToken
            }

            let response = try await gateway.signInWithIDToken(
                provider: "apple",
                idToken: idToken,
                nonce: currentRawNonce
            )
            let newSession = SupabaseSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                userID: response.user.id,
                expiresAt: Date().addingTimeInterval(response.expiresIn)
            )
            session = newSession
            gateway.tokenBox.set(newSession.accessToken)
            keychain.save(newSession)
        }
    }

    func signOut() {
        session = nil
        gateway?.tokenBox.set(nil)
        keychain.delete()
    }

    // MARK: - Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Keychain への最小限の保存（セッショントークン用。憲章 原則III）
struct KeychainStore {
    let service: String

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "default",
        ]
    }

    func save<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func load<T: Decodable>(_ type: T.Type) -> T? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
