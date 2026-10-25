import Foundation

/// 保存の状態: 行きたい／行った（1つの店はどちらか一方、または未保存）
enum SavedStatus: Equatable, Sendable {
    case wantToGo
    case visited
}

/// 保存したお店1件（店ID＋日付。行きたい＝追加日、行った＝行った日）
struct SavedEntry: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
}

/// 「行きたい」「行った」の2つのリスト（端末ローカル・サインイン不要・位置情報を伴わない）。
/// 純ロジック・UI非依存（憲章 原則IV）。1つの店は2つのリストのどちらか一方にだけ入る
/// （行ったにしたら行きたいから外れ、行きたいにしたら行ったから外れる）。
struct SavedPlaces: Codable, Equatable, Sendable {
    private(set) var wantToGo: [SavedEntry]
    private(set) var visited: [SavedEntry]

    init(wantToGo: [SavedEntry] = [], visited: [SavedEntry] = []) {
        self.wantToGo = wantToGo
        self.visited = visited
    }

    func status(of id: UUID) -> SavedStatus? {
        if wantToGo.contains(where: { $0.id == id }) { return .wantToGo }
        if visited.contains(where: { $0.id == id }) { return .visited }
        return nil
    }

    /// 行った日（行ったの店だけ）
    func visitedDate(of id: UUID) -> Date? {
        visited.first(where: { $0.id == id })?.date
    }

    var wantToGoIDs: Set<UUID> { Set(wantToGo.map(\.id)) }
    var visitedIDs: Set<UUID> { Set(visited.map(\.id)) }

    /// 「行きたい」の切り替え。行きたいなら外す。そうでなければ（未保存でも行ったでも）行きたいに入れる。
    mutating func toggleWantToGo(_ id: UUID, at date: Date) {
        if status(of: id) == .wantToGo {
            wantToGo.removeAll { $0.id == id }
        } else {
            visited.removeAll { $0.id == id }
            wantToGo.append(SavedEntry(id: id, date: date))
        }
    }

    /// 「行った」の切り替え。行ったなら外す。そうでなければ（未保存でも行きたいでも）行ったに入れる。
    mutating func toggleVisited(_ id: UUID, at date: Date) {
        if status(of: id) == .visited {
            visited.removeAll { $0.id == id }
        } else {
            wantToGo.removeAll { $0.id == id }
            visited.append(SavedEntry(id: id, date: date))
        }
    }

    /// どちらのリストからも外す
    mutating func remove(_ id: UUID) {
        wantToGo.removeAll { $0.id == id }
        visited.removeAll { $0.id == id }
    }

    /// 並び: 日付が新しい順（同じ日付は店IDの文字列順で固定）。行きたい＝追加が新しい順、行った＝行った日が新しい順。
    static func newestFirst(_ entries: [SavedEntry]) -> [SavedEntry] {
        entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// 保存一覧を新しい順にして、読み込み済みの店に当てはめる。見つからない店（閉店で非掲載など）は飛ばす。
    static func resolve(_ entries: [SavedEntry], in cafes: [CafeWithDistance]) -> [CafeWithDistance] {
        let byID = Dictionary(cafes.map { ($0.cafe.id, $0) }, uniquingKeysWith: { first, _ in first })
        return newestFirst(entries).compactMap { byID[$0.id] }
    }
}

/// 旧「お気に入り」から「行きたい」への移行（純ロジック）。
enum SavedPlacesMigration {
    /// 旧お気に入り（UserDefaults の UUID 文字列配列）をすべて「行きたい」に入れる。
    /// すでにどちらかのリストにある店は動かさない（二重に入れない）。パース不能な値は無視する。
    static func migrate(legacyRawIDs: [String]?, into places: SavedPlaces, at date: Date) -> SavedPlaces {
        var result = places
        let legacyIDs = FavoritesLogic.decode(legacyRawIDs).sorted { $0.uuidString < $1.uuidString }
        for id in legacyIDs where result.status(of: id) == nil {
            result.toggleWantToGo(id, at: date)
        }
        return result
    }
}

/// 「行きたい」リストの共有文（店名・エリア・Google マップの検索URLを1店1ブロック）
enum SavedListShare {
    /// 共有に載せる最大店数（超えた分は「ほかN店」）
    static let maxCount = 20

    static func message(for cafes: [Cafe]) -> String {
        var blocks: [String] = [String(localized: "行きたいお店リスト（\(cafes.count)店）")]
        for cafe in cafes.prefix(maxCount) {
            var lines = [cafe.name]
            if let area = cafe.subArea?.trimmingCharacters(in: .whitespacesAndNewlines), !area.isEmpty {
                lines.append(area)
            }
            if let url = CafeDetailShare.mapsURL(for: cafe) {
                lines.append(url.absoluteString)
            }
            blocks.append(lines.joined(separator: "\n"))
        }
        if cafes.count > maxCount {
            blocks.append(String(localized: "ほか\(cafes.count - maxCount)店"))
        }
        blocks.append(String(localized: "Puppy With Cafe で見つけました"))
        return blocks.joined(separator: "\n\n")
    }
}
