import SwiftUI

/// 詳細の答えのカードの上の1行（再設計 段階3）:「うちの子（小型犬）は：店内で過ごせます」。
/// 入れると明記された店だけブランド色。入れない店は橙の注意色と印（直下の答えのカード＝犬全般の答えと区別する）。分からない店はグレー（憶測で OK を出さない, 憲章 原則I）。
/// 過ごし方が `indoor_style` に明記されていれば、その補足を下に小さく添える。うちの子が未設定なら何も出さない。
struct CafeDetailMyDogLine: View {
    let cafe: Cafe
    @Environment(\.dogProfile) private var dog

    var body: some View {
        if let dog {
            let result = DogFit.evaluate(cafe: cafe, dog: dog)
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(result.detailLine)
                        .font(.subheadline.bold())
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: symbol(for: result.overall))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(tint(for: result.overall))

                if let note = result.styleNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private func symbol(for overall: DogFit.Overall) -> String {
        switch overall {
        case .fits: return "dog.fill"
        case .doesNotFit: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private func tint(for overall: DogFit.Overall) -> Color {
        switch overall {
        case .fits: return Color.brand
        case .doesNotFit: return Color.cafeDetailOrange
        case .unknown: return Color(.secondaryLabel)
        }
    }
}
