import Foundation

/// 検索画面の純ロジック（店名検索の正規化と一致・よく探されるエリアの並べ替え・最近の検索）。憲章 原則IV。
enum CafeNameSearch {
    /// 候補の最大件数
    static let maxResults = 20

    /// 検索用の正規化。全角半角・大文字小文字・ひらがなカタカナ・ラテン文字のアクセント記号を同一視し、空白は取り除く。
    /// 例: 「ｃａｆｅ」「Cafe」「Café」→「cafe」、「bébé」→「bebe」、「かふぇ」→「カフェ」。
    /// 濁点・半濁点（が/か、ぱ/は など）は別の文字なので落とさない。
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
        // アクセント記号の除去はラテン文字だけに限る（かなの濁点まで落ちてしまうため）
        let unaccented = folded.map { character -> String in
            let isLatin = character.unicodeScalars.first.map { $0.isASCII || (0xC0...0x24F).contains($0.value) } ?? false
            return isLatin
                ? String(character).folding(options: .diacriticInsensitive, locale: nil)
                : String(character)
        }.joined()
        let katakana = unaccented.applyingTransform(.hiraganaToKatakana, reverse: false) ?? unaccented
        return katakana.filter { !$0.isWhitespace }
    }

    /// 店名の部分一致。閉店の店は除く。前方一致を先に、続いて途中一致（それぞれ元の並びを保つ）。最大 `limit` 件。
    static func results(query: String, in cafes: [Cafe], limit: Int = maxResults) -> [Cafe] {
        let needle = normalize(query)
        guard !needle.isEmpty else { return [] }
        var prefixMatches: [Cafe] = []
        var otherMatches: [Cafe] = []
        for cafe in cafes where !cafe.isClosed {
            let name = normalize(cafe.name)
            if name.hasPrefix(needle) {
                prefixMatches.append(cafe)
            } else if name.contains(needle) {
                otherMatches.append(cafe)
            }
        }
        return Array((prefixMatches + otherMatches).prefix(limit))
    }
}

/// 「よく探されるエリア」: 各エリアの中心から半径内に掲載店が多い順に並べる。
enum PopularAreaRanking {
    struct Entry: Equatable {
        let area: ManualArea
        let count: Int
    }

    static let radiusMeters: Double = 1_500

    /// 掲載店数の多い順（同数は渡された順）。数えるのは地図・一覧に既定で出る店だけ
    /// （閉店・犬不可・未確認は数えない。読み上げる件数を画面に出る店と一致させる）。
    static func ranked(areas: [ManualArea], cafes: [Cafe], radiusMeters: Double = radiusMeters) -> [Entry] {
        let open = cafes.filter { !$0.isClosed && $0.dogPolicyStatus != .unverified && $0.dogPolicyStatus != .notAllowed }
        let entries = areas.map { area in
            let count = open.filter {
                DistanceCalculator.distanceMeters(
                    fromLatitude: area.latitude, fromLongitude: area.longitude,
                    toLatitude: $0.latitude, toLongitude: $0.longitude
                ) <= radiusMeters
            }.count
            return Entry(area: area, count: count)
        }
        // sorted は安定ではないので、元の位置を第2キーにする
        return entries.enumerated()
            .sorted { lhs, rhs in
                lhs.element.count != rhs.element.count
                    ? lhs.element.count > rhs.element.count
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

/// 最近の検索（場所検索とエリア選択）の1件。名前と座標だけを持つ（端末内のみ・位置情報そのものは保存しない）。
struct RecentSearch: Codable, Equatable, Identifiable {
    let name: String
    let latitude: Double
    let longitude: Double

    var id: String { name }

    var origin: SearchOrigin {
        .searched(name: name, latitude: latitude, longitude: longitude)
    }
}

/// 最近の検索の並び・上限・保存形式の純ロジック。
enum RecentSearchLogic {
    static let limit = 5

    /// 先頭に追加する。同じ名前は古い方を消して先頭へ移し、上限を超えた分は末尾から捨てる。
    static func adding(_ entry: RecentSearch, to list: [RecentSearch], limit: Int = limit) -> [RecentSearch] {
        Array(([entry] + list.filter { $0.name != entry.name }).prefix(limit))
    }

    static func encode(_ list: [RecentSearch]) -> Data? {
        try? JSONEncoder().encode(list)
    }

    /// 壊れたデータは空として扱い、上限を超えていれば切り詰める。
    static func decode(_ data: Data?, limit: Int = limit) -> [RecentSearch] {
        guard let data, let list = try? JSONDecoder().decode([RecentSearch].self, from: data) else { return [] }
        return Array(list.prefix(limit))
    }
}
