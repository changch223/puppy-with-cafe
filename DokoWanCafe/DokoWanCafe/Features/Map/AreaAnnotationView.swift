import MapKit
import UIKit

/// 東京全体が見えるほど引いたときにピンの代わりに出す、エリアのラベルの注釈（`AreaOverview`）。
/// 位置は、そのエリアの表示中の店の座標の中央値。
final class AreaAnnotation: NSObject, MKAnnotation {
    let summary: AreaSummary
    /// 衝突で間引くときの優先度（0〜1。件数が多いほど高い）
    let priority: Double

    init(summary: AreaSummary, priority: Double) {
        self.summary = summary
        self.priority = priority
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: summary.centerLatitude, longitude: summary.centerLongitude)
    }

    var title: String? { summary.name }

    /// VoiceOver で読む文（例: 「渋谷、42件」。続けて「タップでこのエリアへ寄ります」）
    var spokenLabel: String {
        String(localized: "\(summary.name)、\(summary.count)件")
    }
}

/// エリアのラベルの見た目: 面の色（ダークでは暗い面）の丸みのある札に、エリア名（太字）と、ブランドの緑の件数。
/// 札（見える部分）は小さめ（高さ 34pt）で、名前も短く（「渋谷」）して、重なりで間引かれるエリアを減らす。
/// 注釈のビュー自体は高さ 44pt 以上（タップ領域）で、その中に札を置く。文字色は面に対して 4.5:1 以上（名前は `label`、件数はブランド色の上の `onBrand`）。
final class AreaAnnotationView: MKAnnotationView {
    private let pill = UIView()
    private let nameLabel = UILabel()
    private let countBadge = UIView()
    private let countLabel = UILabel()

    private static let minHeight: CGFloat = 34
    private static let minTapHeight: CGFloat = 44
    private static let maxNameWidth: CGFloat = 150
    private static let horizontalPadding: CGFloat = 10
    private static let gap: CGFloat = 6
    private static let badgeHeight: CGFloat = 22

    /// ブランドの緑の上に載せる文字色（ライトは白、ダークは濃い色）
    private static let onBrand = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.04, green: 0.16, blue: 0.12, alpha: 1) : .white
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setUp()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }

    private func setUp() {
        canShowCallout = false
        collisionMode = .rectangle
        // 重なりの間引きは `AreaOverview.nonOverlappingLabelIDs` で決める（地図の標準の間引きには任せない）
        displayPriority = .required
        clusteringIdentifier = nil
        backgroundColor = .clear
        pill.backgroundColor = .systemBackground
        pill.isUserInteractionEnabled = false
        pill.layer.borderWidth = 1.5
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.2
        pill.layer.shadowRadius = 4
        pill.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(pill)

        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.textColor = .label
        nameLabel.isAccessibilityElement = false
        pill.addSubview(nameLabel)

        countBadge.backgroundColor = .brand
        countBadge.isAccessibilityElement = false
        pill.addSubview(countBadge)
        countLabel.textColor = Self.onBrand
        countLabel.textAlignment = .center
        countLabel.isAccessibilityElement = false
        countBadge.addSubview(countLabel)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = String(localized: "タップでこのエリアへ寄ります")

        updateBorderColor()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: AreaAnnotationView, _) in
            view.updateBorderColor()
        }
    }

    private func updateBorderColor() {
        pill.layer.borderColor = UIColor.brand.resolvedColor(with: traitCollection).cgColor
    }

    private static var labelFont: UIFont {
        UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 12, weight: .bold))
    }

    /// 札（見える部分）の大きさ。重なりの判定に使う（`configure` と同じ計算）
    static func pillSize(for summary: AreaSummary) -> CGSize {
        let font = labelFont
        let name = BroadArea.shortName(forArea: summary.name) as NSString
        let nameSize = name.size(withAttributes: [.font: font])
        let countSize = ("\(summary.count)" as NSString).size(withAttributes: [.font: font])
        let nameWidth = min(nameSize.width, maxNameWidth).rounded(.up)
        let badge = max(badgeHeight, countSize.height.rounded(.up) + 6)
        let badgeWidth = max(badge, countSize.width.rounded(.up) + 10)
        let height = max(minHeight, badge + 10, nameSize.height.rounded(.up) + 10)
        return CGSize(width: horizontalPadding + nameWidth + gap + badgeWidth + horizontalPadding - 4, height: height)
    }

    func configure(with annotation: AreaAnnotation) {
        let summary = annotation.summary
        nameLabel.font = Self.labelFont
        nameLabel.text = BroadArea.shortName(forArea: summary.name)
        countLabel.font = Self.labelFont
        countLabel.text = "\(summary.count)"

        let nameSize = nameLabel.sizeThatFits(CGSize(width: Self.maxNameWidth, height: CGFloat.greatestFiniteMagnitude))
        let nameWidth = min(nameSize.width, Self.maxNameWidth).rounded(.up)
        let countSize = countLabel.sizeThatFits(CGSize(width: 80, height: CGFloat.greatestFiniteMagnitude))
        let badgeHeight = max(Self.badgeHeight, countSize.height.rounded(.up) + 6)
        let badgeWidth = max(badgeHeight, countSize.width.rounded(.up) + 10)
        let height = max(Self.minHeight, badgeHeight + 10, nameSize.height.rounded(.up) + 10)
        let width = Self.horizontalPadding + nameWidth + Self.gap + badgeWidth + Self.horizontalPadding - 4

        let tapHeight = max(height, Self.minTapHeight)
        bounds = CGRect(x: 0, y: 0, width: width, height: tapHeight)
        pill.frame = CGRect(x: 0, y: (tapHeight - height) / 2, width: width, height: height)
        pill.layer.cornerRadius = height / 2
        nameLabel.frame = CGRect(
            x: Self.horizontalPadding, y: (height - nameSize.height) / 2, width: nameWidth, height: nameSize.height
        )
        countBadge.frame = CGRect(
            x: Self.horizontalPadding + nameWidth + Self.gap, y: (height - badgeHeight) / 2,
            width: badgeWidth, height: badgeHeight
        )
        countBadge.layer.cornerRadius = badgeHeight / 2
        countLabel.frame = countBadge.bounds
        centerOffset = .zero

        displayPriority = .required
        zPriority = .defaultUnselected
        accessibilityLabel = annotation.spokenLabel
    }
}
