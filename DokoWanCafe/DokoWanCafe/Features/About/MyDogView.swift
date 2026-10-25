import SwiftUI

/// SafariView(sheet) 提示用の識別可能なURLラッパー
private struct AboutSafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// 「うちの子」タブ（再設計 段階1a。段階3で犬の設定が入る）。
/// 段階1では、データの更新日と再読み込み・ピンと表示の見かた・このアプリについて（旧 AboutView の中身）を置く。
/// リンクは既存の `SafariView`（アプリ内ブラウザ）で開く。
struct MyDogView: View {
    /// データ（cafes.json）の生成日時（FR-032: 鮮度の提示）。分からなければ nil。
    let dataGeneratedAt: Date?
    let isSampleMode: Bool
    let isReloading: Bool
    let onReload: () -> Void

    @State private var safariItem: AboutSafariItem?

    var body: some View {
        List {
            dataSection
            legendSection
            appSection
        }
        .navigationTitle(String(localized: "うちの子"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
        }
    }

    // MARK: - データ

    private var dataSection: some View {
        Section {
            HStack {
                Text("データの更新日")
                Spacer()
                Text(dataGeneratedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? String(localized: "不明"))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if isSampleMode {
                Text("サンプルデータ表示中（架空の店舗情報です）")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Button(action: onReload) {
                HStack {
                    Label(String(localized: "再読み込み"), systemImage: "arrow.clockwise")
                    Spacer()
                    if isReloading {
                        ProgressView()
                    }
                }
                .frame(minHeight: 44)
            }
            .disabled(isReloading)
            .accessibilityHint(Text("お店のデータを最新に更新します"))
        } header: {
            Text("データ")
        } footer: {
            Text("犬同伴に関する情報は、出典URLと確認日をつけて運営が整備しています。条件や営業状況は変わることがあるため、ご来店前に必ず店舗へご確認ください。")
        }
    }

    // MARK: - ピンと表示の見かた

    private var legendSection: some View {
        Section {
            legendRow(category: .indoorOK, title: String(localized: "店内OK"), detail: String(localized: "愛犬と店内に入れます（緑の丸）"))
            legendRow(category: .terraceOnly, title: String(localized: "テラスOK"), detail: String(localized: "テラス席は可。店内は不可または不明です（青緑の角丸四角）"))
            legendRow(category: .checkDetail, title: String(localized: "条件を確認"), detail: String(localized: "席の種類や条件を詳細で確認（橙のしずく形）"))
            legendRow(category: .unverified, title: String(localized: "未確認"), detail: String(localized: "犬同伴の可否を確認できていません（グレーの菱形）"))
            legendRow(
                category: .indoorOK,
                title: String(localized: "薄いピン"),
                detail: String(localized: "営業時間が分かっていて、今は営業時間外です"),
                isDimmed: true
            )
        } header: {
            Text("ピンと表示の見かた")
        } footer: {
            Text("「テラスのみ」と表示するのは、店内が不可と確認できているお店だけです。")
        }
    }

    private func legendRow(category: MapPinCategory, title: String, detail: String, isDimmed: Bool = false) -> some View {
        let style = MapPinStyle(category: category, isFavorite: false, isDimmed: isDimmed)
        return HStack(spacing: 12) {
            Image(uiImage: MapPinRenderer.image(for: style))
                .opacity(style.alpha)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - このアプリについて

    private var appSection: some View {
        Group {
            Section {
                HStack {
                    Text("アプリ名")
                    Spacer()
                    Text(AppEnvironment.displayName)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(AppEnvironment.appVersion())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                linkRow(String(localized: "プライバシーポリシー"), systemImage: "hand.raised", url: AppEnvironment.privacyPolicyURL)
                linkRow(String(localized: "サポート"), systemImage: "questionmark.circle", url: AppEnvironment.supportURL)
            } header: {
                Text("このアプリについて")
            }

            Section {
                Text("位置情報の一部は、デジタル庁「アドレス・ベース・レジストリ」（公共データ利用規約（第1.0版））を Puppy With Cafe 運営が加工して作成しています。")
                    .font(.footnote)
                linkRow(String(localized: "公共データ利用規約（第1.0版）"), systemImage: "link", url: AppEnvironment.addressBaseRegistryTermsURL)
            } header: {
                Text("出典")
            }

            Section {
                Text("© 2026 Puppy With Cafe")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func linkRow(_ title: String, systemImage: String, url: URL) -> some View {
        Button {
            safariItem = AboutSafariItem(url: url)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
        }
        .foregroundStyle(.primary)
    }
}
