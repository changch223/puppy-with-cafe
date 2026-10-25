import SwiftUI
import UIKit

/// 頭文字タイル（写真がない店の代替表示）。店名の1文字＋店IDから決まる落ち着いた色。
struct InitialTileView: View {
    let cafe: Cafe
    let size: CGFloat

    /// 落ち着いた色のパレット（白文字が読める濃さ）。番号は `InitialTile.colorIndex` が決める。
    private static let palette: [Color] = [
        Color(red: 0.36, green: 0.55, blue: 0.47),
        Color(red: 0.55, green: 0.48, blue: 0.38),
        Color(red: 0.42, green: 0.52, blue: 0.62),
        Color(red: 0.62, green: 0.45, blue: 0.40),
        Color(red: 0.50, green: 0.45, blue: 0.60),
        Color(red: 0.55, green: 0.55, blue: 0.36),
        Color(red: 0.38, green: 0.55, blue: 0.58),
        Color(red: 0.60, green: 0.42, blue: 0.50),
    ]

    var body: some View {
        Self.palette[InitialTile.colorIndex(for: cafe.id) % Self.palette.count]
            .overlay {
                Text(InitialTile.character(for: cafe.name))
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// 店の写真（`LinkPreviewService` のキャッシュ経由の画像のみ）。写真がない・取得できない店は頭文字タイル。
/// スクロールで行が入れ替わっても `.task(id:)` が自動キャンセルする。
struct CafeThumbnailView: View {
    let cafe: Cafe
    var size: CGFloat = 64

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
            } else {
                InitialTileView(cafe: cafe, size: size)
            }
        }
        .accessibilityHidden(true)
        .task(id: cafe.id) {
            image = nil
            guard let url = PhotoSourceResolver.previewSourceURL(for: cafe) else { return }
            let preview = await LinkPreviewService.shared.preview(for: url)
            guard !Task.isCancelled else { return }
            image = preview?.image
        }
    }
}

/// タグ1つ（店内OK／テラスのみ／条件を確認／未確認／大型犬OK）
struct CafeTagChip: View {
    let tag: CafeTag

    var body: some View {
        Text(tag.label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize()
    }

    private var tint: Color {
        switch tag.kind {
        case .category(let category): return category.tint
        case .largeDog: return Color(UIColor.systemIndigo)
        }
    }
}

/// タグの並び。幅が足りない（大きな文字サイズなど）ときは縦に積む。
struct CafeTagsView: View {
    let cafe: Cafe

    var body: some View {
        let tags = CafePresentation.tags(for: cafe)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(Array(tags.enumerated()), id: \.offset) { CafeTagChip(tag: $0.element) }
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(tags.enumerated()), id: \.offset) { CafeTagChip(tag: $0.element) }
            }
        }
    }
}

/// 営業の行。営業中だけブランド色、それ以外はグレー（時間が不明な店で嘘をつかない）。
struct OpenLineView: View {
    let line: OpenLine

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(line.state == .open ? Color.brand : Color(.secondaryLabel).opacity(0.5))
                .frame(width: 7, height: 7)
            Text(line.text)
                .font(.caption)
                .foregroundStyle(line.state == .open ? Color.brand : Color(.secondaryLabel))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityHidden(true)
    }
}
