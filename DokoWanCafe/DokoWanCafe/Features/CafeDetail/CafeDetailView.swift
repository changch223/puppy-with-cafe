import SwiftUI

/// カフェ詳細画面（T032/T035/T046/T047/T048/T050）。
/// 可否・条件・出典・最終確認日を提示し（US2）、矛盾と AI 推測を明示区別する（US4）。
struct CafeDetailView: View {
    @StateObject private var viewModel: CafeDetailViewModel
    private let dependencies: AppDependencies
    @State private var showReport = false

    init(cafe: Cafe, dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: CafeDetailViewModel(cafe: cafe, repository: dependencies.repository)
        )
    }

    var body: some View {
        List {
            headerSection

            if viewModel.cafe.dogAmenities != nil || viewModel.cafe.dogNote != nil {
                amenitiesSection
            }

            if viewModel.cafe.hours?.hasAnyDay == true || viewModel.cafe.hoursText != nil {
                hoursSection
            }

            if viewModel.hasConflict {
                conflictSection
            }

            if !viewModel.sources.isEmpty {
                sourcesSection
            }

            infoSection

            if viewModel.cafe.links?.isEmpty == false || viewModel.cafe.operatorNote != nil {
                linksSection
            }

            actionSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.cafe.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .sheet(isPresented: $showReport) {
            ReportView(cafe: viewModel.cafe)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - 可否・鮮度（US2）

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.cafe.name)
                            .font(.title3.bold())
                        if let subArea = viewModel.cafe.subArea {
                            Label(subArea, systemImage: "mappin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    StatusBadge(status: viewModel.cafe.dogPolicyStatus, prominent: true)
                }

                // 店舗紹介（002/FR-107）
                if let description = viewModel.cafe.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 条件付きの条件は必ず読める形で提示（FR-007）
                if viewModel.cafe.dogPolicyStatus == .conditional,
                   let condition = viewModel.cafe.dogPolicyCondition {
                    Label(condition, systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }

                // 出典・最終確認日の併記（FR-008）
                if let lastVerified = viewModel.cafe.lastVerified {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal")
                        Text("最終確認日: \(lastVerified.formatted(date: .abbreviated, time: .omitted))")
                        if let representative = viewModel.representativeSource {
                            Text("（出典: \(representative.type.displayName)）")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                // 未確認情報の明示区別（FR-009/T035）
                if viewModel.isUnverified {
                    warningBox(
                        text: String(localized: "この情報は未確認です。出典・確認日のある確定情報ではありません。ご来店前に店舗へ直接ご確認ください。"),
                        systemImage: "questionmark.circle",
                        color: .gray
                    )
                }

                // 古い情報の警告（FR-010/T033）
                if viewModel.isStale && !viewModel.isUnverified {
                    warningBox(
                        text: String(localized: "この情報は最終確認から1年以上経過しています。最新でない可能性があります。"),
                        systemImage: "clock.badge.exclamationmark",
                        color: .orange
                    )
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - 犬向け設備（002/FR-101/104, T108）

    private var amenitiesSection: some View {
        Section {
            if let amenities = viewModel.cafe.dogAmenities {
                HStack(spacing: 8) {
                    AmenityBadge(label: String(localized: "店内OK"), value: amenities.indoor)
                    AmenityBadge(label: String(localized: "テラスOK"), value: amenities.terrace)
                    AmenityBadge(label: String(localized: "大型犬OK"), value: amenities.largeDogs)
                    AmenityBadge(label: String(localized: "犬メニュー"), value: amenities.dogMenu)
                }
                .padding(.vertical, 4)
            }
            // サイズ制限（002/FR-107。例: 小型・中型のみ、抱っこ・カート推奨）
            if let sizeLimit = viewModel.cafe.dogSizeLimit {
                LabeledContent {
                    Text(sizeLimit)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("サイズ")
                }
                .font(.footnote)
            }
            if let note = viewModel.cafe.dogNote {
                Label(note, systemImage: "pawprint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("わんちゃん向け情報")
        }
    }

    // MARK: - 営業時間（002/FR-102, T109）

    private var hoursSection: some View {
        Section {
            if let hours = viewModel.cafe.hours, hours.hasAnyDay {
                OpenStateBadge(state: OpeningHoursEvaluator.state(hours: hours))
                    .font(.subheadline)
                ForEach(Weekday.allCases, id: \.rawValue) { day in
                    if let ranges = hours.ranges(for: day) {
                        LabeledContent {
                            Text(hoursText(for: ranges))
                                .font(.callout.monospacedDigit())
                        } label: {
                            Text(day.displayName)
                        }
                    }
                }
            }
            if let text = viewModel.cafe.hoursText {
                Text(text)
                    .font(.callout)
            }
            // 定休日メモ（002/FR-107。例: 不定休・展示入替で休館あり）
            if let holidayNote = viewModel.cafe.holidayNote {
                LabeledContent {
                    Text(holidayNote)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("定休日")
                }
                .font(.callout)
            }
        } header: {
            Text("営業時間")
        } footer: {
            if let verified = viewModel.cafe.infoVerified {
                Text("基本情報の確認日: \(verified.formatted(date: .abbreviated, time: .omitted))。最新の営業情報は公式でご確認ください。")
            } else {
                Text("最新の営業情報は公式でご確認ください。")
            }
        }
    }

    private func hoursText(for ranges: [TimeRange]) -> String {
        if ranges.isEmpty { return String(localized: "定休日") }
        return ranges.map { "\($0.open)〜\($0.close)" }.joined(separator: ", ")
    }

    // MARK: - 矛盾提示（US4/FR-011/T046）

    private var conflictSection: some View {
        Section {
            warningBox(
                text: String(localized: "出典によって犬同伴可否の情報が食い違っています。各出典の内容と確認日をご確認ください。"),
                systemImage: "exclamationmark.triangle.fill",
                color: .yellow
            )
            ForEach(viewModel.sources) { source in
                SourceRow(
                    source: source,
                    isRepresentative: source.id == viewModel.representativeSource?.id
                )
            }
        } header: {
            Text("出典間の食い違い")
        } footer: {
            Text("代表表示は「確認日が新しい出典 → 由来の信頼順」で決定しています。確定できない場合は「未確認」になります。")
        }
    }

    // MARK: - 出典一覧（US2/FR-008/T032）

    private var sourcesSection: some View {
        Section {
            if viewModel.hasConflict {
                // 矛盾セクションで既に全出典を表示済み
                EmptyView()
            } else {
                ForEach(viewModel.sources) { source in
                    SourceRow(
                        source: source,
                        isRepresentative: source.id == viewModel.representativeSource?.id
                    )
                }
            }
        } header: {
            if !viewModel.hasConflict {
                Text("出典")
            }
        }
    }

    // MARK: - 店舗情報（US5/FR-014/T050）

    private var infoSection: some View {
        Section("店舗情報") {
            if let address = viewModel.cafe.address {
                LabeledContent {
                    Text(address)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("住所")
                }
            }
            // 電話（タップで発信, 002/FR-106）
            if let phone = viewModel.cafe.phone,
               let telURL = URL(string: "tel://" + phone.filter { $0.isNumber || $0 == "+" }) {
                Link(destination: telURL) {
                    LabeledContent {
                        Text(phone)
                            .foregroundStyle(.tint)
                    } label: {
                        Label(String(localized: "電話"), systemImage: "phone")
                            .labelStyle(.titleOnly)
                    }
                }
                .accessibilityLabel(Text("電話をかける: \(phone)"))
            }
            // 予約情報（002/FR-101）
            if let reservation = viewModel.cafe.reservation {
                LabeledContent {
                    Text(reservation)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("予約")
                }
            }
            if let contact = viewModel.cafe.contact {
                if let url = URL(string: contact), url.scheme?.hasPrefix("http") == true {
                    Link(destination: url) {
                        LabeledContent(String(localized: "連絡先・サイト"), value: contact)
                    }
                } else {
                    LabeledContent(String(localized: "連絡先"), value: contact)
                }
            }
            if case .loading = viewModel.phase {
                HStack {
                    ProgressView()
                    Text("出典情報を読み込み中…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if case .error(let message) = viewModel.phase {
                VStack(alignment: .leading, spacing: 8) {
                    Text("出典情報を取得できませんでした: \(message)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "再試行")) {
                        Task { await viewModel.load() }
                    }
                    .font(.footnote)
                }
            }
        }
    }

    // MARK: - 公式リンク・運営メモ（002/FR-103/106, T110）

    private var linksSection: some View {
        Section {
            if let links = viewModel.cafe.links, !links.isEmpty {
                ForEach(links) { link in
                    if let url = link.resolvedURL {
                        Link(destination: url) {
                            Label(link.type.displayName, systemImage: link.type.systemImage)
                        }
                    }
                }
            }
            if let note = viewModel.cafe.operatorNote {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                        Text("運営メモ（\(note.sourceDisplayName)より・\(note.verifiedAt.formatted(date: .abbreviated, time: .omitted))確認）")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.teal)
                    Text(note.text)
                        .font(.footnote)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.teal.opacity(0.10)))
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("公式情報・SNS")
        } footer: {
            if viewModel.cafe.operatorNote != nil {
                Text("運営メモは公式SNS等で運営が確認した内容の転記であり、公式の一次情報そのものではありません。")
            }
        }
    }

    // MARK: - アクション（US5/T049, US3/T038）

    private var actionSection: some View {
        Section {
            Button {
                viewModel.openInMaps()
            } label: {
                Label(String(localized: "経路案内（マップで開く）"), systemImage: "arrow.triangle.turn.up.right.diamond")
            }

            Button {
                showReport = true
            } label: {
                Label(String(localized: "情報の誤りを報告"), systemImage: "exclamationmark.bubble")
            }
        } footer: {
            Text("誤り報告は審査（v1: 運営確認）を通過してから反映されます。")
        }
    }

    private func warningBox(text: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .font(.footnote)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
        .foregroundStyle(color == .yellow ? Color.primary : color)
        .accessibilityElement(children: .combine)
    }
}

/// 出典1件の行: 種別・主張する可否・確認日・由来（provenance）を提示。
/// AI推測は明示ラベルで確定情報と視覚的に区別する（FR-012/T047）。
struct SourceRow: View {
    let source: Source
    let isRepresentative: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(source.type.displayName)
                    .font(.subheadline.bold())
                if isRepresentative {
                    Text("採用根拠")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                        .foregroundStyle(.blue)
                }
                Spacer()
                StatusBadge(status: source.claimedStatus)
            }
            HStack(spacing: 8) {
                ProvenanceChip(provenance: source.provenance)
                if let verifiedAt = source.verifiedAt {
                    Text("確認日: \(verifiedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let url = source.referenceURL {
                Link(destination: url) {
                    Text(url.absoluteString)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// 由来（provenance）チップ。AI推測は紫＋アイコンで確定情報と区別（FR-012）。
struct ProvenanceChip: View {
    let provenance: Provenance

    var body: some View {
        HStack(spacing: 3) {
            if provenance.isAIInferred {
                Image(systemName: "sparkles")
                    .font(.caption2)
            }
            Text(provenance.displayName)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
        .accessibilityLabel(Text(
            provenance.isAIInferred
                ? "由来: AI推測（未確定の情報）"
                : "由来: \(provenance.displayName)"
        ))
    }

    private var color: Color {
        provenance.isAIInferred ? .purple : .teal
    }
}
