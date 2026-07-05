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

## Phase 5: 実データ対応（2026-07-05 追補: 天王洲CSVとの突き合わせ, FR-107）

- [x] T113 スキーマ追加4列（sub_area/description/dog_size_limit/holiday_note）＋ unknown/不明の空欄正規化＋Instagram @ハンドル→URL 変換 in `tools/export_cafes.py`
- [x] T114 実データマスター作成: 天王洲アイルの実在カフェ5件（WHAT CAFE / T.Y.HARBOR / RIDE / breadworks / Le Calin）を新スキーマへ移行 in `data/master/cafes.csv`, `data/master/sources.csv` ※出典は集約サイト由来のため provenance=aggregated・確認日2026-07-05
- [x] T115 テンプレート更新（新4列を含む全35列）in `tools/sheet_template/cafes.csv`
- [x] T116 アプリ対応: Cafe モデル4フィールド追加＋詳細画面表示（地区名・紹介文・サイズ制限・定休日）＋手動エリアに「天王洲アイル」追加 in `DokoWanCafe/DokoWanCafe/`
- [x] T117 テストのフィクスチャ分離（アプリバンドル=実データ化に伴い、テストは凍結サンプル7件を使用）in `DokoWanCafe/DokoWanCafeTests/Fixtures/cafes.json`
- [ ] T118 **座標の実測確認（ユーザー/運営作業）**: 5件の緯度経度は概算。Google Maps で各店をピン→座標コピペで `data/master/cafes.csv` を修正 → `python3 tools/export_cafes.py` で再出力
