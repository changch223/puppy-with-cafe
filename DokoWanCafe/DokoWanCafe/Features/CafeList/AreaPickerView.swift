import SwiftUI

/// 検索地域の選択（FR-017: 位置情報の代替導線 / FR-022: v1 は東京のみ）
struct AreaPickerView: View {
    let onSelect: (SearchOrigin) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
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
}
