import SwiftUI

/// SafariView(sheet) 提示用の識別可能なURLラッパー
private struct AboutSafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// 「このアプリについて」画面（App Store 審査対応）。
/// アプリ名・バージョン・プライバシーポリシー・サポート・データの考え方・出典クレジットを提示する。
/// リンクは既存の `SafariView`（アプリ内ブラウザ）で開く。
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var safariItem: AboutSafariItem?

    var body: some View {
        NavigationStack {
            List {
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
                }

                Section {
                    linkRow(String(localized: "プライバシーポリシー"), systemImage: "hand.raised", url: AppEnvironment.privacyPolicyURL)
                    linkRow(String(localized: "サポート"), systemImage: "questionmark.circle", url: AppEnvironment.supportURL)
                }

                Section {
                    Text("犬同伴に関する情報は、出典URLと確認日をつけて運営が整備しています。条件や営業状況は変わることがあるため、ご来店前に必ず店舗へご確認ください。")
                        .font(.footnote)
                } header: {
                    Text("データについて")
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
            .navigationTitle(String(localized: "このアプリについて"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
            .sheet(item: $safariItem) { item in
                SafariView(url: item.url)
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
        }
        .foregroundStyle(.primary)
    }
}
