import Foundation

/// お気に入り（端末ローカル・サインインなし・同期なし・位置情報を伴わない, UI/UXブラッシュアップ設計書 1c）。
/// UserDefaults に保存する。テストからは `defaults` に隔離用の suite（`UserDefaults(suiteName:)`）を注入できる。
@MainActor
final class FavoritesStore: ObservableObject {
    private static let storageKey = "favorites.cafeIDs"

    private let defaults: UserDefaults
    @Published private(set) var favoriteIDs: Set<UUID>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.favoriteIDs = FavoritesLogic.decode(defaults.stringArray(forKey: Self.storageKey))
    }

    /// `id` がお気に入りに含まれるか
    func contains(_ id: UUID) -> Bool {
        favoriteIDs.contains(id)
    }

    /// お気に入りのON/OFFを切り替え、UserDefaultsへ即時保存する
    func toggle(_ id: UUID) {
        favoriteIDs = FavoritesLogic.toggled(id, in: favoriteIDs)
        defaults.set(FavoritesLogic.encode(favoriteIDs), forKey: Self.storageKey)
    }
}
