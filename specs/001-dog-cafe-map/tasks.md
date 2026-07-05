---
description: "Task list for DokoWanCafe — 犬同伴OKカフェの地図検索"
---

# Tasks: DokoWanCafe — 犬同伴OKカフェの地図検索

**Input**: Design documents from `/specs/001-dog-cafe-map/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: 憲章 原則IV に基づき、**Core/ の純ロジック（距離・フィルタ・名寄せ・矛盾解決・鮮度）にのみユニットテスト必須**。UIは主要フローの手動/quickstart検証で足りる（全面TDDは課さない）。

**Organization**: タスクはユーザーストーリー単位。各ストーリーは独立して実装・テスト・デモ可能。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可（別ファイル・未完了依存なし）
- **[Story]**: US1〜US5（Setup/Foundational/Polish はラベルなし）

## Path Conventions

- iOSアプリ: `DokoWanCafe/DokoWanCafe/...`（Xcodeプロジェクト）、テスト: `DokoWanCafe/DokoWanCafeTests/...`
- バックエンド定義: `supabase/...`

---

## Phase 1: Setup（共有基盤の初期化）

**Purpose**: プロジェクトと開発環境の用意

- [x] T001 Xcode プロジェクト（iOS 16+ / SwiftUI App）を作成 in `DokoWanCafe/`
- [x] T002 バックエンド接続基盤 in `DokoWanCafe/` ※実装変更: supabase-swift SDK ではなく URLSession ベースの内製ゲートウェイ（`Services/SupabaseGateway.swift`）を採用（必要操作は RPC/select/insert/Auth の4つのみ・憲章V の依存最小化。外部パッケージ依存ゼロ）
- [x] T003 [P] ソース構成フォルダを作成（App/Features/Models/Services/Core/Resources）in `DokoWanCafe/DokoWanCafe/`
- [x] T004 [P] SwiftLint/SwiftFormat 設定 in `.swiftlint.yml`
- [x] T005 [P] String Catalog（日本語第一）作成 in `DokoWanCafe/DokoWanCafe/Resources/Localizable.xcstrings`
- [x] T006 [P] Privacy Manifest と位置情報用途文言 in `DokoWanCafe/DokoWanCafe/Resources/PrivacyInfo.xcprivacy` および `Info.plist`（`NSLocationWhenInUseUsageDescription`）
- [ ] T007 Supabase プロジェクト作成と接続設定（URL/anon key を安全注入、機密はリポジトリに含めない）in `DokoWanCafe/DokoWanCafe/App/AppConfig.swift` ※クライアント側は実装済み（環境変数 SUPABASE_URL/SUPABASE_ANON_KEY をスキームで注入・未設定時はサンプルモード）。**残り: あなたの Supabase アカウントでプロジェクト作成＋migrations/seed 適用＋Apple サインイン有効化**（quickstart.md 手順1〜2）

---

## Phase 2: Foundational（全ストーリーの前提・ブロッキング）

**⚠️ CRITICAL**: このフェーズ完了までユーザーストーリー実装は開始不可

- [x] T008 Supabase migration: PostGIS有効化＋`cafes`/`sources`/`corrections` テーブルと制約 in `supabase/migrations/0001_init.sql`（`contracts/db-schema.md` 準拠）
- [x] T009 Supabase migration: `cafe_conflicts` ビューと `nearby_cafes` RPC in `supabase/migrations/0002_rpc_views.sql`
- [x] T010 Supabase migration: RLS ポリシー（閲覧公開／`corrections` は認証insert／更新は運営）in `supabase/migrations/0003_rls.sql`
- [ ] T011 東京の種データを手動整備（数十件。`conditional`・出典矛盾・`ai_inferred` を各1件以上含む）in `supabase/seed/tokyo_seed.sql` ※開発検証用の**架空サンプル7件**（全検証パターン含む）は作成済み。**残り: 実在カフェの手動確認・整備（運営作業。憲章 原則I: 出典・確認日必須）**
- [x] T012 [P] 列挙型（DogPolicyStatus/SourceType/Provenance/CorrectionStatus/SubmitterType）in `DokoWanCafe/DokoWanCafe/Models/Enums.swift`
- [x] T013 [P] Codable ドメインモデル（Cafe/Source/Conflict/Correction）in `DokoWanCafe/DokoWanCafe/Models/`
- [x] T014 SupabaseGateway（クライアント初期化・セッション保持）in `DokoWanCafe/DokoWanCafe/Services/SupabaseGateway.swift`
- [x] T015 CafeRepository プロトコル＋Supabase実装（nearby / detail）in `DokoWanCafe/DokoWanCafe/Services/CafeRepository.swift`
- [x] T016 [P] DistanceCalculator（純ロジック）in `DokoWanCafe/DokoWanCafe/Core/DistanceCalculator.swift`
- [x] T017 [P] DistanceCalculator ユニットテスト in `DokoWanCafe/DokoWanCafeTests/DistanceCalculatorTests.swift`
- [x] T018 [P] CafeDeduplicator（place_id優先／名称正規化＋位置近接, FR-030）in `DokoWanCafe/DokoWanCafe/Core/CafeDeduplicator.swift`
- [x] T019 [P] CafeDeduplicator ユニットテスト in `DokoWanCafe/DokoWanCafeTests/CafeDeduplicatorTests.swift`
- [x] T020 LocationService（CoreLocation WhenInUse／不許可時は手動エリア指定 fallback, FR-016/017）in `DokoWanCafe/DokoWanCafe/Services/LocationService.swift`
- [x] T021 App スキャフォールド（ナビゲーション・DI・共通エラー/空状態基盤）in `DokoWanCafe/DokoWanCafe/App/`
- [x] T059 nearby_cafes RPC と RLS の契約テスト（半径・only_dog_ok・距離昇順・登録データの表示漏れなし=SC-005／未認証の corrections insert 拒否・未承認提案の非反映=SC-008）in `supabase/tests/contract_tests.sql`

**Checkpoint**: 基盤完了 → ユーザーストーリー着手可能

---

## Phase 3: User Story 1 - 現在地から周辺の犬同伴OKカフェを地図と一覧で見つける (Priority: P1) 🎯 MVP

**Goal**: 現在地起点で周辺の犬OKカフェを地図＋一覧＋距離で表示、可否で絞り込み。

**Independent Test**: 位置を東京に設定して起動 → 5秒以内に地図中心＝現在地・周辺ピン・距離つき一覧が出る。距離順並び替えと「可のみ」フィルタが機能する（SC-001/002/005）。

- [x] T022 [US1] CafeListViewModel（現在地取得→`nearby_cafes`→距離算出→距離順）in `DokoWanCafe/DokoWanCafe/Features/CafeList/CafeListViewModel.swift`
- [x] T023 [P] [US1] 可否フィルタ純ロジック（可/条件付きのみ 等, FR-004）in `DokoWanCafe/DokoWanCafe/Core/CafeFilter.swift`
- [x] T024 [P] [US1] CafeFilter ユニットテスト in `DokoWanCafe/DokoWanCafeTests/CafeFilterTests.swift`
- [x] T025 [US1] 一覧View（距離順・可否バッジ・距離表示・フィルタUI）in `DokoWanCafe/DokoWanCafe/Features/CafeList/CafeListView.swift`
- [x] T026 [US1] 地図View（MKMapView を UIViewRepresentable で橋渡し＋クラスタリング＋ピン）in `DokoWanCafe/DokoWanCafe/Features/Map/MapView.swift`
- [x] T027 [US1] MapViewModel（一覧と同一 Repository 結果を共有し乖離させない, FR-003）in `DokoWanCafe/DokoWanCafe/Features/Map/MapViewModel.swift`
- [x] T028 [US1] 地図⇄一覧の切替・連動と現在地中心表示 in `DokoWanCafe/DokoWanCafe/Features/Map/`
- [x] T029 [US1] 空状態（0件→範囲拡大導線）とローディング表示（FR-020）in `DokoWanCafe/DokoWanCafe/Features/CafeList/`
- [x] T030 [P] [US1] 距離・可否ラベルのローカライズ文字列 in `DokoWanCafe/DokoWanCafe/Resources/Localizable.xcstrings`
- [x] T060 [US1] 対象エリア判定と「現在は東京のみ対応」の明示表示（エリア外を0件と誤認させない, FR-022）in `DokoWanCafe/DokoWanCafe/Core/SupportedArea.swift` および `DokoWanCafe/DokoWanCafe/Features/CafeList/`
- [x] T061 [P] [US1] SupportedArea ユニットテスト in `DokoWanCafe/DokoWanCafeTests/SupportedAreaTests.swift`

**Checkpoint**: US1 単独で動作・デモ可能（= MVP 成立）

---

## Phase 4: User Story 2 - カフェの犬同伴可否と情報の鮮度を確認する (Priority: P2)

**Goal**: 詳細で可否ステータス・条件・出典・最終確認日を提示、未確認/古さを区別。

**Independent Test**: カフェ詳細で可否/条件/出典/最終確認日が表示され、出典なしは「未確認」、古い確認日は警告が出る（SC-003）。

- [x] T031 [US2] CafeDetailViewModel（cafe＋sources 取得）in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/CafeDetailViewModel.swift`
- [x] T032 [US2] 詳細View（可否ステータス・条件・出典・最終確認日, FR-006/007/008）in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/CafeDetailView.swift`
- [x] T033 [P] [US2] FreshnessEvaluator（最終確認日>365日で古い警告, FR-010）in `DokoWanCafe/DokoWanCafe/Core/FreshnessEvaluator.swift`
- [x] T034 [P] [US2] FreshnessEvaluator ユニットテスト in `DokoWanCafe/DokoWanCafeTests/FreshnessEvaluatorTests.swift`
- [x] T035 [US2] 未確認/出典なしの視覚的区別表示（FR-009）in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/`
- [x] T036 [P] [US2] 詳細画面のローカライズ文字列 in `DokoWanCafe/DokoWanCafe/Resources/Localizable.xcstrings`

**Checkpoint**: US1＋US2 が独立動作

---

## Phase 5: User Story 3 - 利用者が誤りを報告し、運営承認を経て反映される (Priority: P2)

**Goal**: サインインした利用者が誤り報告・修正提案を送信、pending 保存、運営承認で反映（v1は運営承認のみ）。

**Independent Test**: 未サインインで報告→サインイン誘導、サインイン後送信→表示は不変(pending)、Supabaseダッシュボードで承認→反映、却下→非反映（SC-008）。

- [x] T037 [US3] AuthService（Appleでサインイン→Supabase Auth、トークンをKeychain, FR-028）in `DokoWanCafe/DokoWanCafe/Services/AuthService.swift`
- [x] T038 [US3] サインイン導線（投稿時のみ要求・未サインインは誘導）in `DokoWanCafe/DokoWanCafe/Features/Auth/`
- [x] T039 [US3] CorrectionService（`corrections` へ insert、submitter=auth.uid, FR-023/024）in `DokoWanCafe/DokoWanCafe/Services/CorrectionService.swift`
- [x] T040 [US3] 報告・修正提案フォーム（可否/条件/自由記述）View＋ViewModel in `DokoWanCafe/DokoWanCafe/Features/Report/`
- [x] T041 [US3] 送信後は pending・即時反映されないことの確認表示（FR-024）in `DokoWanCafe/DokoWanCafe/Features/Report/`
- [x] T042 [P] [US3] 運営承認の運用手順（ダッシュボード流用）in `supabase/README-moderation.md`
- [x] T043 [US3] 反映処理（`applied` 時に cafe/source 更新・由来 `user_submitted_verified`/`operator_verified`・確認日更新, FR-025/026）in `supabase/migrations/0004_apply_correction.sql`

**Checkpoint**: 是正ループが機能（投稿→承認→反映、却下は非反映）

---

## Phase 6: User Story 4 - 出典の矛盾検出とAI推測情報の区別を確認する (Priority: P3)

**Goal**: 出典間の矛盾を提示、代表可否の根拠を辿れる、AI推測を明示区別。

**Independent Test**: 矛盾を仕込んだカフェで矛盾提示と各出典の可否/確認日が見え、`ai_inferred` が確定情報と区別される（SC-004/007）。

- [x] T044 [P] [US4] ConflictResolver（確認日最新→由来の信頼順→未確認, FR-013）in `DokoWanCafe/DokoWanCafe/Core/ConflictResolver.swift`
- [x] T045 [P] [US4] ConflictResolver ユニットテスト（FR-013 の各分岐）in `DokoWanCafe/DokoWanCafeTests/ConflictResolverTests.swift`
- [x] T046 [US4] 詳細に矛盾提示（出典間の食い違い・各出典の可否/確認日, FR-011）in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/`
- [x] T047 [US4] AI推測（`provenance = ai_inferred`）の明示ラベル・区別表示（FR-012）in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/`
- [x] T048 [P] [US4] 代表可否の根拠（representative_source）と `has_conflict` の反映表示 in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/`

**Checkpoint**: 信頼性表示が完成

---

## Phase 7: User Story 5 - カフェ詳細を確認し、外部地図アプリで経路案内する (Priority: P3)

**Goal**: 詳細から住所/連絡先/出典リンクを確認し、外部地図アプリで経路案内を起動。

**Independent Test**: 詳細から経路案内→外部地図が当該カフェを目的地に開く。住所/出典リンクが見える（FR-014/015）。

- [x] T049 [US5] 外部地図アプリでの経路起動（`MKMapItem.openMaps`）in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/`
- [x] T050 [US5] 住所・連絡先・出典リンク表示 in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/`

**Checkpoint**: 発見→信頼→来店の導線が完成

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 複数ストーリーに跨る品質・横断要件

- [x] T051 [P] オフラインキャッシュ（CacheStore＋Repository統合、鮮度/「最新でない可能性」表示, FR-029）in `DokoWanCafe/DokoWanCafe/Services/CacheStore.swift`
- [x] T052 [P] アクセシビリティ（VoiceOverラベル・Dynamic Type）を主要フローに適用（FR-031）in `DokoWanCafe/DokoWanCafe/Features/`
- [x] T053 [P] プライバシー最終確認（位置の非保存・Privacy Manifest 整合, 憲章III）
- [x] T054 [P] パフォーマンス調整（位置許可→表示5秒以内・地図60fps・クラスタリング, SC-001）
- [x] T055 [P] ローカライズ総点検（ハードコード無し・日付/距離のロケール表示, FR-019）
- [ ] T056 [Spike] 外部集約の取得手段（公式API候補・利用規約/著作権適合）を決定し `specs/001-dog-cafe-map/research.md` の R8 に追記 ※**未決定（意図的保留）**: 利用規約・コスト・法務の確認を伴うユーザー判断事項。MVP は手動種データで成立するためブロッカーではない
- [ ] T057 quickstart.md の検証シナリオ実行（US1〜US5＋横断）in `specs/001-dog-cafe-map/quickstart.md` ※**部分完了**: ユニットテスト34件全緑＋シミュレータ（iPhone 17・東京駅・サンプルモード）で US1 の地図/ピン/クラスタリング/バナー表示を実機確認済み。**残り: Supabase 設定後（T007）の実データ・US3 サインイン〜承認フローのエンドツーエンド検証**
- [x] T058 [P] AI自動スクリーニング（第2段階）Edge Function の設計メモ in `supabase/functions/ai-screen/README.md`

---

## Dependencies & Execution Order

### Phase Dependencies
- **Setup (P1)**: 依存なし・即着手可
- **Foundational (P2)**: Setup 完了後。全ユーザーストーリーをブロック
- **User Stories (P3〜P7)**: Foundational 完了後に着手。優先度順（US1→US2→US3→US4→US5）または並行
- **Polish (P8)**: 対象ストーリー完了後

### User Story Dependencies
- **US1 (P1)**: Foundational のみに依存（他ストーリー非依存）= MVP
- **US2 (P2)**: Foundational 依存。US1 の詳細導線を利用するが単独テスト可
- **US3 (P2)**: Foundational＋Auth。US1/US2 と独立してテスト可
- **US4 (P3)**: Foundational 依存。詳細画面（US2）に矛盾/AI表示を足す形
- **US5 (P3)**: Foundational 依存。詳細画面に経路/リンクを足す形

### 各ストーリー内
- モデル → サービス → ViewModel → View の順
- Core純ロジックとそのテストは先行して並行可

---

## Parallel Opportunities

- **Setup**: T003/T004/T005/T006 は [P] 並行
- **Foundational**: モデル系 T012/T013、Core系 T016+T017 / T018+T019 は [P] 並行（DBマイグレーション T008→T009→T010→T011 は順次）
- **US1**: T023+T024（フィルタ＋テスト）、T030 は [P]。ViewModel/View 群は同一機能領域で一部順次
- **横断**: Polish の T051〜T055/T058 は [P] 並行

### Parallel Example: Foundational の Core ロジック
```
T016 DistanceCalculator + T017 test
T018 CafeDeduplicator + T019 test
（別ファイル・依存なしのため同時進行可）
```

---

## Implementation Strategy

### MVP First（US1 のみ）
1. Phase 1 Setup 完了
2. Phase 2 Foundational 完了（DB/種データ/モデル/Repository/位置/距離）
3. Phase 3 US1 完了 → **STOP して検証**（現在地→地図＋一覧＋距離＋フィルタ）
4. デモ/リリース可能な MVP

### Incremental Delivery
- MVP(US1) → US2(信頼情報) → US3(是正ループ) → US4(矛盾/AI区別) → US5(経路) の順で価値を積み増し、各段でリリース可能

---

## Notes

- テストは Core 純ロジック（距離/フィルタ/名寄せ/矛盾解決/鮮度/エリア判定）＋バックエンド契約テスト（T059）を必須とする（憲章IV）。UIは quickstart で検証
- T059〜T061 は `/speckit-analyze` の指摘（C1/C2）による追補。ID は追番だが**実行順は記載フェーズに従う**（T059=Phase 2、T060/T061=Phase 3）
- [P] = 別ファイル・依存なし。同一ファイルへの変更は順次
- 各タスク完了ごとにコミット推奨
- 機密（Supabase URL/key）はコミットしない
- **T056（外部集約の取得手段）** は MVP を止めない（手動種DBで US1〜US5 は検証可能）。実データ拡大の前に決定する
