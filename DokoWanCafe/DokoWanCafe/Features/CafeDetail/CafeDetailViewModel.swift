import Foundation
import MapKit

/// カフェ詳細の ViewModel（T031）。
/// 出典（sources）を取得し、矛盾解決（ConflictResolver）・鮮度（FreshnessEvaluator）を適用する。
@MainActor
final class CafeDetailViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var detail: CafeDetail?

    /// 一覧から渡される概要（詳細取得前の即時表示にも使う）
    let summary: Cafe

    private let repository: any CafeRepository

    init(cafe: Cafe, repository: any CafeRepository) {
        self.summary = cafe
        self.repository = repository
    }

    /// 表示に使うカフェ（詳細取得済みならその値・未取得なら概要）
    var cafe: Cafe { detail?.cafe ?? summary }

    var sources: [Source] { detail?.sources ?? [] }

    /// クライアント側でも FR-013 のルールで代表可否を検算（根拠の提示に使用, T048）
    var resolution: ConflictResolution? {
        guard detail != nil else { return nil }
        return ConflictResolver.resolve(sources: sources)
    }

    /// 矛盾提示（FR-011）: サーバ算出の has_conflict とクライアント検算のどちらかが真なら提示
    var hasConflict: Bool {
        cafe.hasConflict || (resolution?.hasConflict ?? false)
    }

    /// 代表可否の根拠となった出典（FR-013: 採用出典は常にたどれる）
    var representativeSource: Source? {
        if let id = cafe.representativeSourceID,
           let source = sources.first(where: { $0.id == id }) {
            return source
        }
        return resolution?.representativeSource
    }

    /// 最終確認日が古い（FR-010: 既定365日）
    var isStale: Bool {
        guard cafe.dogPolicyStatus != .unverified else { return false }
        return FreshnessEvaluator.isStale(lastVerified: cafe.lastVerified)
    }

    /// 出典・確認日を持たない「未確認」情報か（FR-009）
    var isUnverified: Bool {
        cafe.dogPolicyStatus == .unverified || cafe.lastVerified == nil
    }

    func load() async {
        phase = .loading
        do {
            detail = try await repository.cafeDetail(id: summary.id)
            phase = .loaded
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// 外部地図アプリで経路案内（FR-015/T049）
    func openInMaps() {
        let placemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: cafe.latitude, longitude: cafe.longitude)
        )
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = cafe.name
        mapItem.openInMaps(launchOptions: nil)
    }
}
