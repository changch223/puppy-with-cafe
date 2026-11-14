import SwiftUI
import UIKit

/// 写真がない店のタイル。ピンと同じ文字・絵柄（席の種類）を、カテゴリの色を薄くした背景の上に置く。
struct CategoryTileView: View {
    let cafe: Cafe
    let size: CGFloat
    @Environment(\.dogProfile) private var dog

    var body: some View {
        // うちの子が入れない席をタイルが言わないよう、同じ行の答えと同じ判定にそろえる
        let category = CafePresentation.tileCategory(for: cafe, dog: dog)
        let color = Color(MapPinRenderer.fillColor(for: category))
        color.opacity(MapPinRenderer.tileBackgroundOpacity(for: category))
            .overlay {
                Group {
                    if let lines = category.pinLines {
                        // ピンと同じ2行の文字（「店内／OK」「テラス／OK」）。タイルの大きさに合わせた固定の大きさ
                        VStack(spacing: -size * 0.03) {
                            ForEach(lines, id: \.self) { line in
                                Text(verbatim: line)
                                    .font(.system(size: size * (line.count > 2 ? 0.25 : 0.29), weight: .heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    } else if let symbolName = category.symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: size * 0.42, weight: .bold))
                    }
                }
                .foregroundStyle(Color(MapPinRenderer.tileGlyphColor(for: category)))
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
        // 通信してよいかが変わったとき（横にめくった先のカードが選ばれたとき）も取り直す
        .task(id: "\(cafe.id.uuidString)-\(allowsNetwork)") {
            image = nil
            guard let url = PhotoSourceResolver.previewSourceURL(for: cafe) else { return }
            let preview = await LinkPreviewService.shared.preview(for: url, allowNetwork: allowsNetwork)
            guard !Task.isCancelled else { return }
            image = preview?.image
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
/// 標準〜xxxLarge の文字サイズでは、「主文＋補足」が1行に入ればそのまま、入らなければ補足を2行目に送る（幅375ptの機種など。補足を落とさない）。
/// 主文だけで入りきらなければ末尾を省略する（VoiceOver は行全体の読み上げラベルが `CafePresentation.answerLine(...).spoken`）。
/// アクセシビリティサイズでは折り返して全文を出す。
struct AnswerLineView: View {
    let cafe: Cafe
    @Environment(\.dogProfile) private var dog
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let answer = CafePresentation.answerLine(for: cafe, dog: dog)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                full(answer).fixedSize(horizontal: false, vertical: true)
            } else {
                ViewThatFits(in: .horizontal) {
                    if answer.supplement != nil {
                        full(answer).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    }
                    // 補足は2行目へ（主文は1行目）。補足がなければ主文だけ
                    VStack(alignment: .leading, spacing: 0) {
                        main(answer).lineLimit(1).minimumScaleFactor(0.9)
                        if let supplement = answer.supplement {
                            Text(verbatim: supplement)
                                .foregroundStyle(Color(.secondaryLabel))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .font(.subheadline)
    }

    private func main(_ answer: CafePresentation.AnswerLine) -> Text {
        Text(verbatim: answer.main).foregroundStyle(answer.tone.color).fontWeight(.semibold)
    }

    private func full(_ answer: CafePresentation.AnswerLine) -> Text {
        guard let supplement = answer.supplement else { return main(answer) }
        return main(answer)
            + Text(verbatim: "・").foregroundStyle(Color(.secondaryLabel))
            + Text(verbatim: supplement).foregroundStyle(Color(.secondaryLabel))
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
