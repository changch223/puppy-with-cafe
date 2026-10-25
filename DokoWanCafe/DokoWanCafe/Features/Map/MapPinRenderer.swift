import UIKit

/// 地図ピンの画像を描いてキャッシュする（毎回描かない）。
/// 形（丸／角丸四角／しずく）と色の両方で区別し、中に白い肉球を置く。保存済みは白い縁を太く、選択中は大きくする。
/// 描画とキャッシュはメインスレッドから呼ぶ前提。薄く見せる（営業時間外）処理は画像ではなく表示側の alpha で行うので、画像は可否の分類×保存×選択だけでキャッシュできる。
enum MapPinRenderer {
    private struct Key: Hashable {
        let category: MapPinCategory
        let isFavorite: Bool
        let isSelected: Bool
    }

    private static var cache: [Key: UIImage] = [:]

    static let baseSize: CGFloat = 30
    static let selectedScale: CGFloat = 1.35
    /// 影のための余白
    private static let padding: CGFloat = 4

    /// 可否の分類ごとのピン色（固定色。ライト・ダークどちらの地図でも見分けられる濃さ）
    static func fillColor(for category: MapPinCategory) -> UIColor {
        switch category {
        case .indoorOK: return UIColor(red: 0x23 / 255, green: 0x73 / 255, blue: 0x5A / 255, alpha: 1)
        case .terraceOnly: return UIColor(red: 0x1B / 255, green: 0x8F / 255, blue: 0x9C / 255, alpha: 1)
        case .checkDetail: return UIColor(red: 0xE0 / 255, green: 0x7B / 255, blue: 0x1F / 255, alpha: 1)
        case .unverified: return UIColor(red: 0x7A / 255, green: 0x7F / 255, blue: 0x85 / 255, alpha: 1)
        }
    }

    static func image(for style: MapPinStyle, isSelected: Bool = false) -> UIImage {
        let key = Key(category: style.category, isFavorite: style.isFavorite, isSelected: isSelected)
        if let cached = cache[key] { return cached }
        let image = draw(category: style.category, isFavorite: style.isFavorite, isSelected: isSelected)
        cache[key] = image
        return image
    }

    /// 地図上の座標にピンの先端（しずく）または中心（丸・四角）を合わせるための offset
    static func centerOffset(for style: MapPinStyle, image: UIImage) -> CGPoint {
        switch style.shape {
        case .circle, .roundedSquare, .diamond: return .zero
        case .teardrop: return CGPoint(x: 0, y: -(image.size.height / 2 - padding))
        }
    }

    private static func draw(category: MapPinCategory, isFavorite: Bool, isSelected: Bool) -> UIImage {
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

            // 白い肉球（丸い部分の中央）
            let glyphSide = (shape == .teardrop ? inner.width : min(inner.width, inner.height)) * (shape == .diamond ? 0.5 : 0.52)
            let center = CGPoint(x: inner.midX, y: shape == .teardrop ? inner.minY + inner.width / 2 : inner.midY)
            let configuration = UIImage.SymbolConfiguration(pointSize: glyphSide, weight: .bold)
            if let paw = UIImage(systemName: "pawprint.fill", withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let fitted = aspectFit(paw.size, in: CGSize(width: glyphSide, height: glyphSide))
                paw.draw(in: CGRect(
                    x: center.x - fitted.width / 2, y: center.y - fitted.height / 2,
                    width: fitted.width, height: fitted.height
                ))
            }
        }
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
