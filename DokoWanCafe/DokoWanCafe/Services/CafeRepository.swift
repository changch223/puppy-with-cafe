import Foundation

/// カフェデータ取得の抽象（憲章 原則IV: プロトコル化してモック検証可能に）。
/// 地図・一覧は必ず同一 Repository の結果を共有する（FR-003）。
protocol CafeRepository: Sendable {
    /// 周辺検索（contracts/api-contracts.md #1）。距離昇順で返る。
    func nearbyCafes(
        latitude: Double,
        longitude: Double,
        radiusMeters: Int,
        onlyDogOK: Bool
    ) async throws -> [CafeWithDistance]

    /// カフェ詳細＋出典（contracts/api-contracts.md #2）
    func cafeDetail(id: UUID) async throws -> CafeDetail
}

// MARK: - Supabase 実装

struct SupabaseCafeRepository: CafeRepository {
    let gateway: SupabaseGateway

    private struct NearbyParams: Encodable {
        let lat: Double
        let lng: Double
        let radiusM: Int
        let onlyDogOk: Bool

        enum CodingKeys: String, CodingKey {
            case lat
            case lng
            case radiusM = "radius_m"
            case onlyDogOk = "only_dog_ok"
        }
    }

    func nearbyCafes(
        latitude: Double,
        longitude: Double,
        radiusMeters: Int,
        onlyDogOK: Bool
    ) async throws -> [CafeWithDistance] {
        try await gateway.rpc(
            "nearby_cafes",
            body: NearbyParams(lat: latitude, lng: longitude, radiusM: radiusMeters, onlyDogOk: onlyDogOK)
        )
    }

    func cafeDetail(id: UUID) async throws -> CafeDetail {
        let rows: [CafeDetail] = try await gateway.select(
            "cafes",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())"),
                URLQueryItem(name: "select", value: "*,sources(*)"),
            ]
        )
        guard let detail = rows.first else { throw SupabaseError.emptyResponse }
        return detail
    }
}

// MARK: - サンプルデータ実装（バックエンド未設定時）

/// バックエンド未設定時に使う架空のサンプルデータ（UI 検証・プレビュー用）。
/// すべて架空の店舗であり、実在のカフェ情報ではない。
/// UI 側は「サンプルデータ表示中」バナーで明示する（憲章 原則I: 誤認させない）。
struct SampleDataRepository: CafeRepository {
    static let referenceDate = Date()

    private static func day(_ daysAgo: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate
    }

    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    /// 架空のサンプルカフェ（東京駅〜銀座周辺の座標）
    static let cafes: [Cafe] = [
        Cafe(
            id: uuid(1), placeID: "sample-place-1",
            name: "サンプル・ドッグテラス丸の内",
            latitude: 35.6820, longitude: 139.7650,
            address: "東京都千代田区丸の内1-0-0（架空）", contact: "https://example.com/marunouchi",
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: day(20), representativeSourceID: sourceID(11),
            hasConflict: false, isClosed: false, area: "tokyo"
        ),
        Cafe(
            id: uuid(2), placeID: "sample-place-2",
            name: "サンプルカフェ 八重洲テラス",
            latitude: 35.6800, longitude: 139.7710,
            address: "東京都中央区八重洲1-0-0（架空）", contact: nil,
            dogPolicyStatus: .conditional, dogPolicyCondition: "テラス席のみ犬同伴可（架空の条件）",
            lastVerified: day(45), representativeSourceID: sourceID(21),
            hasConflict: false, isClosed: false, area: "tokyo"
        ),
        Cafe(
            id: uuid(3), placeID: "sample-place-3",
            name: "サンプル珈琲 日本橋",
            latitude: 35.6840, longitude: 139.7740,
            address: "東京都中央区日本橋1-0-0（架空）", contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: day(10), representativeSourceID: sourceID(31),
            hasConflict: true, isClosed: false, area: "tokyo"
        ),
        Cafe(
            id: uuid(4), placeID: "sample-place-4",
            name: "サンプル・レトロ喫茶 銀座",
            latitude: 35.6717, longitude: 139.7650,
            address: "東京都中央区銀座4-0-0（架空）", contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: day(500), representativeSourceID: sourceID(41),
            hasConflict: false, isClosed: false, area: "tokyo"
        ),
        Cafe(
            id: uuid(5), placeID: "sample-place-5",
            name: "サンプルベーカリー 京橋",
            latitude: 35.6770, longitude: 139.7700,
            address: "東京都中央区京橋2-0-0（架空）", contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: day(30), representativeSourceID: sourceID(51),
            hasConflict: false, isClosed: false, area: "tokyo"
        ),
        Cafe(
            id: uuid(6), placeID: "sample-place-6",
            name: "サンプル喫茶 神田",
            latitude: 35.6910, longitude: 139.7700,
            address: "東京都千代田区神田1-0-0（架空）", contact: nil,
            dogPolicyStatus: .unverified, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo"
        ),
        Cafe(
            id: uuid(7), placeID: "sample-place-7",
            name: "サンプルティールーム 有楽町",
            latitude: 35.6750, longitude: 139.7630,
            address: "東京都千代田区有楽町1-0-0（架空）", contact: nil,
            dogPolicyStatus: .notAllowed, dogPolicyCondition: nil,
            lastVerified: day(60), representativeSourceID: sourceID(71),
            hasConflict: false, isClosed: false, area: "tokyo"
        ),
    ]

    private static func sourceID(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", n))!
    }

    static let sources: [UUID: [Source]] = [
        uuid(1): [
            Source(id: sourceID(11), cafeID: uuid(1), type: .officialHP,
                   reference: "https://example.com/marunouchi",
                   claimedStatus: .allowed, verifiedAt: day(20), provenance: .operatorVerified),
        ],
        uuid(2): [
            Source(id: sourceID(21), cafeID: uuid(2), type: .officialHP,
                   reference: "https://example.com/yaesu",
                   claimedStatus: .conditional, verifiedAt: day(45), provenance: .operatorVerified),
            Source(id: sourceID(22), cafeID: uuid(2), type: .tabelog,
                   reference: "https://example.com/yaesu-tabelog",
                   claimedStatus: .conditional, verifiedAt: day(90), provenance: .aggregated),
        ],
        uuid(3): [
            // 出典間の矛盾サンプル（FR-011/US4 検証用）: 公式は「可」(新)、ブログは「不可」(古)
            Source(id: sourceID(31), cafeID: uuid(3), type: .officialHP,
                   reference: "https://example.com/nihonbashi",
                   claimedStatus: .allowed, verifiedAt: day(10), provenance: .operatorVerified),
            Source(id: sourceID(32), cafeID: uuid(3), type: .blog,
                   reference: "https://example.com/nihonbashi-blog",
                   claimedStatus: .notAllowed, verifiedAt: day(200), provenance: .aggregated),
        ],
        uuid(4): [
            Source(id: sourceID(41), cafeID: uuid(4), type: .sns,
                   reference: "https://example.com/ginza-sns",
                   claimedStatus: .allowed, verifiedAt: day(500), provenance: .humanVerified),
        ],
        uuid(5): [
            // AI推測サンプル（FR-012/US4 検証用）
            Source(id: sourceID(51), cafeID: uuid(5), type: .other,
                   reference: nil,
                   claimedStatus: .allowed, verifiedAt: day(30), provenance: .aiInferred),
        ],
        uuid(6): [],
        uuid(7): [
            Source(id: sourceID(71), cafeID: uuid(7), type: .googleMap,
                   reference: "https://example.com/yurakucho",
                   claimedStatus: .notAllowed, verifiedAt: day(60), provenance: .humanVerified),
        ],
    ]

    func nearbyCafes(
        latitude: Double,
        longitude: Double,
        radiusMeters: Int,
        onlyDogOK: Bool
    ) async throws -> [CafeWithDistance] {
        // nearby_cafes RPC と同じ契約をクライアント側で再現（半径・可否フィルタ・距離昇順）
        Self.cafes
            .filter { !$0.isClosed }
            .filter { !onlyDogOK || $0.dogPolicyStatus == .allowed || $0.dogPolicyStatus == .conditional }
            .map { cafe in
                CafeWithDistance(
                    cafe: cafe,
                    distanceMeters: DistanceCalculator.distanceMeters(
                        fromLatitude: latitude, fromLongitude: longitude,
                        toLatitude: cafe.latitude, toLongitude: cafe.longitude
                    )
                )
            }
            .filter { $0.distanceMeters <= Double(radiusMeters) }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    func cafeDetail(id: UUID) async throws -> CafeDetail {
        guard let cafe = Self.cafes.first(where: { $0.id == id }) else {
            throw SupabaseError.emptyResponse
        }
        return CafeDetail(cafe: cafe, sources: Self.sources[id] ?? [])
    }
}
