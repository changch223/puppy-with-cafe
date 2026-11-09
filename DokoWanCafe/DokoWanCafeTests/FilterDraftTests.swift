import XCTest
@testable import DokoWanCafe

/// 「絞り込み」シートの下書き（オンの数・1つ外した候補・いちばん増えるもの・文言）のユニットテスト
final class FilterDraftTests: XCTestCase {
    private func draft(
        indoor: Bool = false, terrace: Bool = false, largeDog: Bool = false, dogMenu: Bool = false,
        openNow: Bool = false, myDog: Bool = false, unverified: Bool = false
    ) -> FilterDraft {
        FilterDraft(
            amenities: AmenityFilter(indoorOnly: indoor, terraceOnly: terrace, largeDogOnly: largeDog, dogMenuOnly: dogMenu),
            openNowOnly: openNow,
            myDogOnly: myDog,
            includeUnverified: unverified
        )
    }

    // MARK: - オンの数

    func test_何もオンでなければ0() {
        XCTAssertEqual(FilterDraft().activeCount, 0)
        XCTAssertTrue(FilterDraft().activeConditions.isEmpty)
    }

    func test_オンの条件を数える() {
        XCTAssertEqual(draft(indoor: true).activeCount, 1)
        XCTAssertEqual(draft(indoor: true, openNow: true).activeCount, 2)
        // 7つ全部（店内OK・テラス・大型犬OK・犬メニュー・営業中・うちの子OK・未確認も表示）
        let all = draft(indoor: true, terrace: true, largeDog: true, dogMenu: true, openNow: true, myDog: true, unverified: true)
        XCTAssertEqual(all.activeCount, 7)
        XCTAssertEqual(all.activeConditions, FilterDraft.relaxationOrder)
    }

    func test_オンの条件は外す影響が小さい順に並ぶ() {
        let d = draft(indoor: true, largeDog: true, myDog: true, unverified: true)
        XCTAssertEqual(d.activeConditions, [.includeUnverified, .largeDog, .indoor, .myDog])
    }

    func test_外す影響が小さい順の並び() {
        XCTAssertEqual(
            FilterDraft.relaxationOrder,
            [.includeUnverified, .dogMenu, .largeDog, .terrace, .indoor, .openNow, .myDog]
        )
    }

    // MARK: - 1つ外す

    func test_1つ外すとほかの条件は変わらない() {
        let all = draft(indoor: true, terrace: true, largeDog: true, dogMenu: true, openNow: true, myDog: true, unverified: true)
        for condition in FilterDraft.relaxationOrder {
            let removed = all.removing(condition)
            XCTAssertFalse(removed.isOn(condition), "\(condition)")
            XCTAssertEqual(removed.activeCount, 6, "\(condition)")
            for other in FilterDraft.relaxationOrder where other != condition {
                XCTAssertTrue(removed.isOn(other), "\(condition) を外しても \(other) は残る")
            }
        }
    }

    func test_オフの条件を外しても変わらない() {
        XCTAssertEqual(FilterDraft().removing(.terrace), FilterDraft())
    }

    // MARK: - 1つずつ外した候補

    func test_オンの条件を1つずつ外した件数を並べる() {
        let d = draft(terrace: true, largeDog: true)
        // 偽の数え方: 外した条件ごとに増える件数が違う（大型犬OKを外すと12件、テラスを外すと5件）
        let count: (FilterDraft) -> Int = { x in (x.isOn(.largeDog) ? 0 : 12) + (x.isOn(.terrace) ? 0 : 5) }
        let list = d.relaxations(count: count)
        XCTAssertEqual(list, [
            FilterDraft.Relaxation(condition: .largeDog, count: 12),
            FilterDraft.Relaxation(condition: .terrace, count: 5),
        ])
    }

    func test_何もオンでなければ候補はない() {
        XCTAssertTrue(FilterDraft().relaxations(count: { _ in 3 }).isEmpty)
        XCTAssertNil(FilterDraft().bestRelaxation(count: { _ in 3 }))
    }

    // MARK: - いちばん増えるもの

    func test_いちばん増える条件を選ぶ() {
        let d = draft(terrace: true, largeDog: true, openNow: true)
        let count: (FilterDraft) -> Int = { x in
            (x.isOn(.largeDog) ? 0 : 12) + (x.isOn(.terrace) ? 0 : 5) + (x.isOn(.openNow) ? 0 : 30)
        }
        let best = d.bestRelaxation(count: count)
        // 営業中を外したときの件数がいちばん多い（30件。大型犬OKは12件、テラスは5件）
        XCTAssertEqual(best, FilterDraft.Relaxation(condition: .openNow, count: 30))
    }

    func test_同じ件数なら外す影響が小さい順で先のものを選ぶ() {
        // 今は0件で、どれを1つ外しても7件になる偽の数え方（条件が今より減っていれば7件）
        func everyOne(_ base: FilterDraft) -> (FilterDraft) -> Int {
            { x in x.activeCount < base.activeCount ? 7 : 0 }
        }
        let d = draft(indoor: true, largeDog: true, myDog: true)
        // 大型犬OK → 店内OK → うちの子OK の順なので、大型犬OK
        XCTAssertEqual(d.bestRelaxation(count: everyOne(d)), FilterDraft.Relaxation(condition: .largeDog, count: 7))

        let d2 = draft(terrace: true, openNow: true, myDog: true)
        XCTAssertEqual(d2.bestRelaxation(count: everyOne(d2)), FilterDraft.Relaxation(condition: .terrace, count: 7))

        let d3 = draft(openNow: true, myDog: true)
        XCTAssertEqual(d3.bestRelaxation(count: everyOne(d3)), FilterDraft.Relaxation(condition: .openNow, count: 7))

        // 未確認も表示は最も先
        let d4 = draft(dogMenu: true, myDog: true, unverified: true)
        XCTAssertEqual(d4.bestRelaxation(count: everyOne(d4)), FilterDraft.Relaxation(condition: .includeUnverified, count: 7))
    }

    func test_外しても1件も増えないなら候補は出さない() {
        let d = draft(terrace: true, largeDog: true)
        XCTAssertNil(d.bestRelaxation(count: { _ in 0 }))
        // 今の件数より増えない（同じ・減る）ときも出さない
        XCTAssertNil(d.bestRelaxation(count: { _ in 4 }))
        XCTAssertNil(d.bestRelaxation(count: { x in x.activeCount == 2 ? 4 : 2 }))
    }

    func test_1つだけ増えるなら増えるものを選ぶ() {
        let d = draft(terrace: true, largeDog: true, dogMenu: true)
        // 大型犬OKを外したときだけ 3件になる
        let count: (FilterDraft) -> Int = { x in x.isOn(.largeDog) ? 0 : 3 }
        XCTAssertEqual(d.bestRelaxation(count: count), FilterDraft.Relaxation(condition: .largeDog, count: 3))
    }

    // MARK: - 文言

    func test_外すと増える条件の文言() {
        XCTAssertEqual(FilterDraft.Relaxation(condition: .largeDog, count: 12).title(), "「大型犬OK」を外すと12件")
        XCTAssertEqual(FilterDraft.Relaxation(condition: .openNow, count: 4).title(), "「営業中」を外すと4件")
        XCTAssertEqual(
            FilterDraft.Relaxation(condition: .openNow, count: 4).title(isTargetTime: true),
            "「その時間に営業」を外すと4件"
        )
        XCTAssertEqual(FilterDraft.Relaxation(condition: .myDog, count: 9).title(), "「うちの子OK」を外すと9件")
    }

    func test_ボタンの文言は0件のとき理由を言う() {
        XCTAssertEqual(FilterDraft.applyButtonTitle(count: 23), "23件を表示")
        XCTAssertEqual(FilterDraft.applyButtonTitle(count: 1), "1件を表示")
        XCTAssertEqual(FilterDraft.applyButtonTitle(count: 0), "この条件では0件")
    }

    func test_チップの読み上げ() {
        XCTAssertEqual(FilterDraft.chipAccessibilityLabel(activeCount: 0), "絞り込み")
        XCTAssertEqual(FilterDraft.chipAccessibilityLabel(activeCount: 2), "絞り込み、2件オン")
    }

    func test_母数が0件のときは_この条件では0件_と言わない() {
        XCTAssertEqual(FilterDraft.applyButtonTitle(count: 0, hasAnyResult: false), "条件を反映")
        XCTAssertEqual(FilterDraft.applyButtonTitle(count: 0, hasAnyResult: true), "この条件では0件")
        XCTAssertEqual(FilterDraft.applyButtonTitle(count: 12, hasAnyResult: true), "12件を表示")
    }
}
