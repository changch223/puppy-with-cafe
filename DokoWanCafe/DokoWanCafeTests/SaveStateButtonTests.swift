import XCTest
@testable import DokoWanCafe

/// 詳細画面の保存の状態ボタン（行きたい／行った）の状態遷移・表示のユニットテスト
final class SaveStateButtonTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private func later(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    // MARK: - ボタンの表示・タップ・メニュー

    func test_未保存_ラベルは行きたい_タップで行きたいに入る() {
        let button = SaveStateButton.make(status: nil, visitedDate: nil)
        XCTAssertEqual(button.title, "行きたい")
        XCTAssertEqual(button.systemImage, "pawprint")
        XCTAssertEqual(button.tapAction, .addWantToGo)
        XCTAssertEqual(button.menuActions, [.addWantToGo, .markVisited])
        XCTAssertEqual(button.menuActions.map { $0.menuTitle(from: nil) }, ["行きたいに入れる", "行ったに記録する"])
    }

    func test_行きたい_ラベルは行きたいチェック_タップで外れる() {
        let button = SaveStateButton.make(status: .wantToGo, visitedDate: nil)
        XCTAssertEqual(button.title, "行きたい ✓")
        XCTAssertEqual(button.systemImage, "pawprint.fill")
        XCTAssertEqual(button.tapAction, .removeFromSaved)
        XCTAssertEqual(button.menuActions, [.markVisited, .removeFromSaved])
        XCTAssertEqual(button.menuActions.map { $0.menuTitle(from: .wantToGo) }, ["行ったに記録する", "行きたいから外す"])
    }

    func test_行った_ラベルに日付_タップでは何もせずメニューを開く() {
        // 2023-11-14 22:13 UTC は東京で 11/15
        let button = SaveStateButton.make(status: .visited, visitedDate: t0)
        XCTAssertEqual(button.title, "行った ✓ \(TargetTime.monthDayText(t0))")
        XCTAssertEqual(button.systemImage, "checkmark.circle.fill")
        XCTAssertNil(button.tapAction, "行った記録を誤って消さないため、タップはメニューを開くだけ")
        XCTAssertEqual(button.menuActions, [.backToWantToGo, .removeFromSaved])
        XCTAssertEqual(button.menuActions.map { $0.menuTitle(from: .visited) }, ["行きたいに戻す", "保存から外す"])
    }

    func test_行ったで日付が不明でもラベルは作れる() {
        XCTAssertEqual(SaveStateButton.make(status: .visited, visitedDate: nil).title, "行った ✓")
    }

    func test_VoiceOverのラベルは状態と動きが分かる() {
        XCTAssertTrue(SaveStateButton.make(status: nil, visitedDate: nil).accessibilityLabel.contains("行きたいに入れる"))
        let want = SaveStateButton.make(status: .wantToGo, visitedDate: nil).accessibilityLabel
        XCTAssertTrue(want.contains("行きたいに入っています") && want.contains("タップで外します"))
        let visited = SaveStateButton.make(status: .visited, visitedDate: t0).accessibilityLabel
        XCTAssertTrue(visited.contains(TargetTime.monthDayText(t0)) && visited.contains("タップで操作を選びます"))
    }

    func test_外す操作だけ破壊的() {
        XCTAssertTrue(SaveAction.removeFromSaved.isDestructive)
        XCTAssertFalse(SaveAction.addWantToGo.isDestructive)
        XCTAssertFalse(SaveAction.markVisited.isDestructive)
        XCTAssertFalse(SaveAction.backToWantToGo.isDestructive)
    }

    // MARK: - 状態遷移（SavedPlaces.apply）

    func test_未保存からの遷移() {
        let id = UUID()
        var places = SavedPlaces()
        places.apply(.addWantToGo, to: id, at: t0)
        XCTAssertEqual(places.status(of: id), .wantToGo)

        var visited = SavedPlaces()
        visited.apply(.markVisited, to: id, at: t0)
        XCTAssertEqual(visited.status(of: id), .visited)
        XCTAssertEqual(visited.visitedDate(of: id), t0)
    }

    func test_行きたいからの遷移() {
        let id = UUID()
        var toVisited = SavedPlaces()
        toVisited.apply(.addWantToGo, to: id, at: t0)
        toVisited.apply(.markVisited, to: id, at: later(10))
        XCTAssertEqual(toVisited.status(of: id), .visited)
        XCTAssertFalse(toVisited.wantToGoIDs.contains(id), "2つのリストに同時には入らない")
        XCTAssertEqual(toVisited.visitedDate(of: id), later(10))

        var removed = SavedPlaces()
        removed.apply(.addWantToGo, to: id, at: t0)
        removed.apply(.removeFromSaved, to: id, at: later(10))
        XCTAssertNil(removed.status(of: id))
    }

    func test_行ったからの遷移() {
        let id = UUID()
        var back = SavedPlaces()
        back.apply(.markVisited, to: id, at: t0)
        back.apply(.backToWantToGo, to: id, at: later(10))
        XCTAssertEqual(back.status(of: id), .wantToGo)
        XCTAssertNil(back.visitedDate(of: id), "行った記録は外れる")

        var removed = SavedPlaces()
        removed.apply(.markVisited, to: id, at: t0)
        removed.apply(.removeFromSaved, to: id, at: later(10))
        XCTAssertNil(removed.status(of: id))
    }

    func test_すでにその状態の操作は何も変えない() {
        let id = UUID()
        var places = SavedPlaces()
        places.apply(.markVisited, to: id, at: t0)
        places.apply(.markVisited, to: id, at: later(99))
        XCTAssertEqual(places.visitedDate(of: id), t0, "行った日は動かない")

        var want = SavedPlaces()
        want.apply(.addWantToGo, to: id, at: t0)
        want.apply(.addWantToGo, to: id, at: later(99))
        XCTAssertEqual(want.status(of: id), .wantToGo, "二度押しで外れない")
        want.remove(id)
        want.apply(.removeFromSaved, to: id, at: t0)
        XCTAssertNil(want.status(of: id))
    }

    func test_ボタンのタップ動作を当てた結果が表示の次の状態になる() {
        let id = UUID()
        var places = SavedPlaces()
        // 未保存 → タップ → 行きたい → タップ → 未保存
        for expected: SavedStatus? in [.wantToGo, nil] {
            let button = SaveStateButton.make(status: places.status(of: id), visitedDate: places.visitedDate(of: id))
            places.apply(button.tapAction!, to: id, at: t0)
            XCTAssertEqual(places.status(of: id), expected)
        }
    }

    // MARK: - ストア

    @MainActor
    func test_ストアのapplyは保存され再読み込みしても残る() {
        let suite = "SaveStateButtonTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID()
        let store = SavedPlacesStore(defaults: defaults, now: { self.t0 })
        store.apply(.markVisited, to: id)
        XCTAssertEqual(store.status(of: id), .visited)

        let reloaded = SavedPlacesStore(defaults: defaults, now: { self.t0 })
        XCTAssertEqual(reloaded.status(of: id), .visited)
        reloaded.apply(.backToWantToGo, to: id)
        XCTAssertEqual(reloaded.status(of: id), .wantToGo)
    }

    // MARK: - 地図スナップショットのキー

    func test_地図キーは店_外観_幅で分かれ幅は整数にそろえる() {
        let id = UUID()
        let base = MapSnapshotKey(cafeID: id, isDark: false, width: 390.0)
        XCTAssertEqual(base, MapSnapshotKey(cafeID: id, isDark: false, width: 389.6))
        XCTAssertNotEqual(base, MapSnapshotKey(cafeID: id, isDark: true, width: 390.0))
        XCTAssertNotEqual(base, MapSnapshotKey(cafeID: id, isDark: false, width: 430.0))
        XCTAssertNotEqual(base, MapSnapshotKey(cafeID: UUID(), isDark: false, width: 390.0))
    }
}
