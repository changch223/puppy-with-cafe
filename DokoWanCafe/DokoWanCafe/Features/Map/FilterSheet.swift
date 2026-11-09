import SwiftUI

/// 「絞り込み」シート（さがす体験 第3弾）: 席・犬・時間・その他の条件をまとめて選ぶ。
/// トグルは下書き（`FilterDraft`）だけを変え、下の「◯件を表示」で ViewModel に反映して閉じる。
/// スワイプなどで閉じたときは下書きを捨てる（反映しない）。下のボタンの件数は、下書きの条件で今の結果をその場で数える。
/// 0件のときは、オンの条件を1つずつ外した件数を数え、いちばん増えるものを1行で案内する（押すと下書きから外す）。
struct FilterSheet: View {
    @ObservedObject var viewModel: CafeListViewModel
    /// 「いつ行く？」の行を押した（下書きを反映してこのシートを閉じ、親が「いつ行く？」シートを開く）
    let onOpenPlan: () -> Void
    /// 「うちの子を設定する」の行を押した（下書きを反映してこのシートを閉じ、親が設定を開く）
    let onNeedMyDog: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 編集中の下書き（シートを開いた時点の今の条件から始める）
    @State private var draft: FilterDraft

    init(viewModel: CafeListViewModel, onOpenPlan: @escaping () -> Void, onNeedMyDog: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onOpenPlan = onOpenPlan
        self.onNeedMyDog = onNeedMyDog
        _draft = State(initialValue: viewModel.filterDraft)
    }

    private var hasMyDog: Bool { viewModel.dogProfile != nil }
    private var isTargetTime: Bool { viewModel.isTargetTime }
    private var targetLabel: String? { viewModel.targetTime.map(TargetTime.shortLabel) }

    var body: some View {
        let count = viewModel.displayCount(for: draft)
        // 条件をすべて外しても0件（対象エリア外・読み込み前など）なら、0件の理由は条件ではない
        let hasAnyResult = count > 0 || viewModel.hasAnyResultIgnoringConditions
        // 条件による0件のときだけ、外すと増える条件を探す（件数が増えるものがなければ nil）
        let relaxation = count == 0 && hasAnyResult ? draft.bestRelaxation(count: viewModel.displayCount(for:)) : nil
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                seatSection
                dogSection
                timeSection
                otherSection
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar(count: count, hasAnyResult: hasAnyResult, relaxation: relaxation)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 見出し

    private var header: some View {
        // 大きな文字では「クリア」が縦に折れないよう、見出しの下に回す
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout())
        return layout {
            Text("絞り込み")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Button {
                draft = FilterDraft()
            } label: {
                Text("クリア")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brand)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("条件をすべてクリア"))
        }
    }

    // MARK: - 区分

    private var seatSection: some View {
        section(title: String(localized: "席")) {
            toggleRow(String(localized: "店内OK"), isOn: $draft.amenities.indoorOnly)
            toggleRow(String(localized: "テラス"), isOn: $draft.amenities.terraceOnly)
        }
    }

    private var dogSection: some View {
        section(title: String(localized: "犬")) {
            if hasMyDog {
                toggleRow(String(localized: "うちの子OK"), isOn: $draft.myDogOnly)
            } else {
                navigationRow(
                    title: String(localized: "うちの子を設定する"),
                    value: nil,
                    hint: String(localized: "うちの子の設定を開きます"),
                    action: {
                        viewModel.apply(draft)
                        onNeedMyDog()
                        dismiss()
                    }
                )
            }
            toggleRow(String(localized: "大型犬OK"), isOn: $draft.amenities.largeDogOnly)
            toggleRow(String(localized: "犬メニュー"), isOn: $draft.amenities.dogMenuOnly)
        }
    }

    private var timeSection: some View {
        section(title: String(localized: "時間")) {
            toggleRow(
                isTargetTime ? String(localized: "その時間に営業") : String(localized: "営業中"),
                isOn: $draft.openNowOnly
            )
            navigationRow(
                title: String(localized: "いつ行く？"),
                value: targetLabel ?? String(localized: "今"),
                hint: String(localized: "日時を選ぶシートを開きます"),
                action: {
                    viewModel.apply(draft)
                    onOpenPlan()
                    dismiss()
                }
            )
        }
    }

    private var otherSection: some View {
        section(title: String(localized: "その他")) {
            toggleRow(String(localized: "未確認の店も表示"), isOn: $draft.includeUnverified)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content()
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.body)
        }
        .tint(Color.brand)
        .frame(minHeight: 44)
    }

    /// 押すと別の画面へ進む行（右に今の値と矢印）
    private func navigationRow(title: String, value: String?, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let value {
                    Text(value)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(value.map { "\(title) \($0)" } ?? title))
        .accessibilityHint(Text(hint))
    }

    // MARK: - 下のボタン

    private func bottomBar(count: Int, hasAnyResult: Bool, relaxation: FilterDraft.Relaxation?) -> some View {
        VStack(spacing: 8) {
            if let relaxation {
                Button {
                    draft = draft.removing(relaxation.condition)
                } label: {
                    Text(relaxation.title(isTargetTime: isTargetTime))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(BrandSecondaryButtonStyle())
            }
            Button {
                viewModel.apply(draft)
                dismiss()
            } label: {
                Text(FilterDraft.applyButtonTitle(count: count, hasAnyResult: hasAnyResult))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(BrandProminentButtonStyle())
            // 条件による0件のときだけ押せなくする（母数が0のときは条件を反映できるように）
            .disabled(count == 0 && hasAnyResult)
            .opacity(count == 0 && hasAnyResult ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}
