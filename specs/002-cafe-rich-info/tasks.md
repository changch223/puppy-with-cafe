---
description: "Task list for 002-cafe-rich-info（カフェ詳細の充実）"
---

# Tasks: カフェ詳細の充実（002-cafe-rich-info）

**Input**: `specs/002-cafe-rich-info/`（spec.md / plan.md）
**Tests**: 憲章IV — 営業中判定（OpeningHoursEvaluator）とエクスポート検証はテスト必須。UIは quickstart 手動確認。

## Phase 1: データパイプライン

- [x] T101 Sheet テンプレートに列追加（phone/reservation/hours_*/link_*/dog_*/info_verified/insta_note*）＋サンプル値 in `tools/sheet_template/cafes.csv`
- [x] T102 export_cafes.py 拡張: 新列のパース・検証（時刻形式/open<close/URL/bool/メモ確認日必須, FR-105）→ JSON 出力 in `tools/export_cafes.py`
- [x] T103 tools/README.md に列仕様を追記 in `tools/README.md`
- [x] T104 cafes.json 再生成（サンプルに新情報を含める）＋契約書追記 in `data/cafes.json`, `specs/001-dog-cafe-map/contracts/cafes-json-schema.md`

## Phase 2: アプリ（モデル・ロジック）

- [x] T105 追加モデル（CafeLink/OpeningHours/DogAmenities/OperatorNote）＋ Cafe に Optional 追加（後方互換）in `DokoWanCafe/DokoWanCafe/Models/`
- [x] T106 OpeningHoursEvaluator（Asia/Tokyo・営業中/時間外/本日定休/不明, FR-102）in `DokoWanCafe/DokoWanCafe/Core/OpeningHoursEvaluator.swift`
- [x] T107 [P] OpeningHoursEvaluator ユニットテスト（営業中/境界/複数帯/定休/不明）in `DokoWanCafe/DokoWanCafeTests/OpeningHoursEvaluatorTests.swift`

## Phase 3: アプリ（UI）

- [x] T108 詳細: 犬向け設備セクション（4項目 ✓/✕/不明 ＋自由記述, FR-104）in `DokoWanCafe/DokoWanCafe/Features/CafeDetail/CafeDetailView.swift`
- [x] T109 詳細: 営業時間セクション（バッジ＋曜日別/テキスト＋確認日）と 基本情報拡張（電話タップ発信・予約, FR-106）in 同上
- [x] T110 詳細: 公式リンク集＋運営転記メモ（出どころ・確認日つき, FR-103）in 同上
- [x] T111 一覧: 営業バッジ（構造化がある店のみ, FR-102）in `DokoWanCafe/DokoWanCafe/Features/CafeList/CafeListView.swift`

## Phase 4: 検証

- [ ] T112 全ユニットテスト緑＋シミュレータでの表示確認 ※テスト49件全緑・ビルドOK。**残り: 実機/シミュレータでの詳細画面の目視確認（ユーザー）**
