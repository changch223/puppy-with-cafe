import UIKit

/// 地図ピンの画像を描いてキャッシュする（毎回描かない）。
/// 形（丸／角丸四角／しずく／菱形）と色の両方で区別し、中に席の種類の白い絵柄（`MapPinCategory.symbolName`。店内OK＝フォークとナイフ＋「OK」、テラス＝太陽＋「テラス」、条件を確認＝？、未確認＝肉球）を置く。保存済みは白い縁を太く、選択中は大きくする。
/// 同じ場所に複数の店があるとき（`count` が2以上）は、右上に数のバッジ（白地の丸に濃い文字。10以上は「9+」）を付ける。
/// 描画とキャッシュはメインスレッドから呼ぶ前提。薄く見せる（営業時間外）処理は画像ではなく表示側の alpha で行うので、画像は可否の分類×保存×選択×バッジの数だけでキャッシュできる。
enum MapPinRenderer {
    private struct Key: Hashable {
        let category: MapPinCategory
        let isFavorite: Bool
        let isSelected: Bool
        /// バッジの数（10以上は同じ「9+」なので10にそろえる。1はバッジなし）
        let count: Int
    }

    private static var cache: [Key: UIImage] = [:]

    static let baseSize: CGFloat = 36
    static let selectedScale: CGFloat = 1.35
    /// 影のための余白
    private static let padding: CGFloat = 4
    /// バッジが付くときの余白の増分（バッジがピンの右上へはみ出すぶん。上下左右そろえて増やし、ピンの中心を画像の中心に保つ）
    private static let badgeExtraPadding: CGFloat = 3
    private static let badgeHeight: CGFloat = 17
    /// バッジがピンの角からはみ出す量
    private static let badgeOverhang: CGFloat = 4

    /// バッジの数字（10以上は「9+」）
    static func badgeText(count: Int) -> String {
        count >= 10 ? "9+" : "\(count)"
    }

    private static func pad(count: Int) -> CGFloat {
        count > 1 ? padding + badgeExtraPadding : padding
    }

    /// 可否の分類ごとのピン色（固定色。ライト・ダークどちらの地図でも見分けられる濃さ）
    static func fillColor(for category: MapPinCategory) -> UIColor {
        switch category {
        case .indoorOK: return UIColor(red: 0x23 / 255, green: 0x73 / 255, blue: 0x5A / 255, alpha: 1)
        case .terraceOnly: return UIColor(red: 0x1F / 255, green: 0x7F / 255, blue: 0xB5 / 255, alpha: 1)
        case .checkDetail: return UIColor(red: 0xE0 / 255, green: 0x7B / 255, blue: 0x1F / 255, alpha: 1)
        case .unverified: return UIColor(red: 0x7A / 255, green: 0x7F / 255, blue: 0x85 / 255, alpha: 1)
        }
    }

    static func image(for style: MapPinStyle, isSelected: Bool = false, count: Int = 1) -> UIImage {
        let key = Key(category: style.category, isFavorite: style.isFavorite, isSelected: isSelected, count: min(max(count, 1), 10))
        if let cached = cache[key] { return cached }
        let image = draw(category: style.category, isFavorite: style.isFavorite, isSelected: isSelected, count: key.count)
        cache[key] = image
        return image
    }

    /// 地図上の座標にピンの先端（しずく）または中心（丸・四角）を合わせるための offset
    static func centerOffset(for style: MapPinStyle, image: UIImage, count: Int = 1) -> CGPoint {
        switch style.shape {
        case .circle, .roundedSquare, .diamond: return .zero
        case .teardrop: return CGPoint(x: 0, y: -(image.size.height / 2 - pad(count: count)))
        }
    }

    private static func draw(category: MapPinCategory, isFavorite: Bool, isSelected: Bool, count: Int) -> UIImage {
        let padding = pad(count: count)
        let shape = category.pinShape
        let size = baseSize * (isSelected ? selectedScale : 1)
        let height = shape == .teardrop ? size * 1.28 : size
        let border: CGFloat = isFavorite ? 4 : 1.5
        let canvas = CGSize(width: size + padding * 2, height: height + padding * 2)
        let outer = CGRect(x: padding, y: padding, width: size, height: height)
        let inner = outer.insetBy(dx: border, dy: border)

        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { context in
            let cg = context.cgContext

            // 縁（白）＋影
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            UIColor.white.setFill()
            path(for: shape, in: outer).fill()
            cg.restoreGState()

            // 本体の色
            fillColor(for: category).setFill()
            path(for: shape, in: inner).fill()

            // 白い絵柄（丸い部分の中央）
            let glyphSide = (shape == .teardrop ? inner.width : min(inner.width, inner.height)) * (shape == .diamond ? 0.5 : 0.52)
            let center = CGPoint(x: inner.midX, y: shape == .teardrop ? inner.minY + inner.width / 2 : inner.midY)
            if let caption = category.pinCaption {
                // 絵柄（上）＋短い文字（下）。文字は内側の幅に収まるまで小さくする
                let side = min(inner.width, inner.height)
                let captionText = fittedCaption(caption, maxWidth: side * 0.84, preferredSize: side * (caption.count > 2 ? 0.27 : 0.34))
                let captionSize = captionText.size()
                let iconSide = side * 0.38
                let gap = side * 0.01
                let total = iconSide + gap + captionSize.height
                let top = center.y - total / 2 + side * 0.02
                let configuration = UIImage.SymbolConfiguration(pointSize: iconSide, weight: .bold)
                if let glyph = UIImage(systemName: category.symbolName, withConfiguration: configuration)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let fitted = aspectFit(glyph.size, in: CGSize(width: iconSide, height: iconSide))
                    glyph.draw(in: CGRect(
                        x: center.x - fitted.width / 2, y: top + (iconSide - fitted.height) / 2,
                        width: fitted.width, height: fitted.height
                    ))
                }
                captionText.draw(at: CGPoint(x: center.x - captionSize.width / 2, y: top + iconSide + gap))
            } else {
                let configuration = UIImage.SymbolConfiguration(pointSize: glyphSide, weight: .bold)
                if let glyph = UIImage(systemName: category.symbolName, withConfiguration: configuration)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let fitted = aspectFit(glyph.size, in: CGSize(width: glyphSide, height: glyphSide))
                    glyph.draw(in: CGRect(
                        x: center.x - fitted.width / 2, y: center.y - fitted.height / 2,
                        width: fitted.width, height: fitted.height
                    ))
                }
            }

            if count > 1 { drawBadge(count: count, pinRect: outer, in: cg) }
        }
    }

    /// ピンの中の短い文字（白・太字）。`maxWidth` に収まるまで文字を小さくする
    private static func fittedCaption(_ text: String, maxWidth: CGFloat, preferredSize: CGFloat) -> NSAttributedString {
        var size = preferredSize
        var result = NSAttributedString()
        repeat {
            result = NSAttributedString(string: text, attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: .heavy),
                .foregroundColor: UIColor.white,
            ])
            size -= 0.5
        } while result.size().width > maxWidth && size > 5
        return result
    }

    /// 右上の数のバッジ（白地の丸＋濃い文字）。ピンの右上の角から少しはみ出させる
    private static func drawBadge(count: Int, pinRect: CGRect, in cg: CGContext) {
        let text = NSAttributedString(string: badgeText(count: count), attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .heavy),
            .foregroundColor: UIColor(white: 0.12, alpha: 1),
        ])
        let textSize = text.size()
        let width = max(badgeHeight, ceil(textSize.width) + 8)
        let rect = CGRect(
            x: pinRect.maxX + badgeOverhang - width, y: pinRect.minY - badgeOverhang,
            width: width, height: badgeHeight
        )
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.35).cgColor)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: badgeHeight / 2).fill()
        cg.restoreGState()
        UIColor(white: 0.12, alpha: 0.35).setStroke()
        let outline = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: badgeHeight / 2)
        outline.lineWidth = 1
        outline.stroke()
        text.draw(at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
    }

    private static func aspectFit(_ size: CGSize, in box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return box }
        let scale = min(box.width / size.width, box.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private static func path(for shape: MapPinShape, in rect: CGRect) -> UIBezierPath {
        switch shape {
        case .circle:
            return UIBezierPath(ovalIn: rect)
        case .roundedSquare:
            return UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.3)
        case .diamond:
            // 角を丸めた正方形を45度回した菱形（対角線が rect の幅にほぼ合う大きさ）
            let side = rect.width * 0.78
            let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
            let path = UIBezierPath(roundedRect: square, cornerRadius: side * 0.18)
            var transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            transform = transform.rotated(by: .pi / 4).translatedBy(x: -rect.midX, y: -rect.midY)
            path.apply(transform)
            return path
        case .teardrop:
            // 上が円、下が先端の1本の閉じた経路（縁を均一に引くため）
            let radius = rect.width / 2
            let center = CGPoint(x: rect.midX, y: rect.minY + radius)
            let tip = CGPoint(x: rect.midX, y: rect.maxY)
            let distance = tip.y - center.y
            let beta = acos(min(radius / max(distance, radius + 0.01), 1))
            let right = CGFloat.pi / 2 - beta
            let left = CGFloat.pi / 2 + beta
            let path = UIBezierPath()
            path.move(to: tip)
            path.addLine(to: CGPoint(x: center.x + radius * cos(right), y: center.y + radius * sin(right)))
            path.addArc(withCenter: center, radius: radius, startAngle: right, endAngle: left, clockwise: false)
            path.close()
            return path
        }
    }
}
