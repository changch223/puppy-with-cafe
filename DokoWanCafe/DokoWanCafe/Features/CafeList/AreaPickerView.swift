import SwiftUI

/// 検索地域の選択（FR-017: 位置情報の代替導線 / FR-022: v1 は東京のみ）。
/// 住所・駅名・エリア名の自由入力検索（機能2）と、固定の主要エリア一覧を併存させる。
struct AreaPickerView: View {
    let onSelect: (SearchOrigin) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchErrorMessage: String?
    // GeocodingService はキャッシュ等の共有状態を持たないため画面ごとに生成する（LinkPreviewService.shared のような
    // 共有インスタンスは不要）。
    private let geocodingService = GeocodingService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "住所・駅名・エリアで検索"), text: $searchText)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit { Task { await search() } }
                        if isSearching {
                            ProgressView()
                        }
                    }
                    if let searchErrorMessage {
                        Text(searchErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        onSelect(.currentLocation)
                        dismiss()
                    } label: {
                        Label(String(localized: "現在地を使う"), systemImage: "location.fill")
                    }
                }

                Section {
                    ForEach(ManualArea.tokyoPresets) { area in
                        Button {
                            onSelect(.manual(area))
                            dismiss()
                        } label: {
                            Label(area.name, systemImage: "mappin.and.ellipse")
                        }
                    }
                } header: {
                    Text("東京の主要エリア")
                } footer: {
                    Text("現在は東京エリアのみ対応しています。対応エリアは順次拡大予定です。")
                }
            }
            .navigationTitle(String(localized: "検索する地域"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
        }
    }

    /// 検索欄の入力を `GeocodingService` でジオコーディングし、成功したら `.searched` 起点として選択する。
    /// Appleへ送信されるのは入力した検索クエリの文字列のみで、GPS現在地は送らない（憲章 原則III）。
    private func search() async {
        guard let normalized = GeocodingService.PureLogic.normalizedQuery(searchText) else { return }
        searchErrorMessage = nil
        isSearching = true
        defer { isSearching = false }

        guard let result = await geocodingService.search(normalized) else {
            searchErrorMessage = String(localized: "見つかりませんでした")
            return
        }
        onSelect(.searched(
            name: result.name,
            latitude: result.coordinate.latitude,
            longitude: result.coordinate.longitude
        ))
        dismiss()
    }
}
