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
