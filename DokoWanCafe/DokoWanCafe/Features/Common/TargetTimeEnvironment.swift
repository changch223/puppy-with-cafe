import SwiftUI

private struct TargetTimeKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

extension EnvironmentValues {
    /// 「いつ行く？」で決めた対象時刻（nil は「今」）。詳細の「今日」タイルが、行の「土 12:00 は営業中」と
    /// 食い違って見えないよう、対象時刻の営業を示すために読む。
    var targetTime: Date? {
        get { self[TargetTimeKey.self] }
        set { self[TargetTimeKey.self] = newValue }
    }
}
