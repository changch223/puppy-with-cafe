import Foundation

/// うちの子の設定（大きさ・過ごし方）の端末ローカル保存（再設計 段階3）。
/// サインインなし・同期なし・端末の外へ送らない（憲章 原則III）。UserDefaults（PrivacyInfo の CA92.1 の範囲）に JSON で保存する。
/// テストからは `defaults` に隔離用の suite（`UserDefaults(suiteName:)`）を注入できる。
@MainActor
final class DogProfileStore: ObservableObject {
    static let profileKey = "mydog.profile.v1"
    /// 初回の2問を一度出したか（「あとで設定する」を選んでも次からは出さない）
    static let onboardingShownKey = "mydog.onboardingShown.v1"

    private let defaults: UserDefaults
    @Published private(set) var profile: DogProfile?
    @Published private(set) var hasShownOnboarding: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 読めない保存データは設定なし（落とさない）。次に保存したとき上書きされる
        self.profile = defaults.data(forKey: Self.profileKey)
            .flatMap { try? JSONDecoder().decode(DogProfile.self, from: $0) }
        self.hasShownOnboarding = defaults.bool(forKey: Self.onboardingShownKey)
    }

    /// 設定を保存する（即時）
    func save(_ profile: DogProfile) {
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.profileKey)
        }
    }

    /// 初回の2問を出したと記録する（出した時点で記録。二度と自動では出さない）
    func markOnboardingShown() {
        hasShownOnboarding = true
        defaults.set(true, forKey: Self.onboardingShownKey)
    }

    /// 初回の2問を今出すか: データを表示できていて、まだ一度も出しておらず、設定もまだないとき。
    func shouldPresentOnboarding(dataDisplayed: Bool) -> Bool {
        dataDisplayed && !hasShownOnboarding && profile == nil
    }
}
