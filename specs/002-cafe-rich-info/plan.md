# Implementation Plan: カフェ詳細の充実（002-cafe-rich-info）

**Branch**: `002-cafe-rich-info` | **Date**: 2026-07-05 | **Spec**: [spec.md](./spec.md)

## Summary

001 の構成B（Sheet → 検証済み cafes.json → バンドル＋静的URL）の上に、営業時間（テキスト＋任意の構造化→営業中バッジ）・電話/予約・公式リンク集・犬向け設備4項目・運営転記メモ（出どころ/確認日必須）を**後方互換のデータ追加**として実装する。新しいインフラ・依存は増やさない。

## Technical Context（001 からの差分のみ）

- **データ**: `tools/sheet_template/cafes.csv` に列追加 → `tools/export_cafes.py` で検証・正規化 → cafes.json（format_version は 1 のまま。アプリは未知キー無視＋Optional 追加で後方互換）
- **新規純ロジック**: `Core/OpeningHoursEvaluator`（Asia/Tokyo 固定で 営業中/時間外/本日定休 を判定。ユニットテスト必須＝憲章IV）
- **UI**: `CafeDetailView` に4セクション追加（犬向け設備／営業時間／基本情報拡張／公式リンク・転記メモ）、`CafeRowView` に営業バッジ
- **タイムゾーン**: Asia/Tokyo 固定（v1 東京のみ）。日跨ぎ営業はエクスポート時エラー（フリーテキストで表現）

## Constitution Check

| 原則 | 判定 | 担保 |
|---|---|---|
| I. 信頼できるデータ 🔒 | ✅ | 転記メモは出どころ＋確認日必須（FR-103）。未登録は「不明」（FR-104）。営業中は構造化データがある場合のみ表示＝推測しない（FR-102）。検証はエクスポートゲート（FR-105） |
| II〜VI | ✅ | 既存構成の拡張のみ。バッジ/設備表示は a11y ラベル付与。文字列は日本語ファースト |

**PASS（違反なし）**

## Sheet 列の追加（cafes タブ）

| 列 | 形式 | 例 |
|---|---|---|
| phone | 文字列 | 03-1234-5678 |
| reservation | 文字列 | 予約可（電話・当日可） |
| hours_text | 文字列 | 9:00〜18:00（L.O.17:30）不定休あり |
| hours_mon 〜 hours_sun | `HH:MM-HH:MM[,HH:MM-HH:MM]` / `定休` / 空=不明 | 9:00-18:00 |
| link_website / link_instagram / link_x / link_tabelog | URL | https://... |
| dog_indoor / dog_terrace / dog_large / dog_menu | true / false / 空=不明 | true |
| dog_note | 文字列 | カート必須・ワクチン証明の提示あり |
| info_verified | YYYY-MM-DD | 基本情報（営業時間等）の確認日 |
| insta_note | 文字列 | テラス席は雨天クローズ |
| insta_note_date | YYYY-MM-DD | 転記メモの確認日（メモがある場合必須） |

## cafes.json への追加（cafe 要素・すべて任意 → 後方互換）

```json
{
  "phone": "03-...", "reservation": "...", "hours_text": "...",
  "hours": {"mon": [{"open": "09:00", "close": "18:00"}], "tue": [], ...},
  "links": [{"type": "instagram", "url": "https://..."}],
  "dog_amenities": {"indoor": true, "terrace": null, "large_dogs": false, "dog_menu": true},
  "dog_note": "...",
  "info_verified": "2026-07-01",
  "operator_note": {"text": "...", "source": "instagram", "verified_at": "2026-07-01"}
}
```
- `hours` のキーが存在する曜日のみ判定対象。空配列＝定休。キー欠落＝不明（バッジなし）。
- 検証: 時刻形式・open<close・URL 形式・enum・メモの確認日必須（違反は配信拒否, FR-105/SC-104）。

## 実装ファイル

- `tools/export_cafes.py` 拡張＋ `tools/sheet_template/cafes.csv` 列追加＋ `tools/README.md` 列仕様追記
- `Models/CafeExtras.swift`（CafeLink/OpeningHours/DogAmenities/OperatorNote）＋ `Models/Cafe.swift` に Optional 追加
- `Core/OpeningHoursEvaluator.swift` ＋ `DokoWanCafeTests/OpeningHoursEvaluatorTests.swift`
- `Features/CafeDetail/CafeDetailView.swift`（セクション追加）／`Features/CafeList/CafeListView.swift`（営業バッジ）
- `contracts/`: 001 の `cafes-json-schema.md` に追記（002 追加分）

## スコープ外（v2 候補）

写真／Instagram 投稿のアプリ内埋め込み／「営業中のみ」「店内OKのみ」フィルタ／日跨ぎ営業の構造化
