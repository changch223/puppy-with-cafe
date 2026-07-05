# Quickstart / Validation Guide: DokoWanCafe

フィーチャーがエンドツーエンドで動くことを検証するための手順。実装コードは含めない（詳細は tasks.md と実装フェーズ）。

## 前提
- macOS + Xcode（iOS 16+ シミュレータ/実機）
- Apple Developer Program（実機・本番Appleサインイン・配布に必要）
- Supabase プロジェクト（無料枠可）
- Swift Package: `supabase-swift`

## セットアップ
1. **バックエンド**: Supabase プロジェクトを作成し、`supabase/migrations/` の SQL（`contracts/db-schema.md` 準拠：PostGIS 有効化、cafes/sources/corrections、`nearby_cafes` RPC、RLS）を適用。
2. **認証**: Supabase Auth で Apple プロバイダを有効化（Service ID / キー設定）。
3. **種データ**: `supabase/seed/` に東京の犬同伴カフェ数十件を手動整備（name/lat/lng/dog_policy_status/last_verified/source/provenance）。少なくとも 1件は `conditional`、1件は複数出典で `claimed_status` を割って**矛盾**を作る、1件は `provenance=ai_inferred` を含める。
4. **アプリ**: Xcode プロジェクトに Supabase の URL / anon key を設定（機密は Xcode 構成/環境で管理、リポジトリに含めない）。位置情報用途文言と `PrivacyInfo.xcprivacy` を設定。

## 実行
- Xcode でシミュレータ起動 → 位置情報を東京（例：東京駅）に設定 → アプリ実行。

## 検証シナリオ（ユーザーストーリー対応）

### US1（P1・MVP）現在地から発見
- 位置許可後、**5秒以内**に地図中心＝現在地、周辺の犬OKカフェがピン＋一覧（距離つき）で表示される（SC-001/002）。
- 一覧を距離順に確認、可否フィルタ「可のみ」で不可/未確認が消える。
- 地図と一覧の件数・対象が一致（乖離しない）。

### US2（P2）信頼情報
- 詳細で可否ステータス、（条件付きなら）条件、**出典と最終確認日**が表示。
- 出典の無いデータは「未確認」として区別される。古い確認日には警告（FR-010）。

### US3（P2）誤り報告＋ダブルチェック
- 未サインインで報告を試みる → サインインへ誘導（Appleでサインイン）。
- サインイン後に修正提案を送信 → **表示は即時に変わらない**（`pending`）。
- Supabase ダッシュボードで `applied` に承認 → 反映され由来が「利用者提案(検証済み)」。`rejected` は反映されない（SC-008）。

### US4（P3）矛盾・AI区別
- 矛盾を仕込んだカフェで**矛盾の提示**と各出典の可否/確認日が見える（SC-007）。
- `ai_inferred` の情報が確定情報と**視覚的に区別**される（SC-004）。

### US5（P3）詳細＋経路
- 詳細から外部地図アプリが当該カフェを目的地に開く。住所/出典リンクが見える。

### 横断（オフライン/プライバシー/a11y）
- 機内モードで再起動 → **直近キャッシュ**が鮮度・「最新でない可能性」つきで閲覧できる（FR-029）。
- 位置許可を拒否 → 地名手動指定で周辺検索できる（FR-017）。
- VoiceOver/Dynamic Type を有効化 → 主要フローが操作・可読（FR-031）。

## 合格条件（Success Criteria 対応）
- SC-001/002/003/004/005/007/008 が上記シナリオで確認できること。
- コアロジック（距離・フィルタ・名寄せ・矛盾解決）のユニットテストが緑（憲章IV）。
