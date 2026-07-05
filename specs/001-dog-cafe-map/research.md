# Phase 0 Research: DokoWanCafe

技術上の未確定点と選定を、決定・根拠・代替案の形で整理する。すべて憲章（SwiftUI優先＋UIKit橋渡し / iOS 16+ / MVVM / 信頼性・プライバシー）に整合。

## R1. バックエンド基盤

- **Decision**: マネージドBaaS の **Supabase**（PostgreSQL + PostGIS、Auth、Row-Level Security、自動REST）を採用。自前サーバは持たない。
- **Rationale**: カフェ↔出典↔修正提案の**関係データ**と、周辺検索・名寄せに必要な**地理検索(PostGIS)** を素直に扱える。「Appleでサインイン」を標準サポート、RLSで「閲覧は誰でも／書き込みは本人・審査経由」を宣言的に表現できる。無料枠があり個人開発の固定コストを最小化。運営コンソールは**管理ダッシュボードを流用**でき自作不要。
- **Alternatives considered**:
  - Firebase/Firestore: リアルタイムは強いが、関係データ＋地理近接クエリ＋矛盾統合が不得手。
  - CloudKit: Apple純正で無料枠は魅力だが、運営モデレーションUI・サーバロジック・地理検索が弱い。
  - 自前サーバ（Vapor等）: 最も自由だが個人開発の運用コストが過大（YAGNI）。

## R2. 地図表示とクラスタリング

- **Decision**: 画面は SwiftUI。地図は **MKMapView を `UIViewRepresentable` で橋渡し**し、**MKMapView 標準のアノテーションクラスタリング**を利用。
- **Rationale**: 犬OKカフェが増えるとピンの重なり対策（クラスタリング）が必須。SwiftUI 標準 `Map`（iOS 16）はクラスタリング等の細かな制御が弱く、憲章V（必要箇所のみUIKit橋渡し）に合致。
- **Alternatives considered**: SwiftUI `Map` 単独（クラスタリング自作が必要で複雑化）／サードパーティ地図SDK（依存増・規約、不要）。

## R3. オフライン用ローカルキャッシュ

- **Decision**: **直近取得結果を Codable スナップショットとしてディスク保存**する軽量キャッシュ。取得時刻を併記し、オフライン時は「最新でない可能性」を明示。
- **Rationale**: 要件は「直近データの閲覧」であり全件同期は非対象（FR-029）。小規模データに重いDBは過剰。SwiftData は iOS 17+ のため最小iOS16と不整合、CoreData はオーバースペック。YAGNI。
- **Alternatives considered**: SwiftData（iOS17必須で不採用）／CoreData（関係DBだが今回のキャッシュ用途には過剰）／GRDB（依存追加、現時点で不要）。

## R4. 認証（Appleでサインイン）

- **Decision**: 閲覧は匿名可。**投稿時のみ** `AuthenticationServices` の Sign in with Apple を用い、**Supabase Auth** にID連携。トークンは Keychain。
- **Rationale**: FR-028 の「閲覧自由・投稿時サインイン必須」を最小構成で満たす。Supabase が Apple OIDC を標準サポート。
- **Alternatives considered**: 独自メール認証（摩擦大）／全画面ログイン必須（MVPに不利、Q1で不採用）。
- **前提**: App Store 配布・本番Appleサインインには Apple Developer Program（有料・年額）が必須。

## R5. 位置情報とプライバシー

- **Decision**: **CoreLocation を WhenInUse** で使用。周辺検索はサーバへ**検索座標のみ**送信し保存しない。`PrivacyInfo.xcprivacy` を同梱し用途文言（`NSLocationWhenInUseUsageDescription`）を明記。許可なし時は地名手動指定にフォールバック（FR-017）。
- **Rationale**: 憲章III（最小取得・非保存）とAppleプライバシー要件に適合。
- **Alternatives considered**: Always 権限（正当理由なく不要）。

## R6. 名寄せ（同一カフェ識別 / FR-030）

- **Decision**: **場所ID（外部の place_id）を主キー候補**とし、無い場合は **名称の正規化一致 ＋ 位置近接（例：半径約50m以内）** でマッチングして統合。処理は `Core/CafeDeduplicator` に純ロジックとして実装しユニットテスト。
- **Rationale**: 外部集約で同一店舗が重複する問題を、地理近接＋名称正規化で吸収。決定論でテスト可能。
- **Alternatives considered**: 名称＋住所文字列のみ（表記ゆれに弱い）／全件手動紐付け（初期の手間過大）。

## R7. 矛盾解決（代表可否 / FR-013）

- **Decision**: `Core/ConflictResolver` で決定論的に算出:
  1. **最終確認日が最新**の出典を優先
  2. 同日/不明なら **由来の信頼順**（公式・運営確認 > 人手確認 > 利用者提案(検証済み) > 外部集約 > AI推測）
  3. それでも確定不能なら **「未確認」**（憶測で「可」にしない）
  採用した出典（根拠）は常に保持し詳細でたどれる。
- **Rationale**: 憲章I（憶測で可にしない）と FR-013 を満たし、テスト容易。
- **Alternatives considered**: 多数決（新しい誤情報に引きずられる）／単純に最新のみ（信頼度差を無視）。

## R8. データ取得（初期整備＋外部集約の補助）

- **Decision**: 犬同伴可否は**運営が手動整備**（東京・数十件から）。住所・座標・店舗基本情報の補助として外部集約を用いる。**規約準拠の公式API（例：地図プラットフォームの Places 系API）を第一候補**とし、スクレイピングは規約・著作権リスクがあるため**採否・手段は別途決定（暫定・保留）**。
- **Rationale**: 核心（犬OK情報）は自動取得が困難なため手動が現実的（①）。補助データは規約準拠手段を優先しリスクを抑える（③）。
- **Alternatives considered**: 全自動集約のみ（犬OK可否が埋まらず製品不成立）／スクレイピング前提固定（法務リスクを未評価のまま固定するのは危険）。
- **Open（tasks/後続で判断）**: 具体的なAPI/データソース名、取得バッチの実装場所（ローカルスクリプト or Edge Function）、利用規約の適合確認。

## R9. モデレーション（段階導入）

- **Decision**: **v1 は運営承認のみ**。修正提案は `pending` で保存され、運営が Supabase ダッシュボードで承認/却下 → 承認分のみ反映（FR-024/027 を運営承認で満たす）。**AI自動スクリーニング（Claude API 等）は第2段階**として Supabase Edge Function で追加し、AI＋運営のダブルチェックへ拡張。
- **Rationale**: 最小工数で信頼ループを起動しつつ、将来のAIダブルチェック（到達目標）に無理なく拡張できる。
- **Alternatives considered**: 初めからAI＋運営（実装量が増え MVP を遅らせる）。

## R10. テスト戦略（憲章IV）

- **Decision**: `Core/`（距離・名寄せ・矛盾解決・フィルタ）と ViewModel のロジックを **XCTest でユニット必須**。ネットワーク/DBは Repository をプロトコル化しモックで検証。UIは主要フロー（現在地→一覧→詳細→報告）を **XCUITest** で最小限。
- **Rationale**: データ正確性に直結する部分を確実に自動検証（費用対効果重視）。
- **Alternatives considered**: 全面TDD（速度低下、憲章で不採用）／テストなし（データ品質リスク）。
