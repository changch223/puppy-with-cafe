import Foundation

/// 最近の検索（端末ローカルのみ・サインインなし・同期なし）。UserDefaults に保存する。
/// テストからは `defaults` に隔離用の suite を注入できる。並び・上限は `RecentSearchLogic` が担う。
@MainActor
final class RecentSearchStore: ObservableObject {
    private static let storageKey = "recentSearches.v1"

    private let defaults: UserDefaults
    @Published private(set) var entries: [RecentSearch]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.entries = RecentSearchLogic.decode(defaults.data(forKey: Self.storageKey))
    }

    func add(name: String, latitude: Double, longitude: Double) {
        entries = RecentSearchLogic.adding(
            RecentSearch(name: name, latitude: latitude, longitude: longitude),
            to: entries
        )
        defaults.set(RecentSearchLogic.encode(entries), forKey: Self.storageKey)
    }
}
