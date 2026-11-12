import SwiftUI
import UIKit

/// 写真がない店のタイル。ピンと同じ絵柄（席の種類）を、カテゴリの色を薄くした背景の上に置く。
struct CategoryTileView: View {
    let cafe: Cafe
    let size: CGFloat

    var body: some View {
        let category = MapPinCategory.category(for: cafe)
        let color = Color(MapPinRenderer.fillColor(for: category))
        color.opacity(0.18)
            .overlay {
                Image(systemName: category.symbolName)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// 店の写真（`LinkPreviewService` のキャッシュ経由の画像のみ）。写真がない・取得できない店はカテゴリの絵柄のタイル。
/// スクロールで行が入れ替わっても `.task(id:)` が自動キャンセルする。
struct CafeThumbnailView: View {
    let cafe: Cafe
    var size: CGFloat = 64
    /// 写真を取りに行く（通信する）か。false（既定）はキャッシュにあるものだけを出す（一覧・検索候補。スクロールを軽くするため）。
    /// ピンのカード・詳細は true で取りに行き、取れた写真は次から一覧にも出る。
    var allowsNetwork = false

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
                CategoryTileView(cafe: cafe, size: size)
            }
        }
        .accessibilityHidden(true)
        .task(id: cafe.id) {
            image = nil
            guard let url = PhotoSourceResolver.previewSourceURL(for: cafe) else { return }
            let preview = await LinkPreviewService.shared.preview(for: url, allowNetwork: allowsNetwork)
            guard !Task.isCancelled else { return }
            image = preview?.image
        }
    }
}

/// タグ1つ（うちの子OK／店内OK／テラスのみ／条件を確認／未確認／大型犬OK）
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
        case .myDog: return Color.brand
        }
    }
}

/// タグの並び。幅が足りない（大きな文字サイズなど）ときは縦に積む。
struct CafeTagsView: View {
    let cafe: Cafe
    @Environment(\.dogProfile) private var dog

    var body: some View {
        let tags = CafePresentation.tags(for: cafe, dog: dog)
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

extension OpenLine.State {
    /// 営業の行の文字色。営業中だけブランド色、閉店が近いときは橙、それ以外はグレー（時間が不明な店で嘘をつかない）
    var lineColor: Color {
        switch self {
        case .open: return Color.brand
        case .closingSoon: return Color.cautionText
        case .outsideHours, .closedToday, .unknown: return Color(.secondaryLabel)
        }
    }
}

extension CafePresentation.AnswerLine.Tone {
    /// 答えの主文の色。店内OK＝ブランド色、テラス＝青、分からない・条件を確認＝橙、未確認・入れない＝グレー
    var color: Color {
        switch self {
        case .indoor: return Color.brand
        case .terrace: return Color.terraceText
        case .attention: return Color.cautionText
        case .unverified, .notAllowed: return Color(.secondaryLabel)
        }
    }
}

/// 営業の行。営業中だけブランド色、閉店が近いときは橙、それ以外はグレー（時間が不明な店で嘘をつかない）。
struct OpenLineView: View {
    let line: OpenLine

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(line.state.isOpen ? line.state.lineColor : Color(.secondaryLabel).opacity(0.5))
                .frame(width: 7, height: 7)
            Text(line.text)
                .font(.caption)
                .foregroundStyle(line.state.lineColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityHidden(true)
    }
}

/// 答えの1行（「うちの子は店内OK・床で待てる」）。主文は色つき・太め、補足は薄い色。色だけに頼らず文言で区別できる。
/// 大きな文字では折り返す。
struct AnswerLineView: View {
    let cafe: Cafe
    @Environment(\.dogProfile) private var dog

    var body: some View {
        let answer = CafePresentation.answerLine(for: cafe, dog: dog)
        Group {
            if let supplement = answer.supplement {
                Text(verbatim: answer.main).foregroundStyle(answer.tone.color).fontWeight(.semibold)
                    + Text(verbatim: "・").foregroundStyle(Color(.secondaryLabel))
                    + Text(verbatim: supplement).foregroundStyle(Color(.secondaryLabel))
            } else {
                Text(verbatim: answer.main).foregroundStyle(answer.tone.color).fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 一覧の行の3行目「営業中・18:00まで・徒歩約4分」。営業の部分だけ色を付け、距離は薄い色。大きな文字では折り返す。
struct OpenAndDistanceLineView: View {
    let line: OpenLine
    let walking: WalkingTime.Summary

    var body: some View {
        (Text(verbatim: line.text).foregroundStyle(line.state.lineColor)
            + Text(verbatim: "・").foregroundStyle(Color(.secondaryLabel))
            + Text(verbatim: walking.headline).foregroundStyle(Color(.secondaryLabel)))
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }
}
