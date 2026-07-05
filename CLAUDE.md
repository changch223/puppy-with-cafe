# DokoWanCafe — プロジェクト指針（AIエージェント向け）

犬同伴OKカフェを現在地から地図で探す iOS アプリ。Spec-Driven Development（Spec Kit）で開発。

**製品名（表示名）: 「Puppy With Cafe」**（2026-07-05 決定）。リポジトリ・Xcodeターゲット等のコードネームは DokoWanCafe のまま（表示名は `INFOPLIST_KEY_CFBundleDisplayName` で設定）。

## 進め方
- ワークフロー: `/speckit-constitution` → `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`
- 憲章: `.specify/memory/constitution.md`（**最優先。特に 原則I 信頼できるデータ / 原則III プライバシー は必須ゲート**）
- 現在のフィーチャー: `specs/001-dog-cafe-map/`（spec / plan / research / data-model / contracts / quickstart）

## 技術スタック（plan.md 準拠）
- **Swift 5.9+ / iOS 16+**、UIは **SwiftUI 優先**、地図クラスタリング等のみ **MKMapView を UIViewRepresentable で橋渡し**
- アーキテクチャ **MVVM**。純ロジック（距離/名寄せ/矛盾解決/フィルタ）は `Core/` に隔離し **XCTest 必須**
- MapKit / CoreLocation（**WhenInUse**）/ AuthenticationServices（**Appleでサインイン**）
- バックエンド **Supabase**（PostgreSQL + PostGIS / Auth / RLS）。自前サーバなし。オフラインは**直近取得の軽量ローカルキャッシュ**
- Supabase 接続は **URLSession ベースの内製ゲートウェイ**（`Services/SupabaseGateway.swift`）。supabase-swift SDK は不使用（依存ゼロ）。接続情報はスキームの環境変数 `SUPABASE_URL`/`SUPABASE_ANON_KEY` で注入し、未設定時は**サンプルデータモード**（バナー明示）で起動
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
