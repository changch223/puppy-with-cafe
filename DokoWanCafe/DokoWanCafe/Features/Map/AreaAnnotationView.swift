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
/// 札は小さめ（高さ 34pt）にして、重なりで間引かれるエリアを減らす。タップ領域だけ上下に広げて 44pt 以上にする。文字色は面に対して 4.5:1 以上（名前は `label`、件数はブランド色の上の `onBrand`）。
final class AreaAnnotationView: MKAnnotationView {
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
        clusteringIdentifier = nil
        backgroundColor = .systemBackground
        layer.borderWidth = 1.5
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 1)

        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.textColor = .label
        nameLabel.isAccessibilityElement = false
        addSubview(nameLabel)

        countBadge.backgroundColor = .brand
        countBadge.isAccessibilityElement = false
        addSubview(countBadge)
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

    /// 見た目は 34pt でも、タップは上下に広げて 44pt 以上で受ける
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let extra = max(0, (Self.minTapHeight - bounds.height) / 2)
        return bounds.insetBy(dx: 0, dy: -extra).contains(point)
    }

    private func updateBorderColor() {
        layer.borderColor = UIColor.brand.resolvedColor(with: traitCollection).cgColor
    }

    func configure(with annotation: AreaAnnotation) {
        let summary = annotation.summary
        nameLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 12, weight: .bold))
        nameLabel.text = summary.name
        countLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 12, weight: .bold))
        countLabel.text = "\(summary.count)"

        let nameSize = nameLabel.sizeThatFits(CGSize(width: Self.maxNameWidth, height: CGFloat.greatestFiniteMagnitude))
        let nameWidth = min(nameSize.width, Self.maxNameWidth).rounded(.up)
        let countSize = countLabel.sizeThatFits(CGSize(width: 80, height: CGFloat.greatestFiniteMagnitude))
        let badgeHeight = max(Self.badgeHeight, countSize.height.rounded(.up) + 6)
        let badgeWidth = max(badgeHeight, countSize.width.rounded(.up) + 10)
        let height = max(Self.minHeight, badgeHeight + 10, nameSize.height.rounded(.up) + 10)
        let width = Self.horizontalPadding + nameWidth + Self.gap + badgeWidth + Self.horizontalPadding - 4

        bounds = CGRect(x: 0, y: 0, width: width, height: height)
        layer.cornerRadius = height / 2
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

        displayPriority = MKFeatureDisplayPriority(rawValue: Float(250 + 700 * annotation.priority))
        zPriority = .defaultUnselected
        accessibilityLabel = annotation.spokenLabel
    }
}
