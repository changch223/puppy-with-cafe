import Foundation

/// 検索画面の純ロジック（店名検索の正規化と一致・エリアの件数の数え方・最近の検索）。憲章 原則IV。
enum CafeNameSearch {
    /// 候補の最大件数
    static let maxResults = 20

    /// 検索用の正規化。全角半角・大文字小文字・ひらがなカタカナ・ラテン文字のアクセント記号を同一視し、空白は取り除く。
    /// 例: 「ｃａｆｅ」「Cafe」「Café」→「cafe」、「bébé」→「bebe」、「かふぇ」→「cafe」。
    /// 濁点・半濁点（が/か、ぱ/は など）は別の文字なので落とさない。
    /// さらに表記の違いをそろえる（入力側にも店名側にも同じようにかかる）: 「&」「＆」→「and」、「カフェ」→「cafe」、
    /// 「珈琲」「コーヒー」→「coffee」。「cafe and」と「カフェ&」、「珈琲」と「コーヒー」と「coffee」が同じに扱われる。
    static func normalize(_ text: String) -> String {
        replacingVariants(in: normalizeBase(text))
    }

    /// 表記の置き換え（「&」→「and」など）をかける前の正規化。打ちかけの入力（「カフ」「コーヒ」）が、
    /// 置き換え後の「cafe」「coffee」に前方一致しなくなるのを補うため、店名の一致ではこちらでも照合する。
    static func normalizeBase(_ text: String) -> String {
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

    /// 表記の置き換え。ひらがなはカタカナに直したあとなので、「カフェ」だけを見ればよい（全角の「＆」は幅をそろえた時点で「&」）
    private static let variantReplacements: [(from: String, to: String)] = [
        ("&", "and"), ("＆", "and"), ("カフェ", "cafe"), ("珈琲", "coffee"), ("コーヒー", "coffee"),
    ]

    private static func replacingVariants(in text: String) -> String {
        variantReplacements.reduce(text) { $0.replacingOccurrences(of: $1.from, with: $1.to) }
    }

    /// 店名の部分一致。閉店の店は除く。前方一致を先に、続いて途中一致（それぞれ元の並びを保つ）。最大 `limit` 件。
    static func results(query: String, in cafes: [Cafe], limit: Int = maxResults) -> [Cafe] {
        let grouped = groupedResults(query: query, in: cafes)
        return Array((grouped.prefix + grouped.other).prefix(limit))
    }

    /// 店名の一致を前方一致と途中一致に分けて返す（閉店は除く・件数の上限なし・それぞれ元の並びを保つ）。
    /// 店名に加えて読み（`nameReading`）も照合する。店名・読みのどちらかで前方一致すれば前方一致、どちらかで途中一致すれば途中一致（1店は1回だけ数える）。
    static func groupedResults(query: String, in cafes: [Cafe]) -> (prefix: [Cafe], other: [Cafe]) {
        let needle = normalize(query)
        guard !needle.isEmpty else { return ([], []) }
        let baseNeedle = normalizeBase(query)
        var prefixMatches: [Cafe] = []
        var otherMatches: [Cafe] = []
        for cafe in cafes where !cafe.isClosed {
            // 打ちかけの入力（「カフ」）は、置き換え前の表記でも照合する（置き換えで当たらなくならないように）
            let targets = [cafe.name] + (cafe.nameReading.map { [$0] } ?? [])
            let forms = targets.map { (normalize($0), normalizeBase($0)) }
            if forms.contains(where: { $0.0.hasPrefix(needle) || $0.1.hasPrefix(baseNeedle) }) {
                prefixMatches.append(cafe)
            } else if forms.contains(where: { $0.0.contains(needle) || $0.1.contains(baseNeedle) }) {
                otherMatches.append(cafe)
            }
        }
        return (prefixMatches, otherMatches)
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

/// 最近の検索（場所検索とエリア選択）と見たお店の1件。名前と座標（見たお店は店の id も）だけを持つ（端末内のみ・位置情報そのものは保存しない）。
/// `cafeID` は見たお店のときだけ入る。古い保存データ（項目なし）もそのまま読める。
struct RecentSearch: Codable, Equatable, Identifiable {
    let name: String
    let latitude: Double
    let longitude: Double
    let cafeID: UUID?

    init(name: String, latitude: Double, longitude: Double, cafeID: UUID? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.cafeID = cafeID
    }

    /// 見たお店は店の id、場所は名前（同じ名前の店と場所が互いを消さないようにする）
    var id: String { cafeID?.uuidString ?? name }

    var origin: SearchOrigin {
        .searched(name: name, latitude: latitude, longitude: longitude)
    }
}

/// 最近の検索の並び・上限・保存形式の純ロジック。
enum RecentSearchLogic {
    static let limit = 5

    /// 先頭に追加する。同じ場所（名前）・同じお店（id）は古い方を消して先頭へ移し、上限（場所とお店を合わせて）を超えた分は末尾から捨てる。
    static func adding(_ entry: RecentSearch, to list: [RecentSearch], limit: Int = limit) -> [RecentSearch] {
        Array(([entry] + list.filter { $0.id != entry.id }).prefix(limit))
    }

    /// 1件消す
    static func removing(_ entry: RecentSearch, from list: [RecentSearch]) -> [RecentSearch] {
        list.filter { $0.id != entry.id }
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
