import Foundation

/// 保存したお店（行きたい／行った）の端末ローカル保存（サインインなし・同期なし・位置情報を伴わない）。
/// UserDefaults に JSON で保存する。テストからは `defaults` に隔離用の suite（`UserDefaults(suiteName:)`）を注入できる。
///
/// 旧「お気に入り」（キー `favorites.cafeIDs`）は、初回起動時に1回だけ「行きたい」へ移行する。
/// 旧キーは移行後も消さない（利用者のデータを失わない）。二重に移行しないよう移行済みフラグを持つ。
@MainActor
final class SavedPlacesStore: ObservableObject {
    static let storageKey = "saved.places.v1"
    /// 旧お気に入り（UUID文字列の配列）。読むだけで、書き換えも削除もしない
    static let legacyFavoritesKey = "favorites.cafeIDs"
    /// 読めなかった保存データの退避先キーの接頭辞（末尾に日時が付く）
    static let corruptKeyPrefix = "saved.places.v1.corrupt-"
    static let migratedFlagKey = "saved.places.migratedFromFavorites"

    private let defaults: UserDefaults
    private let now: () -> Date
    @Published private(set) var places: SavedPlaces

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
        var loaded = Self.load(from: defaults, now: now())
        if !defaults.bool(forKey: Self.migratedFlagKey) {
            loaded = SavedPlacesMigration.migrate(
                legacyRawIDs: defaults.stringArray(forKey: Self.legacyFavoritesKey),
                into: loaded,
                at: now()
            )
            // 先にデータを保存してからフラグを立てる（途中で終わっても再移行は何も足さない）
            Self.save(loaded, to: defaults)
            defaults.set(true, forKey: Self.migratedFlagKey)
        }
        self.places = loaded
    }

    /// 保存済みのデータを読む。読めないデータは空で上書きして失わないよう、別キー
    /// （`saved.places.v1.corrupt-<日時>`）へ退避し、元のキーを消してから空で始める（退避は1回だけ）。
    private static func load(from defaults: UserDefaults, now: Date) -> SavedPlaces {
        guard let data = defaults.data(forKey: storageKey) else { return SavedPlaces() }
        if let decoded = try? JSONDecoder().decode(SavedPlaces.self, from: data) { return decoded }
        defaults.set(data, forKey: corruptKeyPrefix + ISO8601DateFormatter().string(from: now))
        defaults.removeObject(forKey: storageKey)
        return SavedPlaces()
    }

    private static func save(_ places: SavedPlaces, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(places) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: - 参照

    func status(of id: UUID) -> SavedStatus? { places.status(of: id) }
    func isWantToGo(_ id: UUID) -> Bool { places.status(of: id) == .wantToGo }
    func visitedDate(of id: UUID) -> Date? { places.visitedDate(of: id) }
    var wantToGoIDs: Set<UUID> { places.wantToGoIDs }
    var visitedIDs: Set<UUID> { places.visitedIDs }

    // MARK: - 操作（即時保存）

    /// 「行きたい」のON/OFF
    func toggleWantToGo(_ id: UUID) {
        update { $0.toggleWantToGo(id, at: now()) }
    }

    /// 「行った」のON/OFF（行きたいから外して行ったに入れる）
    func toggleVisited(_ id: UUID) {
        update { $0.toggleVisited(id, at: now()) }
    }

    /// どちらのリストからも外す
    func remove(_ id: UUID) {
        update { $0.remove(id) }
    }

    private func update(_ change: (inout SavedPlaces) -> Void) {
        var next = places
        change(&next)
        places = next
        Self.save(next, to: defaults)
    }
}
