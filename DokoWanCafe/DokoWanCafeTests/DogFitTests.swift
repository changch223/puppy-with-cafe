import XCTest
@testable import DokoWanCafe

/// DogFit（うちの子が入れるかの判定）のユニットテスト（再設計 段階3, 憲章 原則I・IV）。
/// 全分岐: 席（店内・テラス）× 可否（true/false/nil）× サイズ上限の有無 × うちの子の大きさ × 未確認。
final class DogFitTests: XCTestCase {
    private func makeCafe(
        status: DogPolicyStatus = .allowed,
        indoor: Bool? = nil,
        terrace: Bool? = nil,
        largeDogs: Bool? = nil,
        sizeIndoor: DogSize? = nil,
        sizeTerrace: DogSize? = nil,
        styles: [DogStyle]? = nil,
        sizeLimitText: String? = nil,
        lastVerified: Date? = Date(timeIntervalSince1970: 1_780_000_000)
    ) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: "テストカフェ",
            latitude: 35.68, longitude: 139.76,
            address: nil, contact: nil,
            dogPolicyStatus: status, dogPolicyCondition: nil,
            lastVerified: lastVerified, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo",
            dogAmenities: DogAmenities(
                indoor: indoor, terrace: terrace, largeDogs: largeDogs, dogMenu: nil,
                sizeMaxIndoor: sizeIndoor, sizeMaxTerrace: sizeTerrace, indoorStyle: styles
            ),
            dogSizeLimit: sizeLimitText
        )
    }

    private func fit(_ cafe: Cafe, _ size: DogSize, styles: Set<DogStyle> = []) -> DogFit.Result {
        DogFit.evaluate(cafe: cafe, dog: DogProfile(size: size, styles: styles))
    }

    // MARK: - 席の可否

    func test_席の可否がfalseならその席は入れない() {
        let result = fit(makeCafe(indoor: false, terrace: true), .small)
        XCTAssertEqual(result.indoor, .doesNotFit(.seatNotAllowed))
    }

    func test_席の可否が空ならその席は分からない() {
        let result = fit(makeCafe(indoor: nil, terrace: nil), .small)
        XCTAssertEqual(result.indoor, .unknown(.seatNotStated))
        XCTAssertEqual(result.terrace, .unknown(.seatNotStated))
        XCTAssertEqual(result.overall, .unknown)
    }

    func test_可否が空の席にサイズ上限があっても入れるとは言わない() {
        // 防御: 席の可否が true でなければ、上限があっても fits にしない
        let result = fit(makeCafe(indoor: nil, sizeIndoor: .large), .small)
        XCTAssertEqual(result.indoor, .unknown(.seatNotStated))
    }

    func test_可否がfalseの席にサイズ上限があっても入れるとは言わない() {
        let result = fit(makeCafe(indoor: false, sizeIndoor: .large), .small)
        XCTAssertEqual(result.indoor, .doesNotFit(.seatNotAllowed))
    }

    // MARK: - サイズ上限が明記されている席

    func test_上限が中型犬なら小型犬と中型犬は入れて大型犬は入れない() {
        let cafe = makeCafe(indoor: true, sizeIndoor: .medium)
        XCTAssertEqual(fit(cafe, .small).indoor, .fits)
        XCTAssertEqual(fit(cafe, .medium).indoor, .fits)
        XCTAssertEqual(fit(cafe, .large).indoor, .doesNotFit(.sizeLimit(.medium)))
    }

    func test_上限が小型犬なら中型犬と大型犬は入れない() {
        let cafe = makeCafe(indoor: true, sizeIndoor: .small)
        XCTAssertEqual(fit(cafe, .small).indoor, .fits)
        XCTAssertEqual(fit(cafe, .medium).indoor, .doesNotFit(.sizeLimit(.small)))
        XCTAssertEqual(fit(cafe, .large).indoor, .doesNotFit(.sizeLimit(.small)))
    }

    func test_上限が大型犬ならどの大きさも入れる() {
        let cafe = makeCafe(indoor: true, sizeIndoor: .large)
        for size in DogSize.allCases {
            XCTAssertEqual(fit(cafe, size).indoor, .fits)
        }
    }

    func test_上限が明記されていれば大型犬可の有無やサイズの条件文より上限を優先する() {
        let cafe = makeCafe(indoor: true, largeDogs: nil, sizeIndoor: .medium, sizeLimitText: "中型犬まで")
        XCTAssertEqual(fit(cafe, .medium).indoor, .fits)
        XCTAssertEqual(fit(cafe, .large).indoor, .doesNotFit(.sizeLimit(.medium)))
    }

    func test_上限は席ごとに別々に効く() {
        let cafe = makeCafe(indoor: true, terrace: true, sizeIndoor: .medium, sizeTerrace: .large)
        let result = fit(cafe, .large)
        XCTAssertEqual(result.indoor, .doesNotFit(.sizeLimit(.medium)))
        XCTAssertEqual(result.terrace, .fits)
        XCTAssertEqual(result.overall, .fits)
    }

    // MARK: - サイズ上限が無い席

    func test_上限なしで小型犬は入れる() {
        XCTAssertEqual(fit(makeCafe(indoor: true), .small).indoor, .fits)
        XCTAssertEqual(fit(makeCafe(indoor: true, largeDogs: false), .small).indoor, .fits)
    }

    func test_上限なしでも小型犬はサイズの条件文がある店では分からない() {
        let cafe = makeCafe(indoor: true, sizeLimitText: "大型犬はテラス席のみ")
        let result = fit(cafe, .small)
        XCTAssertEqual(result.indoor, .unknown(.sizeConditionText))
        XCTAssertEqual(result.overall, .unknown)
    }

    func test_サイズの条件文が空白だけなら無いものとして扱う() {
        XCTAssertEqual(fit(makeCafe(indoor: true, sizeLimitText: "  \n"), .small).indoor, .fits)
    }

    func test_上限なしで中型犬と大型犬は大型犬可でサイズの条件文が無ければ入れる() {
        let cafe = makeCafe(indoor: true, largeDogs: true)
        XCTAssertEqual(fit(cafe, .medium).indoor, .fits)
        XCTAssertEqual(fit(cafe, .large).indoor, .fits)
    }

    func test_上限なしで大型犬可でもサイズの条件文があれば中型犬と大型犬は分からない() {
        let cafe = makeCafe(indoor: true, largeDogs: true, sizeLimitText: "大型犬はテラス席のみ")
        XCTAssertEqual(fit(cafe, .medium).indoor, .unknown(.sizeConditionText))
        XCTAssertEqual(fit(cafe, .large).indoor, .unknown(.sizeConditionText))
    }

    func test_上限なしで大型犬可が空かfalseなら中型犬と大型犬は分からない() {
        for largeDogs in [nil, false] as [Bool?] {
            let cafe = makeCafe(indoor: true, largeDogs: largeDogs)
            XCTAssertEqual(fit(cafe, .medium).indoor, .unknown(.sizeNotStated))
            XCTAssertEqual(fit(cafe, .large).indoor, .unknown(.sizeNotStated))
        }
    }

    func test_片方の席に上限があれば大型犬可でもう片方の席をfitsにしない() {
        // 店内は中型犬までと明記、テラスは上限なし＋large_dogs=true（どちらの席の話か分からない）
        let cafe = makeCafe(indoor: true, terrace: true, largeDogs: true, sizeIndoor: .medium)
        let large = fit(cafe, .large)
        XCTAssertEqual(large.indoor, .doesNotFit(.sizeLimit(.medium)))
        XCTAssertEqual(large.terrace, .unknown(.sizeNotStated))
        XCTAssertEqual(large.overall, .unknown)
        XCTAssertNotEqual(large.detailBody, "テラス席なら過ごせます（店内は中型犬まで）")
        // 上限内の中型犬は、上限が明記された席で fits
        let medium = fit(cafe, .medium)
        XCTAssertEqual(medium.indoor, .fits)
        XCTAssertEqual(medium.terrace, .unknown(.sizeNotStated))
        XCTAssertEqual(medium.overall, .fits)
        // 小型犬は large_dogs に頼らないので従来どおり両方 fits
        XCTAssertEqual(fit(cafe, .small).terrace, .fits)
    }

    func test_テラスにだけ上限があるときも店内を大型犬可で補完しない() {
        let cafe = makeCafe(indoor: true, terrace: true, largeDogs: true, sizeTerrace: .medium)
        let large = fit(cafe, .large)
        XCTAssertEqual(large.indoor, .unknown(.sizeNotStated))
        XCTAssertEqual(large.terrace, .doesNotFit(.sizeLimit(.medium)))
        XCTAssertEqual(large.overall, .unknown)
    }

    func test_実データ型_テラスにだけ上限がある条件つきの店() {
        // Le Maghreb・a-bridge 三軒茶屋と同じ形: 店内は上限なし、テラスは大型犬まで、large_dogs=true、conditional
        let cafe = makeCafe(status: .conditional, indoor: true, terrace: true, largeDogs: true, sizeTerrace: .large)
        for size in [DogSize.medium, .large] {
            let result = fit(cafe, size)
            XCTAssertEqual(result.indoor, .unknown(.sizeNotStated), "店内を large_dogs で補完しない")
            XCTAssertEqual(result.terrace, .fits)
            XCTAssertEqual(result.detailBody, "テラス席なら過ごせます")
            XCTAssertTrue(result.detailLine.hasSuffix("（条件あり）"))
        }
        XCTAssertEqual(fit(cafe, .small).indoor, .fits)
    }

    func test_どちらの席にも上限がなければ大型犬可で両方fits() {
        let cafe = makeCafe(indoor: true, terrace: true, largeDogs: true)
        let large = fit(cafe, .large)
        XCTAssertEqual(large.indoor, .fits)
        XCTAssertEqual(large.terrace, .fits)
    }

    // MARK: - 店全体

    func test_いずれかの席が入れるなら店全体は入れる() {
        let indoorOnly = fit(makeCafe(indoor: true, terrace: false), .small)
        XCTAssertEqual(indoorOnly.overall, .fits)
        let terraceOnly = fit(makeCafe(indoor: false, terrace: true), .small)
        XCTAssertEqual(terraceOnly.overall, .fits)
        // 片方が分からなくても、もう片方が入れると明記されていれば入れる
        let terraceUnknown = fit(makeCafe(indoor: true, terrace: nil), .small)
        XCTAssertEqual(terraceUnknown.overall, .fits)
    }

    func test_すべての席が入れないなら店全体は入れない() {
        let cafe = makeCafe(indoor: true, terrace: true, sizeIndoor: .small, sizeTerrace: .medium)
        let result = fit(cafe, .large)
        XCTAssertEqual(result.overall, .doesNotFit)
        let seatsClosed = fit(makeCafe(indoor: false, terrace: false), .small)
        XCTAssertEqual(seatsClosed.overall, .doesNotFit)
    }

    func test_入れない席と分からない席だけなら店全体は分からない() {
        let indoorNoTerraceUnknown = fit(makeCafe(indoor: false, terrace: nil), .small)
        XCTAssertEqual(indoorNoTerraceUnknown.overall, .unknown)
        let sizeNoTerraceUnknownSize = fit(makeCafe(indoor: true, terrace: true, sizeIndoor: .small), .medium)
        XCTAssertEqual(sizeNoTerraceUnknownSize.indoor, .doesNotFit(.sizeLimit(.small)))
        XCTAssertEqual(sizeNoTerraceUnknownSize.terrace, .unknown(.sizeNotStated))
        XCTAssertEqual(sizeNoTerraceUnknownSize.overall, .unknown)
    }

    // MARK: - 未確認・犬不可

    func test_未確認の店は常に分からない() {
        let cafe = makeCafe(status: .unverified, indoor: true, terrace: true, sizeIndoor: .large)
        let result = fit(cafe, .small)
        XCTAssertEqual(result.overall, .unknown)
        XCTAssertEqual(result.indoor, .unknown(.unverified))
        XCTAssertEqual(result.terrace, .unknown(.unverified))
    }

    func test_確認日のない店は常に分からない() {
        let cafe = makeCafe(indoor: true, terrace: true, styles: [.floor], lastVerified: nil)
        let result = fit(cafe, .small, styles: [.floor])
        XCTAssertEqual(result.overall, .unknown)
        XCTAssertTrue(result.matchedStyles.isEmpty)
    }

    func test_犬同伴不可の店は入れない() {
        let result = fit(makeCafe(status: .notAllowed, indoor: true), .small)
        XCTAssertEqual(result.overall, .doesNotFit)
        XCTAssertEqual(result.reasonText, "犬の同伴は不可")
    }

    func test_設備情報がまったく無い店は分からない() {
        var cafe = makeCafe()
        cafe.dogAmenities = nil
        XCTAssertEqual(fit(cafe, .small).overall, .unknown)
    }

    // MARK: - 過ごし方は判定に使わない（補足だけ）

    func test_過ごし方が一致してもしなくても判定は変わらない() {
        let withStyle = makeCafe(indoor: true, styles: [.carrier])
        let without = makeCafe(indoor: true, styles: nil)
        for size in DogSize.allCases {
            XCTAssertEqual(
                fit(withStyle, size, styles: [.carrier]).overall,
                fit(without, size, styles: [.carrier]).overall
            )
            XCTAssertEqual(fit(withStyle, size, styles: [.floor]).overall, fit(withStyle, size).overall)
        }
    }

    func test_過ごし方はindoor_styleに含まれるものだけが補足になる() {
        let cafe = makeCafe(indoor: true, styles: [.floor, .carrier])
        let result = fit(cafe, .small, styles: [.carrier, .hold])
        XCTAssertEqual(result.matchedStyles, [.carrier])
        XCTAssertEqual(result.styleNote, "カート・キャリーでの入店が明記されています")
    }

    func test_含まれていない過ごし方を不可とは扱わない() {
        let cafe = makeCafe(indoor: true, styles: [.carrier])
        let result = fit(cafe, .small, styles: [.floor])
        XCTAssertTrue(result.matchedStyles.isEmpty)
        XCTAssertNil(result.styleNote)
        XCTAssertEqual(result.overall, .fits)
    }

    func test_店内に入れないと分かっているときは過ごし方の補足を出さない() {
        let cafe = makeCafe(indoor: true, terrace: true, sizeIndoor: .small, styles: [.carrier])
        let result = fit(cafe, .large, styles: [.carrier])
        XCTAssertEqual(result.matchedStyles, [.carrier])
        XCTAssertNil(result.styleNote)
    }

    // MARK: - 文言

    func test_タグはうちの子OKのときだけ() {
        XCTAssertEqual(fit(makeCafe(indoor: true), .small).tagLabel, "うちの子OK")
        XCTAssertNil(fit(makeCafe(indoor: true), .medium).tagLabel)
        XCTAssertNil(fit(makeCafe(indoor: false, terrace: false), .small).tagLabel)
    }

    func test_詳細の1行_店内で過ごせる() {
        let result = fit(makeCafe(indoor: true), .small)
        XCTAssertEqual(result.detailLine, "うちの子（小型犬）は：店内で過ごせます")
    }

    func test_詳細の1行_条件つきの店で入れるときは条件ありを添える() {
        let cafe = makeCafe(status: .conditional, indoor: true)
        XCTAssertEqual(fit(cafe, .small).detailLine, "うちの子（小型犬）は：店内で過ごせます（条件あり）")
        // 無条件（allowed）の店には添えない
        XCTAssertEqual(fit(makeCafe(status: .allowed, indoor: true), .small).detailLine, "うちの子（小型犬）は：店内で過ごせます")
        // 条件つきでも、分からない・入れないときは添えない
        XCTAssertFalse(fit(cafe, .medium).detailLine.contains("条件あり"))
        let closed = makeCafe(status: .conditional, indoor: true, sizeIndoor: .small)
        XCTAssertFalse(fit(closed, .large).detailLine.contains("条件あり"))
        // テラス席の言い方でも末尾に添える
        let terrace = makeCafe(status: .conditional, indoor: false, terrace: true)
        XCTAssertEqual(
            fit(terrace, .small).detailLine,
            "うちの子（小型犬）は：テラス席なら過ごせます（店内は不可・条件あり）"
        )
        // 店内に上限があるときも括弧は1つにまとめる
        let limited = makeCafe(status: .conditional, indoor: true, terrace: true, sizeIndoor: .medium, sizeTerrace: .large)
        XCTAssertEqual(
            fit(limited, .large).detailLine,
            "うちの子（大型犬）は：テラス席なら過ごせます（店内は中型犬まで・条件あり）"
        )
    }

    func test_詳細の1行_テラス席なら過ごせる_店内は上限あり() {
        let cafe = makeCafe(indoor: true, terrace: true, sizeIndoor: .medium, sizeTerrace: .large)
        XCTAssertEqual(
            fit(cafe, .large).detailLine,
            "うちの子（大型犬）は：テラス席なら過ごせます（店内は中型犬まで）"
        )
    }

    func test_詳細の1行_テラス席なら過ごせる_店内は不可() {
        let cafe = makeCafe(indoor: false, terrace: true)
        XCTAssertEqual(
            fit(cafe, .small).detailLine,
            "うちの子（小型犬）は：テラス席なら過ごせます（店内は不可）"
        )
    }

    func test_詳細の1行_店内の可否が空でテラスが入れるときは店内に触れない() {
        let cafe = makeCafe(indoor: nil, terrace: true)
        XCTAssertEqual(fit(cafe, .small).detailLine, "うちの子（小型犬）は：テラス席なら過ごせます")
    }

    func test_詳細の1行_入れない() {
        let cafe = makeCafe(indoor: true, terrace: true, sizeIndoor: .medium, sizeTerrace: .medium)
        let result = fit(cafe, .large)
        XCTAssertEqual(result.detailLine, "うちの子（大型犬）は：入れません（店内は中型犬まで・テラスは中型犬まで）")
        XCTAssertEqual(result.rowNote, "うちの子は不可（店内は中型犬まで・テラスは中型犬まで）")
    }

    func test_行の注記_店内だけの店で店内に入れない() {
        let cafe = makeCafe(indoor: true, terrace: false, sizeIndoor: .medium)
        let result = fit(cafe, .large)
        XCTAssertEqual(result.rowNote, "うちの子は不可（店内は中型犬まで・テラスは不可）")
    }

    func test_詳細の1行_サイズの記載がない() {
        let result = fit(makeCafe(indoor: true), .medium)
        XCTAssertEqual(result.detailLine, "うちの子（中型犬）は：サイズの記載がないため、来店前に確認を")
        XCTAssertNil(result.rowNote)
        XCTAssertNil(result.tagLabel)
    }

    func test_詳細の1行_サイズの条件がある() {
        let result = fit(makeCafe(indoor: true, sizeLimitText: "中型犬までOK"), .small)
        XCTAssertEqual(result.detailLine, "うちの子（小型犬）は：サイズの条件があるため、来店前に確認を")
    }

    func test_詳細の1行_席の記載がない() {
        let result = fit(makeCafe(), .small)
        XCTAssertEqual(result.detailLine, "うちの子（小型犬）は：席の種類の記載がないため、来店前に確認を")
    }

    func test_詳細の1行_未確認() {
        let result = fit(makeCafe(status: .unverified, indoor: true), .small)
        XCTAssertEqual(result.detailLine, "うちの子（小型犬）は：まだ確認できていないため、来店前に確認を")
    }

    // MARK: - 安全性（総当たり）

    /// 「うちの子OK」は、少なくとも1つの席が可と明記されていて、かつサイズが明記で収まる
    /// （上限内、または上限なしで小型犬／大型犬可）ときだけ。どの組み合わせでも推測で OK を出さない。
    func test_総当たり_fitsは明記された事実があるときだけ() {
        let flags: [Bool?] = [nil, false, true]
        let sizes: [DogSize?] = [nil, .small, .medium, .large]
        for indoor in flags { for terrace in flags {
            for sizeIndoor in sizes { for sizeTerrace in sizes {
                for largeDogs in flags { for hasText in [false, true] {
                    for dogSize in DogSize.allCases {
                        let cafe = makeCafe(
                            indoor: indoor, terrace: terrace, largeDogs: largeDogs,
                            sizeIndoor: sizeIndoor, sizeTerrace: sizeTerrace,
                            sizeLimitText: hasText ? "条件あり" : nil
                        )
                        let result = fit(cafe, dogSize)
                        // 片方の席にでも上限の明記があれば、large_dogs での補完はしない
                        let anyLimit = sizeIndoor != nil || sizeTerrace != nil
                        func seatFits(_ allowed: Bool?, _ max: DogSize?) -> Bool {
                            guard allowed == true else { return false }
                            if let max { return dogSize <= max }
                            if hasText { return false }
                            return dogSize == .small || (largeDogs == true && !anyLimit)
                        }
                        let expected = seatFits(indoor, sizeIndoor) || seatFits(terrace, sizeTerrace)
                        XCTAssertEqual(result.overall == .fits, expected)
                        if result.overall == .doesNotFit {
                            XCTAssertFalse(expected)
                        }
                    }
                }}
            }}
        }}
    }
}
