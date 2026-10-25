import SwiftUI

private struct DogProfileKey: EnvironmentKey {
    static let defaultValue: DogProfile? = nil
}

extension EnvironmentValues {
    /// うちの子の設定（再設計 段階3）。行・カード・詳細が「うちの子OK」などを出すために読む。未設定は nil。
    var dogProfile: DogProfile? {
        get { self[DogProfileKey.self] }
        set { self[DogProfileKey.self] = newValue }
    }
}

/// 行・カードの「うちの子は不可（店内は中型犬まで）」。灰色で出し、隠さない（チップで除外できる）。
struct MyDogNoteView: View {
    let cafe: Cafe
    @Environment(\.dogProfile) private var dog

    var body: some View {
        if let dog, let note = DogFit.evaluate(cafe: cafe, dog: dog).rowNote {
            Text(note)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
