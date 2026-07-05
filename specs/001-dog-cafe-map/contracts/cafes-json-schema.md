# Contract: cafes.json（構成Bの正式データ契約）

アプリとデータパイプラインが共有する配信データの契約。生成は `tools/export_cafes.py` のみが行い、
**検証を通らないデータは配信されない**（憲章 原則I の実装点）。旧A案のDB契約は
[db-schema.md](./db-schema.md)（保管）を参照。

## 配信経路
1. `data/cafes.json` — リポジトリ内の正本（git 履歴＝変更履歴, FR-033）
2. `DokoWanCafe/DokoWanCafe/Resources/cafes.json` — アプリへのバンドル（オフライン初期データ）
3. 静的URL（GitHub Pages 等）— アプリが起動時に取得（15分スロットル）。取得失敗時はキャッシュ→バンドルへフォールバック（FR-029/032）

## トップレベル

```json
{
  "format_version": 1,
  "generated_at": "2026-07-05T02:41:00Z",
  "is_sample_data": true,
  "cafes": [ { ... } ]
}
```

| フィールド | 型 | 説明 |
|---|---|---|
| format_version | int | 契約バージョン。アプリは `1` 以外を**拒否**（不正データで壊さない） |
| generated_at | ISO8601 | 生成日時。UIに「データ更新: ○月○日時点」として提示（FR-032） |
| is_sample_data | bool | 架空サンプルなら true → アプリが警告バナーを表示（誤認防止） |

## cafe 要素

| フィールド | 型 | 制約 |
|---|---|---|
| id | UUID | 安定ID（CSVで空欄なら place_id / 名称+座標から決定論生成） |
| place_id | string? | 外部場所ID（名寄せ主キー, FR-030） |
| name | string | 必須 |
| latitude / longitude | double | 必須・範囲検証 |
| address / contact | string? | 任意 |
| dog_policy_status | enum | `allowed / conditional / not_allowed / unverified` — **出典から導出**（Sheetに直接書かない） |
| dog_policy_condition | string? | `conditional` のとき必須（FR-007） |
| last_verified | date? | 代表出典の確認日。`unverified` 以外は必須（FR-009） |
| representative_source_id | UUID? | 採用根拠（FR-013） |
| has_conflict | bool | 出典間で可否が割れているか（FR-011） |
| is_closed | bool | 閉店（表示除外） |
| area | string | 提供エリア（v1: `tokyo`） |
| sources | array | 出典（下表）。表示可否の根拠 |

## source 要素

| フィールド | 型 | 制約 |
|---|---|---|
| id | UUID | 決定論生成 |
| cafe_id | UUID | 親 |
| type | enum | `official_hp / sns / google_map / tabelog / blog / other` |
| reference | string? | 出典URL |
| claimed_status | enum | この出典が示す可否 |
| verified_at | date? | 確認日（`unverified` 以外は必須） |
| provenance | enum | `official / operator_verified / human_verified / user_submitted_verified / aggregated / ai_inferred`（AI推測は明示区別, FR-012） |

## 導出規則（エクスポート時に確定・アプリの ConflictResolver と同一）
1. 確認日が最新の出典を優先 → 2. 同日なら由来の信頼順 → 3. 確定不能なら `unverified`（憶測で可にしない）

## 検証（エクスポートがエラーで拒否するもの）
- enum 外の値／緯度経度が数値でない・範囲外
- `conditional` なのに条件テキストなし／`unverified` 以外なのに確認日なし
- place_id 重複／同名 50m 以内の別行（名寄せ疑い, FR-030）

## 互換性ポリシー
- **後方互換の追加**（新フィールド）は format_version を変えずに可（アプリは未知キーを無視する）
- 既存フィールドの意味変更・削除は format_version を上げ、アプリ側の対応と同時にリリースする
