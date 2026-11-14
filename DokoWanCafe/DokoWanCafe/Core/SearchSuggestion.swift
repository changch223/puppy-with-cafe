import CoreLocation
import Foundation

/// 入力中の候補（検索画面の第2弾）の純ロジック。憲章 原則IV。
/// 条件の辞書・エリアの索引・組み合わせ・お店の並び・お店の行の2行目を扱う。
/// すべて端末の中だけで計算し、入力語を外へ送らない（原則III）。判定は行わず、データに明記された事実だけを使う（原則I）。

// MARK: - 条件

/// 入力語から提案する条件。地図の条件チップ（フィルタ）に1対1で対応する。
enum SearchCondition: CaseIterable, Hashable, Sendable {
    case terrace
    case indoor
    case largeDog
    case dogMenu
    case openNow
    case myDog

    /// 条件の言葉（言い換えを含む）。照合は `CafeNameSearch.normalize` を通して行う。
    var words: [String] {
        switch self {
        case .terrace: return ["テラス", "terrace", "外席", "屋外"]
        case .indoor: return ["店内", "室内", "indoor", "雨", "雨の日"]
        case .largeDog: return ["大型犬", "大きい犬", "large"]
        case .dogMenu: return ["犬メニュー", "わんこメニュー", "ドッグメニュー", "犬用メニュー"]
        case .openNow: return ["営業中", "今開いてる", "開いてる", "open"]
        case .myDog: return ["うちの子"]
        }
    }

    /// 「◯◯のお店」の◯◯。行の文言と組み合わせの文言に使う
    var phrase: String {
        switch self {
        case .terrace: return String(localized: "テラス席OK")
        case .indoor: return String(localized: "店内OK")
        case .largeDog: return String(localized: "大型犬OK")
        case .dogMenu: return String(localized: "犬メニューあり")
        case .openNow: return String(localized: "営業中")
        case .myDog: return String(localized: "うちの子OK")
        }
    }

    /// 条件の名前（「絞り込み」シートの行・営業中／うちの子OK のチップ名と同じ）
    var chipName: String {
        switch self {
        case .terrace: return String(localized: "テラス")
        case .indoor: return String(localized: "店内OK")
        case .largeDog: return String(localized: "大型犬OK")
        case .dogMenu: return String(localized: "犬メニュー")
        case .openNow: return String(localized: "営業中")
        case .myDog: return String(localized: "うちの子OK")
        }
    }

    /// 地図に条件チップがあるか。営業中・うちの子OK だけがチップ。ほかは「絞り込み」シートの中
    var hasChip: Bool { self == .openNow || self == .myDog }

    /// 行の文言: 「テラス席OKのお店に絞る」。「いつ行く？」で時刻を決めているときの営業中は「その時間に営業のお店に絞る」
    /// （実際の絞り込みは対象時刻に開いている店なので、チップ名と同じ言い方にする）
    func title(isTargetTime: Bool = false) -> String {
        if self == .openNow && isTargetTime { return String(localized: "その時間に営業のお店に絞る") }
        return String(localized: "\(phrase)のお店に絞る")
    }

    /// サブ行: 「渋谷駅の周り · 地図の「営業中」チップをオンにします」「渋谷駅の周り · 「絞り込み」の「テラス」をオンにします」。
    /// `originName` は今の起点の名前（現在地なら「現在地」）
    func subtitle(originName: String, isTargetTime: Bool = false) -> String {
        let chip = self == .openNow && isTargetTime ? String(localized: "その時間に営業") : chipName
        if hasChip { return String(localized: "\(originName)の周り · 地図の「\(chip)」チップをオンにします") }
        return String(localized: "\(originName)の周り · 「絞り込み」の「\(chip)」をオンにします")
    }

    /// VoiceOver: 「テラス席OKのお店に絞る。地図の条件をオンにします」
    func spokenText(isTargetTime: Bool = false) -> String {
        String(localized: "\(title(isTargetTime: isTargetTime))。地図の条件をオンにします")
    }

    /// 正規化した入力がこの条件の言葉に当たるか。店名への誤爆を減らすため、次の決まりで照合する。
    /// - 1文字の言葉（「雨」）は、入力がその1文字のときだけ（「彩雨珈琲店」では出さない）
    /// - 言葉の先頭との一致は、言葉の半分以上（2文字以上）打ったとき。英字の言葉は4文字以上（「la」「in」では出さない）
    /// - 入力が言葉を含む場合は、日本語の言葉だけ。英字の言葉は、空白で区切った語がその言葉と同じときだけ
    ///   （`normalizedTerms` は空白で区切った語をそれぞれ正規化したもの）
    func matches(normalizedInput input: String, normalizedTerms: [String] = []) -> Bool {
        guard !input.isEmpty else { return false }
        return words.contains { word in
            let normalizedWord = CafeNameSearch.normalize(word)
            if normalizedWord.count == 1 { return input == normalizedWord }
            let isASCII = normalizedWord.unicodeScalars.allSatisfy(\.isASCII)
            let minimumPrefix = max(isASCII ? 4 : 2, (normalizedWord.count + 1) / 2)
            if input.count >= minimumPrefix && normalizedWord.hasPrefix(input) { return true }
            if isASCII { return normalizedTerms.contains(normalizedWord) }
            return input.contains(normalizedWord)
        }
    }

    /// 条件をフィルタの状態へ反映する（オンにするだけ。すでにオンのものは変えない）。起点は変えない。
    static func apply(
        _ conditions: some Collection<SearchCondition>,
        amenities: inout AmenityFilter,
        openNowOnly: inout Bool,
        myDogOnly: inout Bool
    ) {
        for condition in conditions {
            switch condition {
            case .terrace: amenities.terraceOnly = true
            case .indoor: amenities.indoorOnly = true
            case .largeDog: amenities.largeDogOnly = true
            case .dogMenu: amenities.dogMenuOnly = true
            case .openNow: openNowOnly = true
            case .myDog: myDogOnly = true
            }
        }
    }
}

// MARK: - エリア

/// エリアの索引の1件。中心は、掲載店の座標の中央値（`sub_area`）またはプリセットの座標。地名からは推測しない。
struct SearchArea: Equatable, Identifiable {
    let name: String
    let latitude: Double
    let longitude: Double
    /// 掲載店の数（閉店・犬不可・未確認は数えない）
    let count: Int
    /// 照合用に正規化した名前。「表参道・青山」なら全体と各部分（「表参道」「青山」）。
    /// 近くのプリセットの名前（「東京駅周辺」など）も別名として入る
    let keys: [String]

    var id: String { name }

    init(name: String, latitude: Double, longitude: Double, count: Int) {
        self.init(name: name, latitude: latitude, longitude: longitude, count: count, keys: Self.defaultKeys(for: name))
    }

    init(name: String, latitude: Double, longitude: Double, count: Int, keys: [String]) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.count = count
        self.keys = keys
    }

    /// 名前の全体と、「・」で区切った各部分（2つ以上あるとき）を正規化したもの
    static func defaultKeys(for name: String) -> [String] {
        let whole = CafeNameSearch.normalize(name)
        return [whole] + parts(of: name).map(CafeNameSearch.normalize)
    }

    /// 「・」で区切った部分（2つ以上あるときだけ。1つなら空）
    static func parts(of name: String) -> [String] {
        let parts = name.split(separator: "・").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.count > 1 ? parts : []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 条件とエリアの組み合わせ（「代官山の周りで、テラス席OKのお店」）
struct SearchCombo: Equatable {
    let area: SearchArea
    let conditions: [SearchCondition]

    /// 行の文言: 「代官山の周りで、テラス席OKのお店」。対象時刻があるときの営業中は「その時間に営業」
    func title(isTargetTime: Bool = false) -> String {
        let phrases = conditions.map { condition in
            condition == .openNow && isTargetTime ? String(localized: "その時間に営業") : condition.phrase
        }.joined(separator: "・")
        return String(localized: "\(area.name)の周りで、\(phrases)のお店")
    }
}

/// 入力中の候補の計算
enum SearchSuggestion {
    /// エリアの候補の最大件数
    static let maxAreaResults = 5
    /// 打つ前の「近くのエリア」の最大件数
    static let maxNearbyAreas = 8
    /// 打つ前の「行きたい」の最大件数
    static let maxWantToGo = 3

    // MARK: 条件・組み合わせ

    /// 入力語が当たる条件（辞書の並び順）。「うちの子OK」は `hasMyDog`（うちの子が設定済み）のときだけ。
    /// 入力が掲載店の名前そのもの（`shopNames` は正規化した店名）のときは、店を探しているので条件を出さない。
    static func conditions(for query: String, hasMyDog: Bool, shopNames: Set<String> = []) -> [SearchCondition] {
        let input = CafeNameSearch.normalize(query)
        guard !input.isEmpty, !shopNames.contains(input) else { return [] }
        let normalizedTerms = terms(of: query).map(CafeNameSearch.normalize)
        return SearchCondition.allCases.filter { condition in
            (condition != .myDog || hasMyDog)
                && condition.matches(normalizedInput: input, normalizedTerms: normalizedTerms)
        }
    }

    /// 入力が、条件・エリア・組み合わせ・お店のどれにも当たらないか（このとき検索画面の先頭に
    /// 「「○○」という名前の掲載店はありません」の案内を出す）。エリアや条件がある場合（お店だけ0件）は false。
    /// 入力がひらがな（と長音・空白）だけのときは、まだ漢字に変換している途中とみなして案内を出さない。
    /// エリアの索引は漢字なので、「しぶや」を打っている途中はどれにも当たらず、駅名を打っている人に
    /// 「駅名やエリア名でも探せます」と言ってしまうため（SwiftUI の TextField は変換前の文字もそのまま渡す）。
    static func hasNoMatch(query: String, hasCombo: Bool, conditions: [SearchCondition], areas: [SearchArea], shops: [Cafe]) -> Bool {
        guard !isLikelyComposingKana(query) else { return false }
        return !hasCombo && conditions.isEmpty && areas.isEmpty && shops.isEmpty
    }

    /// 変換前の入力らしいか。ひらがな・長音・空白だけ（フリック入力の途中）か、
    /// その後ろに英字が数文字付いた形（ローマ字入力の途中。「しb」「だいかn」）なら true。
    static func isLikelyComposingKana(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // ローマ字入力の途中の英字（半角・全角）を末尾から外す。1音の綴りは長くても数文字（「ltsu」など）
        var scalars = Array(trimmed.unicodeScalars)
        var strippedLatin = 0
        while let last = scalars.last, strippedLatin < 4, isLatinLetter(last) {
            scalars.removeLast()
            strippedLatin += 1
        }
        guard !scalars.isEmpty else { return false }
        return scalars.allSatisfy { scalar in
            (0x3041...0x309F).contains(scalar.value) || scalar.value == 0x30FC || scalar.properties.isWhitespace
        }
    }

    /// 半角・全角の英字か
    private static func isLatinLetter(_ scalar: Unicode.Scalar) -> Bool {
        (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value)
            || (0xFF21...0xFF3A).contains(scalar.value) || (0xFF41...0xFF5A).contains(scalar.value)
    }

    /// 入力を空白（全角・半角）で区切った語
    static func terms(of query: String) -> [String] {
        query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// 1つの語がエリアに当たり、別の語が条件に当たったときの組み合わせ。なければ nil。
    static func combo(for query: String, areas: [SearchArea], hasMyDog: Bool) -> SearchCombo? {
        let words = terms(of: query)
        guard words.count >= 2 else { return nil }
        for (index, term) in words.enumerated() {
            guard let area = self.areas(matching: term, in: areas, limit: 1).first else { continue }
            var matched: [SearchCondition] = []
            for (otherIndex, other) in words.enumerated() where otherIndex != index {
                for condition in conditions(for: other, hasMyDog: hasMyDog) where !matched.contains(condition) {
                    matched.append(condition)
                }
            }
            if !matched.isEmpty { return SearchCombo(area: area, conditions: matched) }
        }
        return nil
    }

    // MARK: エリアの索引

    /// プリセットを近くのデータのエリアにまとめる距離（メートル）。これより近ければ、プリセットは別名にする
    static let presetMergeMeters: Double = 1_500

    /// エリアの索引を作る。データの `sub_area` とプリセットから。地名からは推測しない（原則I）。
    /// - 中心は掲載店の座標の中央値（緯度・経度それぞれ）。遠い店1軒に引っ張られないように平均は使わない
    /// - 件数は閉店・犬不可・未確認を数えない。0件のエリアは出さない
    /// - 「立川・昭島」のようなエリアは、部分（「昭島」）で打っても全体の名前で出す（部分ごとの中心は作らない。
    ///   住所の文字で店を分けると、建物名の一致などで件数と中心が実際とずれるため）
    /// - プリセットは、`presetMergeMeters` 以内にデータのエリアがあれば、いちばん近いエリアの別名にする
    ///   （「渋谷 72」と「渋谷駅周辺 19」のように、同じ場所が数え方の違う件数で並ばないように）。
    ///   近くに無いプリセットだけを、半径で数えた件数で残す
    static func buildIndex(cafes: [Cafe], presets: [ManualArea]) -> [SearchArea] {
        let shown = cafes.filter { !$0.isClosed && $0.dogPolicyStatus != .unverified && $0.dogPolicyStatus != .notAllowed }

        var order: [String] = []
        var groups: [String: [Cafe]] = [:]
        for cafe in shown {
            guard let name = cafe.subArea?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            if groups[name] == nil { order.append(name) }
            groups[name, default: []].append(cafe)
        }

        // データのエリア（全体）
        var wholes: [SearchArea] = order.map { name in
            let members = groups[name] ?? []
            let center = medianCoordinate(members)
            return SearchArea(name: name, latitude: center.latitude, longitude: center.longitude, count: members.count)
        }
        var usedNames = Set(wholes.map { CafeNameSearch.normalize($0.name) })

        // プリセット: 近くのデータのエリアの別名にするか、単独で残す
        var aliases: [Int: [String]] = [:]
        var standalonePresets: [SearchArea] = []
        for entry in PopularAreaRanking.ranked(areas: presets, cafes: cafes) where entry.count > 0 {
            let key = CafeNameSearch.normalize(entry.area.name)
            // 同じ名前のデータのエリアがあれば、距離によらずそこにまとめる（別名を付ける先を取り違えない）
            if wholes.contains(where: { CafeNameSearch.normalize($0.name) == key }) { continue }
            let nearest = wholes.indices.map { index in
                (index, DistanceCalculator.distanceMeters(
                    fromLatitude: entry.area.latitude, fromLongitude: entry.area.longitude,
                    toLatitude: wholes[index].latitude, toLongitude: wholes[index].longitude
                ))
            }.min { $0.1 < $1.1 }
            if let nearest, nearest.1 <= presetMergeMeters {
                if !wholes[nearest.0].keys.contains(key) { aliases[nearest.0, default: []].append(key) }
                usedNames.insert(key)
                continue
            }
            guard usedNames.insert(key).inserted else { continue }
            standalonePresets.append(SearchArea(
                name: entry.area.name,
                latitude: entry.area.latitude, longitude: entry.area.longitude,
                count: entry.count
            ))
        }
        for (index, extra) in aliases {
            let area = wholes[index]
            wholes[index] = SearchArea(
                name: area.name, latitude: area.latitude, longitude: area.longitude,
                count: area.count, keys: area.keys + extra
            )
        }

        return wholes + standalonePresets
    }

    /// 座標の中央値（緯度・経度それぞれ）。空なら (0, 0)
    static func medianCoordinate(_ cafes: [Cafe]) -> CLLocationCoordinate2D {
        func median(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            guard !sorted.isEmpty else { return 0 }
            let middle = sorted.count / 2
            return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        }
        return CLLocationCoordinate2D(latitude: median(cafes.map(\.latitude)), longitude: median(cafes.map(\.longitude)))
    }

    /// 入力語に当たるエリア。前から一致 → 途中一致（2文字以上のとき）の順で、それぞれ件数の多い順。最大 `limit` 件。
    static func areas(matching query: String, in index: [SearchArea], limit: Int = maxAreaResults) -> [SearchArea] {
        let needle = CafeNameSearch.normalize(query)
        guard !needle.isEmpty else { return [] }
        let prefixMatches = index.filter { area in area.keys.contains { $0.hasPrefix(needle) } }
        var matches = byCount(prefixMatches)
        if needle.count >= 2 {
            let prefixNames = Set(prefixMatches.map(\.name))
            let others = index.filter { area in
                !prefixNames.contains(area.name) && area.keys.contains { $0.contains(needle) }
            }
            matches += byCount(others)
        }
        return Array(matches.prefix(limit))
    }

    /// 打つ前の「近くのエリア」: 起点から近い順に `limit` 件。起点がまだ無いときは件数の多い順。
    static func nearbyAreas(in index: [SearchArea], origin: CLLocationCoordinate2D?, limit: Int = maxNearbyAreas) -> [SearchArea] {
        guard let origin else { return Array(byCount(index).prefix(limit)) }
        let keyed = index.map { area in
            (area, DistanceCalculator.distanceMeters(
                fromLatitude: origin.latitude, fromLongitude: origin.longitude,
                toLatitude: area.latitude, toLongitude: area.longitude
            ))
        }
        return Array(stableSorted(keyed) { $0.1 }.map(\.0).prefix(limit))
    }

    private static func byCount(_ areas: [SearchArea]) -> [SearchArea] {
        stableSorted(areas) { -Double($0.count) }
    }

    // MARK: お店

    /// 店名の一致（前方一致 → 部分一致、閉店は除く）。各グループの中は「行きたいの店 → 起点から近い順」。最大 `limit` 件。
    static func shops(
        matching query: String,
        in cafes: [Cafe],
        wantToGoIDs: Set<UUID>,
        origin: CLLocationCoordinate2D?,
        limit: Int = CafeNameSearch.maxResults
    ) -> [Cafe] {
        let grouped = CafeNameSearch.groupedResults(query: query, in: cafes)
        let ordered = wantToGoFirstNearest(grouped.prefix, wantToGoIDs: wantToGoIDs, origin: origin)
            + wantToGoFirstNearest(grouped.other, wantToGoIDs: wantToGoIDs, origin: origin)
        return Array(ordered.prefix(limit))
    }

    /// 打つ前の「行きたい」: 行きたいの店（閉店は除く）を起点から近い順に最大 `limit` 件
    static func wantToGoShops(
        in cafes: [Cafe],
        wantToGoIDs: Set<UUID>,
        origin: CLLocationCoordinate2D?,
        limit: Int = maxWantToGo
    ) -> [Cafe] {
        let wanted = cafes.filter { wantToGoIDs.contains($0.id) && !$0.isClosed }
        return Array(nearestFirst(wanted, origin: origin).prefix(limit))
    }

    private static func wantToGoFirstNearest(_ cafes: [Cafe], wantToGoIDs: Set<UUID>, origin: CLLocationCoordinate2D?) -> [Cafe] {
        let wanted = cafes.filter { wantToGoIDs.contains($0.id) }
        let others = cafes.filter { !wantToGoIDs.contains($0.id) }
        return nearestFirst(wanted, origin: origin) + nearestFirst(others, origin: origin)
    }

    /// 起点から近い順（同じ距離・起点なしは元の並びのまま）
    private static func nearestFirst(_ cafes: [Cafe], origin: CLLocationCoordinate2D?) -> [Cafe] {
        guard let origin else { return cafes }
        return stableSorted(cafes) { cafe in
            DistanceCalculator.distanceMeters(
                fromLatitude: origin.latitude, fromLongitude: origin.longitude,
                toLatitude: cafe.latitude, toLongitude: cafe.longitude
            )
        }
    }

    /// 安定な昇順の並べ替え（`sorted` は安定でないので、元の位置を第2キーにする）
    private static func stableSorted<T>(_ items: [T], by key: (T) -> Double) -> [T] {
        let keys: [Double] = items.map(key)
        let order: [Int] = Array(items.indices).sorted { lhs, rhs in
            keys[lhs] != keys[rhs] ? keys[lhs] < keys[rhs] : lhs < rhs
        }
        return order.map { items[$0] }
    }
}

// MARK: - お店の行

/// 候補のお店の行の2行目「エリア · 距離 · 営業中・19時まで」と読み上げ。
/// 距離は今の起点から測る。営業の状態は営業時間から分かるときだけ書く（分からないときは書かない。原則I）。
struct SearchShopSubtitle: Equatable {
    /// 表示する部分（エリア・距離・営業の順。分かるものだけ）
    let parts: [String]
    /// 読み上げる部分（エリア・距離・営業の順）
    let spokenParts: [String]

    /// 2行目の文字。1つも無ければ nil
    var text: String? {
        parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// - Parameters:
    ///   - origin: 距離を測る起点（無ければ距離は書かない）
    ///   - date: 営業の判定に使う時刻（今、または「いつ行く？」の対象時刻）
    ///   - isTargetTime: `date` が対象時刻か（「土 12:00 は…」の言い方にする）
    static func make(cafe: Cafe, origin: CLLocationCoordinate2D?, at date: Date, isTargetTime: Bool = false) -> SearchShopSubtitle {
        var parts: [String] = []
        var spoken: [String] = []

        if let subArea = cafe.subArea?.trimmingCharacters(in: .whitespacesAndNewlines), !subArea.isEmpty {
            parts.append(subArea)
            spoken.append(subArea)
        }

        if let origin {
            let meters = DistanceCalculator.distanceMeters(
                fromLatitude: origin.latitude, fromLongitude: origin.longitude,
                toLatitude: cafe.latitude, toLongitude: cafe.longitude
            )
            parts.append(WalkingTime.distanceText(meters: meters))
            spoken.append(spokenDistance(meters: meters))
        }

        if let open = openText(for: cafe, at: date, isTargetTime: isTargetTime) {
            parts.append(open.text)
            spoken.append(open.spoken)
        }
        return SearchShopSubtitle(parts: parts, spokenParts: spoken)
    }

    /// 距離の読み上げ（「320メートル」「3.2キロメートル」）
    static func spokenDistance(meters: Double) -> String {
        let value = max(meters, 0)
        if value < 995 {
            return String(localized: "\(max(10, Int((value / 10).rounded()) * 10))メートル")
        }
        return String(localized: "\(String(format: "%.1f", value / 1_000))キロメートル")
    }

    /// 営業の状態。営業中は「営業中・19時まで」（閉店時刻が分かるとき）、営業時間外は「時間外」、定休は `OpenLine` と同じ言い方。
    /// 営業時間が分からない店は nil（営業中とも時間外とも書かない）。
    private static func openText(for cafe: Cafe, at date: Date, isTargetTime: Bool) -> (text: String, spoken: String)? {
        let label = isTargetTime ? TargetTime.shortLabel(date) : nil
        switch OpeningHoursEvaluator.state(hours: cafe.hours, at: date) {
        case .open:
            let closing = OpeningHoursEvaluator.closingTimeIfOpen(hours: cafe.hours, at: date)
            let closingText = closing.map { OpenLine.spokenTime($0) }
            let text = closingText.map { String(localized: "営業中・\($0)まで") } ?? String(localized: "営業中")
            let spoken = closingText.map { String(localized: "営業中\($0)まで") } ?? String(localized: "営業中")
            guard let label else { return (text, spoken) }
            return (String(localized: "\(label) は\(text)"), String(localized: "\(label) は\(spoken)"))
        case .outsideHours:
            let text = String(localized: "時間外")
            guard let label else { return (text, text) }
            let targeted = String(localized: "\(label) は\(text)")
            return (targeted, targeted)
        case .closedToday:
            let text = OpenLine.make(hours: cafe.hours, at: date, isTargetTime: isTargetTime).text
            return (text, text)
        case .unknown:
            return nil
        }
    }
}
