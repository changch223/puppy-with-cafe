import AuthenticationServices
import SwiftUI

/// サインイン誘導（T038, FR-028）。
/// 閲覧はサインイン不要。誤り報告・修正提案の送信時のみここへ誘導される。
struct SignInPromptView: View {
    @ObservedObject var auth: AuthService
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("報告にはサインインが必要です")
                .font(.headline)

            Text("いたずらやスパムを防ぎ、信頼できる情報を保つため、誤り報告の送信時のみサインインをお願いしています。閲覧・検索にサインインは不要です。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SignInWithAppleButton(.signIn) { request in
                auth.configure(request: request)
            } onCompletion: { result in
                Task {
                    do {
                        try await auth.handleCompletion(result)
                        errorMessage = nil
                    } catch AuthError.cancelled {
                        // キャンセルは黙って戻る
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .accessibilityLabel(Text("Appleでサインイン"))

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }
}
