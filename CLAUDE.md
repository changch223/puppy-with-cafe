# DokoWanCafe — プロジェクト指針（AIエージェント向け）

犬同伴OKカフェを現在地から地図で探す iOS アプリ。Spec-Driven Development（Spec Kit）で開発。

**製品名（表示名）: 「Puppy With Cafe」**（2026-07-05 決定）。リポジトリ・Xcodeターゲット等のコードネームは DokoWanCafe のまま（表示名は `INFOPLIST_KEY_CFBundleDisplayName` で設定）。

## 進め方
- ワークフロー: `/speckit-constitution` → `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`
- 憲章: `.specify/memory/constitution.md`（**最優先。特に 原則I 信頼できるデータ / 原則III プライバシー は必須ゲート**）
- フィーチャー: `specs/001-dog-cafe-map/`（中核: 発見・信頼・報告。contracts/ にデータ契約）、`specs/002-cafe-rich-info/`（詳細充実: 営業時間+営業中バッジ・電話/予約・公式リンク・犬向け設備4項目・運営転記メモ）

## 技術スタック（plan.md 準拠）
- **Swift 5.9+ / iOS 16+**、UIは **SwiftUI 優先**、地図クラスタリング等のみ **MKMapView を UIViewRepresentable で橋渡し**
- アーキテクチャ **MVVM**。純ロジック（距離/名寄せ/矛盾解決/フィルタ）は `Core/` に隔離し **XCTest 必須**
- MapKit / CoreLocation（**WhenInUse**）/ AuthenticationServices（**Appleでサインイン**）
- **バックエンド（2026-07-05 構成Bに改訂, research.md R11）**: サーバーレス。**Google Sheet（マスター）→ `tools/export_cafes.py`（検証・矛盾/代表導出・差分CHANGELOG）→ `cafes.json`** をアプリにバンドル＋静的URL（GitHub Pages 予定）から遠隔更新（`Services/StaticCafeRepository.swift`）。検索・距離計算は端末内完結（位置情報を送信しない）
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
