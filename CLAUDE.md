# DokoWanCafe — プロジェクト指針（AIエージェント向け）

犬同伴OKカフェを現在地から地図で探す iOS アプリ。Spec-Driven Development（Spec Kit）で開発。

> 🤝 **引き継ぎ・別PCで再開する場合は [`HANDOFF.md`](HANDOFF.md) を最初に読むこと**（現状・環境構築・次の作業・注意点の全体像）。

**製品名（表示名）: 「Puppy With Cafe」**（2026-07-05 決定）。リポジトリ・Xcodeターゲット等のコードネームは DokoWanCafe のまま（表示名は `INFOPLIST_KEY_CFBundleDisplayName` で設定）。

**GitHub**: https://github.com/changch223/puppy-with-cafe （public）。**データ配信**: GitHub Pages `https://changch223.github.io/puppy-with-cafe/data/cafes.json`（`AppConfig.defaultCafesDataURL` に設定済み・E2E確認済み）。プライバシーポリシー: 同 `docs/privacy.html`。データ反映＝`export_cafes.py` 実行 → commit → **push**（pushで配信される）。

## データ調査（database構築）
- カフェ調査の引き継ぎブリーフ: **`research-agent/README.md`**（収集項目・絶対ルール・手順のすべて）＋ `research-agent/progress.md`（エリア別進捗）
- 専用エージェント定義: `.claude/agents/cafe-researcher.md` —「cafe-researcher で代官山エリアを調査して」のように依頼する
- 調査エージェントは**コミットしない**。差分（CHANGELOG・git diff）を運営がレビューして反映＝承認（FR-024 の運営承認と同じ構図）
- 姉妹リポジトリ **CafeResearchAgent**（`../CafeResearchAgent/`）が spec-kit で独立運用する調査基盤。手動調査バッチを `staging/<日付>-<エリア>/` に納品し、本リポジトリへは運営レビュー後に `export_cafes.py --check` 通過を確認して反映する。2026-07-18 に初期34エリア268件を反映し、その後 2026-08 の wave2〜4 等で **594件**（2026-10 時点）まで拡大（詳細: 同リポジトリ `HANDOFF.md` / `agent/progress.md`）。座標は多くが概算のため今後の実測課題

## データ反映の運用（2026-08〜10・cc-crew）
- 調査は CSV に直接書かず **JSON で納品 → 1体が集約して CSV 反映 → qa-reviewer が原文突き合わせ QA → PR → 運営がマージ（＝承認＝Pages 配信）**。営業時間の構造化は二重独立変換で一致分のみ採用。手順・ルールの詳細は `HANDOFF.md` §5 と `research-agent/gap-handover-2026-08.md`。

## 進め方
- ワークフロー: `/speckit-constitution` → `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`
- 憲章: `.specify/memory/constitution.md`（**最優先。特に 原則I 信頼できるデータ / 原則III プライバシー は必須ゲート**）
- フィーチャー: `specs/001-dog-cafe-map/`（中核: 発見・信頼・報告。contracts/ にデータ契約）、`specs/002-cafe-rich-info/`（詳細充実: 営業時間+営業中バッジ・電話/予約・公式リンク・犬向け設備4項目・運営転記メモ）

## 技術スタック（plan.md 準拠）
- **Swift 5.9+ / iOS 16+**、UIは **SwiftUI 優先**、地図クラスタリング等のみ **MKMapView を UIViewRepresentable で橋渡し**
- アーキテクチャ **MVVM**。純ロジック（距離/名寄せ/矛盾解決/フィルタ）は `Core/` に隔離し **XCTest 必須**
- MapKit / CoreLocation（**WhenInUse**）/ AuthenticationServices（**Appleでサインイン**）
- **バックエンド（2026-07-05 構成Bに改訂, research.md R11）**: サーバーレス。**マスターCSV `data/master/*.csv`（Google Sheet 移行まで）→ `tools/export_cafes.py`（検証・矛盾/代表導出・差分CHANGELOG）→ `cafes.json`** をアプリにバンドル＋静的URL（GitHub Pages 予定）から遠隔更新（`Services/StaticCafeRepository.swift`）。検索・距離計算は端末内完結（位置情報を送信しない）。実データ: **594件・東京都内**（出典約1355件。初期268件＝天王洲アイル5＋姉妹リポジトリ `../CafeResearchAgent/` の手動調査263件に、2026-08 の wave2〜4 で追加。大型犬可否 約257件・曜日別営業時間 約405件を構造化済み。座標は多くが概算・要実測。2026-10-07 時点）。テストは凍結フィクスチャ（`DokoWanCafeTests/Fixtures/`）を使用
- 誤り報告は **Google フォーム**（プリフィル。`AppConfig.defaultReportFormTemplate` に設定）。**サインインなし**（FR-028改訂）。運営がマスター反映＝承認
- 旧A案（Supabase: `supabase/` の SQL・`Services/Supabase*`/`AuthService` 等）は**保管**。規模拡大時の移行先。v1では配線しない
- 依存管理は **SwiftPM**。文字列は **String Catalog（日本語第一）**

## 重要な設計判断
- 犬同伴可否の**初期データは運営が手動整備（東京・数十件）**、外部集約は住所/座標の補助
- 可否は `allowed/conditional/not_allowed/unverified`。**憶測で allowed にしない**。出典・確認日・由来(provenance)を必須保持
- 矛盾解決: **確認日最新 → 由来の信頼順 → 決まらなければ未確認**（`Core/ConflictResolver`）
- 修正提案は **投稿時サインイン必須**、**v1は運営承認のみ**（Supabaseダッシュボード流用）。AI自動スクリーニングは第2段階（Edge Function）
- 外部データの取得手段（API/スクレイピング）は**未確定**。規約・著作権を要確認

## 制約
- 位置情報は保存しない（検索座標のみ送信）。`PrivacyInfo.xcprivacy` 同梱
- 機密（Supabase URL/key 等）はリポジトリに含めない
