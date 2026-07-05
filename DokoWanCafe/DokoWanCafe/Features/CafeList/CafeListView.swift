import MapKit
import SwiftUI

/// 一覧画面（T025）: 距離順・可否バッジ・距離表示（FR-002/005, SC-002）。
struct CafeListView: View {
    @ObservedObject var viewModel: CafeListViewModel

    var body: some View {
        List(viewModel.displayedResults) { item in
            NavigationLink(value: item.cafe) {
                CafeRowView(item: item)
            }
        }
        .listStyle(.plain)
        .accessibilityLabel(Text("周辺の犬同伴OKカフェ一覧（近い順）"))
    }
}

/// 一覧の1行: 詳細を開かなくても「可否」と「距離」が判別できる（SC-002）
struct CafeRowView: View {
    let item: CafeWithDistance

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.cafe.name)
                    .font(.headline)
                    .lineLimit(2)
                if let condition = item.cafe.dogPolicyCondition,
                   item.cafe.dogPolicyStatus == .conditional {
                    Text(condition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                // 営業状態（構造化営業時間のある店のみ, FR-102）
                OpenStateBadge(state: OpeningHoursEvaluator.state(hours: item.cafe.hours))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: item.cafe.dogPolicyStatus)
                Text(MapViewModel.distanceText(meters: item.distanceMeters))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            "\(item.cafe.name)、\(item.cafe.dogPolicyStatus.displayName)、\(MapViewModel.distanceText(meters: item.distanceMeters))"
        ))
    }
}
