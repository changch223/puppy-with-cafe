import Foundation

/// 一覧シートの見出し（今の条件を言葉にする）の純ロジック（憲章 原則IV）。
enum SheetHeadline {
    struct Text: Equatable {
        /// 例: 「犬OKのお店 547件」
        let title: String
        /// 並び順と起点（例: 「現在地から近い順」「渋谷駅から近い順」「確認日が新しい順」）
        let subtitle: String
    }

    /// - Parameters:
    ///   - count: 今の条件での件数
    ///   - amenities: 店内OK/テラス/大型犬OK/犬メニュー の条件
    ///   - openNowOnly: 「営業中」チップ（対象時刻があるときは「その時間に営業」）
    ///   - targetLabel: 「いつ行く？」で決めた対象時刻の短い表記（例: 「土 12:00」）。nil は「今」
    ///   - myDog: 「うちの子OK」チップがオンのときのうちの子（見出しが「うちの子（小型犬）が入れるお店」になる）。オフは nil
    ///   - includeUnverified: 未確認の店も表示中か（含むときは「犬OK」と言い切らない）
    ///   - sortOrder: 並び順
    ///   - originName: 起点名。現在地のとき（`isCurrentLocation`）は「現在地」と言う
    static func make(
        count: Int,
        amenities: AmenityFilter,
        openNowOnly: Bool,
        targetLabel: String? = nil,
        myDog: DogProfile? = nil,
        includeUnverified: Bool = false,
        sortOrder: CafeSortOrder = .distance,
        originName: String,
        isCurrentLocation: Bool
    ) -> Text {
        let labels = amenityLabels(amenities)
        // 未確認を含むときは「犬OK」ではなく「犬同伴」（未確認は可と言えない, 憲章 原則I）
        let dogPhrase = includeUnverified ? String(localized: "犬同伴") : String(localized: "犬OK")
        // 「今開いている」／対象時刻があるときは「土 12:00 に開いている」
        let openPhrase = targetLabel.map { String(localized: "\($0) に開いている") } ?? String(localized: "今開いている")
        let body: String
        if let myDog {
            // 「うちの子（小型犬）が入れるお店」。ほかの条件はその前後に添える
            let dogName = myDog.size.displayName
            let canEnter = String(localized: "うちの子（\(dogName)）が入れる")
            switch (openNowOnly, labels.isEmpty) {
            case (false, true):
                body = String(localized: "\(canEnter)お店")
            case (true, true):
                body = String(localized: "\(openPhrase)、\(canEnter)お店")
            case (false, false):
                body = String(localized: "\(canEnter)、\(labels.joined(separator: "・"))のお店")
            case (true, false):
                body = String(localized: "\(openPhrase)、\(canEnter)、\(labels.joined(separator: "・"))のお店")
            }
        } else {
            switch (openNowOnly, labels.isEmpty) {
            case (false, true):
                body = String(localized: "\(dogPhrase)のお店")
            case (true, true):
                body = String(localized: "\(openPhrase)\(dogPhrase)のお店")
            case (false, false):
                body = String(localized: "\(labels.joined(separator: "・"))のお店")
            case (true, false):
                body = String(localized: "\(openPhrase)、\(labels.joined(separator: "・"))のお店")
            }
        }
        let suffix = includeUnverified ? String(localized: "（未確認を含む）") : ""
        return Text(
            title: String(localized: "\(body) \(count)件\(suffix)"),
            subtitle: subtitle(sortOrder: sortOrder, originName: originName, isCurrentLocation: isCurrentLocation)
        )
    }

    static func subtitle(sortOrder: CafeSortOrder, originName: String, isCurrentLocation: Bool) -> String {
        switch sortOrder {
        case .distance:
            let origin = isCurrentLocation ? String(localized: "現在地") : originName
            return String(localized: "\(origin)から近い順")
        case .recentlyVerified:
            return String(localized: "確認日が新しい順")
        }
    }

    /// オンの犬向け条件の表示名（チップと同じ並び）
    static func amenityLabels(_ amenities: AmenityFilter) -> [String] {
        var labels: [String] = []
        if amenities.indoorOnly { labels.append(String(localized: "店内OK")) }
        if amenities.terraceOnly { labels.append(String(localized: "テラス")) }
        if amenities.largeDogOnly { labels.append(String(localized: "大型犬OK")) }
        if amenities.dogMenuOnly { labels.append(String(localized: "犬メニュー")) }
        return labels
    }
}
