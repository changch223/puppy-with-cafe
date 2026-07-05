# Phase 1 Data Model: DokoWanCafe

仕様の Key Entities と機能要件から、サーバ（Supabase/Postgres）と端末（キャッシュ/ドメインモデル）で共有する論理データモデルを定義する。実DDLは [contracts/db-schema.md](./contracts/db-schema.md) を参照。

## 列挙型

- **DogPolicyStatus**: `allowed`（可） / `conditional`（条件付き） / `not_allowed`（不可） / `unverified`（未確認）
- **SourceType**: `official_hp` / `sns` / `google_map` / `tabelog` / `blog` / `other`
- **Provenance**（由来・信頼順の高い順）: `official` / `operator_verified`（運営確認） / `human_verified`（人手確認） / `user_submitted_verified`（利用者提案(検証済み)） / `aggregated`（外部集約） / `ai_inferred`（AI推測）
- **CorrectionStatus**: `pending`（未審査） / `ai_checked`（AI確認済み） / `operator_checked`（運営確認済み） / `applied`（反映済み） / `rejected`（却下）
- **SubmitterType**: `user` / `operator`

## エンティティ

### Cafe（カフェ）
| フィールド | 型 | 制約・備考 |
|---|---|---|
| id | UUID | PK |
| place_id | text | 外部場所ID。存在すれば一意（名寄せ主キー候補, FR-030） |
| name | text | NOT NULL |
| latitude | double | NOT NULL |
| longitude | double | NOT NULL |
| geo | geography(Point) | PostGIS。周辺検索・近接名寄せ用（lat/lng から生成） |
| address | text | 任意 |
| contact | text | 任意（電話/URL等） |
| dog_policy_status | DogPolicyStatus | NOT NULL。矛盾解決で算出した**代表可否**（FR-006/013） |
| dog_policy_condition | text | `conditional` のとき必須（FR-007） |
| last_verified | date | NOT NULL。代表となる最終確認日（FR-008/010） |
| representative_source_id | UUID | 代表可否の根拠となった Source（FR-013 の追跡） |
| has_conflict | bool | 出典間で可否が食い違うか（FR-011 の提示に使用） |
| is_closed | bool | 閉店/失効（Edge Case） |
| area | text | 提供エリア（v1: `tokyo`）。対象外判定（FR-022） |

- **関係**: 1 Cafe — N Source、1 Cafe — N Correction。
- **バリデーション**: `dog_policy_condition` は status=`conditional` で NOT NULL。`last_verified` 無し or `source` 無しなら status は `unverified` にする（FR-009）。
- **派生**: 現在地からの**距離**は保存せず、クライアントで `DistanceCalculator` により算出（プライバシー: 位置非保存）。

### Source（出典）
| フィールド | 型 | 制約・備考 |
|---|---|---|
| id | UUID | PK |
| cafe_id | UUID | FK → Cafe |
| type | SourceType | NOT NULL |
| reference | text | URL等（任意） |
| claimed_status | DogPolicyStatus | この出典が示す可否 |
| verified_at | date | この出典の確認日 |
| provenance | Provenance | NOT NULL（AI由来の明示区別 FR-012） |

- **用途**: 矛盾検出（同一 Cafe で `claimed_status` が割れる）と代表可否算出の入力。

### Correction（修正提案）
| フィールド | 型 | 制約・備考 |
|---|---|---|
| id | UUID | PK |
| cafe_id | UUID | FK → Cafe |
| submitter_type | SubmitterType | NOT NULL |
| submitter_id | UUID | 利用者提案はサインイン済みアカウントに紐づく（FR-028）。運営は運営ID |
| proposed_status | DogPolicyStatus | 任意（可否の修正提案） |
| proposed_condition | text | 任意（条件の修正） |
| note | text | 任意（自由記述の指摘） |
| status | CorrectionStatus | NOT NULL, 既定 `pending` |
| ai_review | jsonb | AI判定履歴（第2段階で使用, 任意） |
| operator_review | text | 運営判定メモ（任意） |
| applied_at | timestamptz | 反映日時（`applied` のとき） |
| created_at | timestamptz | NOT NULL |

- **状態遷移**（FR-024/027, R9）:
  - v1: `pending` → （運営承認）→ `applied` ／ （運営却下）→ `rejected`
  - 第2段階: `pending` → `ai_checked` → `operator_checked` → `applied` ／ 途中で `rejected`
  - **不変条件**: `applied` 以外は表示に反映されない（`rejected` は決して反映しない）。
- **反映**: `applied` 時に対象 Cafe/Source を更新し、由来を `user_submitted_verified` or `operator_verified` として記録。

### Conflict（矛盾）— 論理ビュー
- 同一 Cafe で複数 Source の `claimed_status` が割れる状態を表す。Postgres では**ビュー/集約**として導出（実体テーブルにしてもよい）。
- 属性: `cafe_id`, 食い違う `source` 集合, 採用された代表可否 (`Cafe.dog_policy_status`) と根拠 (`representative_source_id`)。
- 用途: 詳細画面での矛盾提示（FR-011）、`Cafe.has_conflict` の算出。

### UserLocation（利用者の現在地）— クライアント一時値
- `latitude`, `longitude`（または手動指定エリア）。**永続保存しない**（憲章III）。周辺検索クエリの入力にのみ使用。

## クライアント側ドメイン / キャッシュ
- 上記 Cafe/Source/Conflict を Codable なドメインモデルへマップ。
- **オフラインキャッシュ**（R3）: 直近取得の Cafe 一覧スナップショット＋`fetchedAt` をディスク保存。表示時に鮮度・「最新でない可能性」を付与（FR-029）。

## 主なインデックス / 整合
- `cafes.geo` に **GIST インデックス**（周辺検索・近接名寄せ）。
- `sources(cafe_id)`、`corrections(cafe_id, status)` にインデックス。
- `cafes.place_id` に部分ユニーク制約（NULL 許容）。
