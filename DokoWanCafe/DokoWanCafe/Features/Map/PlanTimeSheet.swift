import SwiftUI

/// 「いつ行く？」シート（再設計 段階2）: 日（今・今日・明日・その先5日の曜日）と時刻（朝・昼・午後・夜＋30分刻み）を選ぶと、
/// その時刻に開いている店だけを表示する。下のボタンに件数を出す（今の他の条件を含めて数える）。
/// 決めた時刻は保存しない（アプリを開き直したら「今」）。
struct PlanTimeSheet: View {
    @ObservedObject var viewModel: CafeListViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 選択肢を組み立てた時点の「今」（シートを開いている間は動かさない）
    private let now: Date
    /// 選んだ日（今日からの日数）。nil は「今」
    @State private var dayOffset: Int?
    /// 選んだ時刻（その日0時からの分）
    @State private var minutes: Int

    init(viewModel: CafeListViewModel) {
        self.viewModel = viewModel
        let now = Date()
        self.now = now
        if let target = viewModel.targetTime, let selection = TargetTime.selection(of: target, now: now) {
            _dayOffset = State(initialValue: selection.dayOffset)
            _minutes = State(initialValue: selection.minutes)
        } else {
            _dayOffset = State(initialValue: nil)
            _minutes = State(initialValue: TargetTime.defaultMinutes)
        }
    }

    /// 今の選択から組み立てた対象時刻（「今」は nil）
    private var draftTarget: Date? {
        guard let dayOffset else { return nil }
        return TargetTime.date(dayOffset: dayOffset, minutes: minutes, now: now)
    }

    var body: some View {
        let target = draftTarget
        let count = viewModel.openCount(at: target)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("いつ行く？")
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: reset) {
                        Text("リセット")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.brand)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(Text("リセットして今に戻す"))
                }

                daySelector

                if dayOffset != nil {
                    timeSelector
                } else {
                    Text("今この時間に開いているお店を表示します")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.applyTargetTime(target)
                    dismiss()
                } label: {
                    Text(TargetTime.applyButtonTitle(target: target, count: count))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(BrandProminentButtonStyle())
                .disabled(count == 0)
                .opacity(count == 0 ? 0.5 : 1)
            }
            .padding(16)
        }
        // 大きな文字では中身が収まるよう、全画面まで開く
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 日

    private var daySelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DayChip(title: String(localized: "今"), subtitle: nil, isSelected: dayOffset == nil) {
                        dayOffset = nil
                    }
                    .id(-1)
                    ForEach(TargetTime.dayOptions(now: now)) { option in
                        DayChip(title: option.title, subtitle: option.dateText, isSelected: dayOffset == option.offset) {
                            dayOffset = option.offset
                        }
                        .id(option.offset)
                    }
                }
            }
            // 画面外の日（その先の曜日）を選んでいるときは、見える位置までスクロールする
            .onAppear { proxy.scrollTo(dayOffset ?? -1, anchor: .center) }
        }
    }

    // MARK: - 時刻

    private var timeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 大きな文字では2列×2段にして、ラベルが切れないようにする
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4),
                spacing: 8
            ) {
                ForEach(TargetTime.presets) { preset in
                    Button {
                        minutes = preset.minutes
                    } label: {
                        Text(preset.label)
                            .font(.subheadline.bold())
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.7)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(minutes == preset.minutes ? Color.onBrand : Color.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                Capsule().fill(minutes == preset.minutes ? Color.brand : Color(.secondarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(preset.label))
                    .accessibilityAddTraits(minutes == preset.minutes ? .isSelected : [])
                }
            }

            Picker(String(localized: "時刻"), selection: $minutes) {
                ForEach(TargetTime.timeChoices, id: \.self) { value in
                    Text(TargetTime.timeText(minutes: value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            // ホイールの文字も大きくなるので、大きな文字では高さを広げる
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 180 : 96)
            .clipped()
            .accessibilityLabel(Text("時刻（30分刻み）"))
        }
    }

    private func reset() {
        dayOffset = nil
        minutes = TargetTime.defaultMinutes
        viewModel.clearTargetTime()
    }
}

/// 日の選択肢1つ（「今」「今日」「土」…。小さく日付を添える）
private struct DayChip: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.subheadline.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                }
            }
            .lineLimit(1)
            .foregroundStyle(isSelected ? Color.onBrand : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minWidth: 52, minHeight: 52)
            .background(Capsule().fill(isSelected ? Color.brand : Color(.secondarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(subtitle.map { "\(title) \($0)" } ?? title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
