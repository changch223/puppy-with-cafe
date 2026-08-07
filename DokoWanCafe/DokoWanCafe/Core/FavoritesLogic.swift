import Foundation

/// お気に入り（端末ローカル, UI/UXブラッシュアップ設計書 1c）の純ロジック。
/// UserDefaults の保存形式（UUID文字列の配列）とアプリ内で扱う `Set<UUID>` の変換、
/// トグル後の集合算出を担う（純ロジック・UI非依存, 憲章 原則IV）。
enum FavoritesLogic {
    /// UserDefaults の保存値（UUID文字列の配列）→ カフェID集合。
    /// パース不能な要素（壊れたデータ等）は無視する。
    static func decode(_ rawValues: [String]?) -> Set<UUID> {
        guard let rawValues else { return [] }
        return Set(rawValues.compactMap(UUID.init))
    }

    /// カフェID集合 → UserDefaults の保存値（UUID文字列の配列）
    static func encode(_ ids: Set<UUID>) -> [String] {
        ids.map(\.uuidString)
    }

    /// `id` を含めば除外、含まなければ追加した集合を返す（純関数）
    static func toggled(_ id: UUID, in ids: Set<UUID>) -> Set<UUID> {
        var result = ids
        if result.contains(id) {
            result.remove(id)
        } else {
            result.insert(id)
        }
        return result
    }
}
