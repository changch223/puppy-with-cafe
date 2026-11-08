import Foundation

/// 最近の検索と見たお店（端末ローカルのみ・サインインなし・同期なし）。UserDefaults に保存する。
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
        persist()
    }

    /// 検索画面から開いたお店を残す（名前・座標・店の id だけ。入力語は残さない）
    func addViewedCafe(_ cafe: Cafe) {
        entries = RecentSearchLogic.adding(
            RecentSearch(name: cafe.name, latitude: cafe.latitude, longitude: cafe.longitude, cafeID: cafe.id),
            to: entries
        )
        persist()
    }

    /// 1件消す（スワイプ）
    func remove(_ entry: RecentSearch) {
        entries = RecentSearchLogic.removing(entry, from: entries)
        persist()
    }

    /// 閉店・削除でデータから消えた「見たお店」を消す（表示されないまま上限の枠をふさがないように）。場所の検索は残す
    func removeCafes(notIn validIDs: Set<UUID>) {
        let kept = entries.filter { entry in entry.cafeID.map(validIDs.contains) ?? true }
        guard kept.count != entries.count else { return }
        entries = kept
        persist()
    }

    /// すべて消す
    func removeAll() {
        entries = []
        persist()
    }

    private func persist() {
        defaults.set(RecentSearchLogic.encode(entries), forKey: Self.storageKey)
    }
}
