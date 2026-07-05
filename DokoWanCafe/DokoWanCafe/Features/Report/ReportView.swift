import SwiftUI

/// 誤り報告・修正提案フォーム（T040/T041, FR-023/024/028）。
/// 未サインインならサインインへ誘導し、送信後は「審査中」であること
/// （表示には即時反映されないこと）を明示する。
struct ReportView: View {
    let cafe: Cafe
    private let dependencies: AppDependencies
    @ObservedObject private var auth: AuthService

    @Environment(\.dismiss) private var dismiss

    @State private var proposedStatus: DogPolicyStatus?
    @State private var condition: String = ""
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var submitted: Correction?

    init(cafe: Cafe, dependencies: AppDependencies) {
        self.cafe = cafe
        self.dependencies = dependencies
        self.auth = dependencies.authService
    }

    var body: some View {
        NavigationStack {
            Group {
                if !dependencies.correctionService.isAvailable {
                    unavailableView
                } else if let submitted {
                    doneView(submitted)
                } else if !auth.isSignedIn {
                    // FR-028: 投稿時のみサインインを要求
                    SignInPromptView(auth: auth)
                } else {
                    formView
                }
            }
            .navigationTitle(String(localized: "情報の誤りを報告"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
        }
    }

    // MARK: - フォーム（T040）

    private var formView: some View {
        Form {
            Section {
                LabeledContent(String(localized: "対象"), value: cafe.name)
                LabeledContent(String(localized: "現在の表示"), value: cafe.dogPolicyStatus.displayName)
            }

            Section {
                Picker(String(localized: "正しい犬同伴可否"), selection: $proposedStatus) {
                    Text("変更を提案しない").tag(DogPolicyStatus?.none)
                    ForEach(DogPolicyStatus.allCases) { status in
                        Text(status.displayName).tag(DogPolicyStatus?.some(status))
                    }
                }
                if proposedStatus == .conditional {
                    TextField(String(localized: "条件（例: テラス席のみ・小型犬のみ）"), text: $condition)
                }
            } header: {
                Text("修正の提案")
            }

            Section {
                TextField(
                    String(localized: "気づいたこと・根拠（任意。例: 公式SNSで犬OKと案内されていた）"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(3...6)
            } header: {
                Text("補足")
            } footer: {
                Text("送信された内容は審査（v1: 運営確認）を通過してから反映されます。即時には反映されません。")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("送信する")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting || !hasContent)
            }
        }
    }

    /// 何も入力されていない送信を防ぐ
    private var hasContent: Bool {
        proposedStatus != nil
            || !condition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let correction = try await dependencies.correctionService.submit(
                    cafeID: cafe.id,
                    proposedStatus: proposedStatus,
                    proposedCondition: condition,
                    note: note
                )
                submitted = correction
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    // MARK: - 送信完了（T041, FR-024: 即時反映されないことの明示）

    private func doneView(_ correction: Correction) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("報告を受け付けました")
                .font(.headline)
            Text("この報告は「\(correction.status.displayName)」です。内容の確認（v1: 運営による審査）を通過すると表示に反映されます。即時には反映されません。ご協力ありがとうございます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "閉じる")) { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    // MARK: - サンプルモード

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("現在は報告を送信できません")
                .font(.headline)
            Text("アプリがサンプルデータモード（バックエンド未設定）で動作しているため、誤り報告は送信できません。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
