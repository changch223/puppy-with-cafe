import SwiftUI

/// ピンを選んだときに一覧シートの中身が変わる「店のカード」（再設計 段階1a）。
/// 写真 or 頭文字タイル・店名・タグ・条件の要点・営業の行・徒歩の目安と、経路／電話／保存、「詳しく見る」。
/// 一覧に戻す（✕）と、シートは元の段に戻る。
struct PlaceCardView: View {
    let item: CafeWithDistance
    let isFavorite: Bool
    let now: Date
    let containerHeight: CGFloat
    let onShowDetail: () -> Void
    let onOpenRoute: () -> Void
    let onToggleFavorite: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    private var cafe: Cafe { item.cafe }
    private var walking: WalkingTime.Summary { WalkingTime.summary(meters: item.distanceMeters) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    CafeThumbnailView(cafe: cafe, size: 72)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(cafe.name)
                            .font(.headline)
                            .lineLimit(2)
                        CafeTagsView(cafe: cafe)
                        if let condition = CafePresentation.conditionSummary(for: cafe) {
                            Text(condition)
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                                .lineLimit(2)
                        }
                        HStack(spacing: 8) {
                            OpenLineView(line: OpenLine.make(hours: cafe.hours, at: now))
                            Text(walkingText)
                                .font(.caption.bold())
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text("閉じて一覧に戻る"))
                }

                HStack(spacing: 8) {
                    Button(action: onOpenRoute) {
                        Label(String(localized: "経路"), systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                    .buttonStyle(BrandProminentButtonStyle())

                    if let phoneURL = PhoneLink.url(for: cafe.phone) {
                        Button {
                            openURL(phoneURL)
                        } label: {
                            Label(String(localized: "電話"), systemImage: "phone.fill")
                        }
                        .buttonStyle(BrandSecondaryButtonStyle())
                        .accessibilityLabel(Text("\(cafe.name)に電話する"))
                    }

                    Button(action: onToggleFavorite) {
                        Label(
                            isFavorite ? String(localized: "保存済み") : String(localized: "保存"),
                            systemImage: isFavorite ? "pawprint.fill" : "pawprint"
                        )
                    }
                    .buttonStyle(BrandSecondaryButtonStyle())
                    .accessibilityLabel(Text(isFavorite ? "保存を外す" : "保存する"))
                }

                Button(action: onShowDetail) {
                    HStack {
                        Text("詳しく見る")
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityLabel(Text("\(cafe.name)の詳細を見る"))
            }
            .padding(16)
        }
        .frame(height: CafeSheetDetent.cardHeight(containerHeight: containerHeight))
        .sheetChrome()
        .accessibilityElement(children: .contain)
    }

    private var walkingText: String {
        if let detail = walking.detail { return "\(walking.headline)・\(detail)" }
        return walking.headline
    }
}
