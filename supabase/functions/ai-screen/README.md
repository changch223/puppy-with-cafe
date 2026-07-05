# AI 自動スクリーニング（第2段階）設計メモ — T058

v1 は運営承認のみ（README-moderation.md）。本メモは第2段階で追加する
**AI 一次判定 Edge Function** の設計を記す。実装は v1 リリース後。

## 目的

修正提案の審査を「AI 一次判定 → 運営最終承認」のダブルチェックに拡張し（FR-024 の到達目標）、
運営の審査負荷を下げつつ、スパム・明らかな誤りを早期に弾く。

## 不変条件（変更不可）

- **AI は絶対に `applied` にしない。** 反映の最終判断は常に運営（FR-024, SC-008: 未承認反映 0%）。
- AI の判定結果・根拠は `corrections.ai_review` (jsonb) に全て記録し、監査可能にする。

## 構成

- **Supabase Edge Function** `ai-screen`（Deno / TypeScript）
- **起動**: Database Webhook（`corrections` への insert 時）または cron（5分間隔で `pending` を取得）
- **モデル**: Claude API（例: `claude-sonnet-5`）。API キーは Function の環境変数 `ANTHROPIC_API_KEY` に設定（コードに埋め込まない）

## 処理フロー

1. `status = 'pending'` の提案を取得
2. コンテキストを組み立てる: 対象カフェの現在の可否・条件・出典一覧（由来・確認日つき）＋提案内容＋補足ノート
3. Claude に判定を依頼（構造化出力）:
   - `verdict`: `plausible`（妥当そう） / `suspicious`（要注意） / `spam`
   - `reasons`: 判定根拠（矛盾・情報の新旧・ノートの具体性 等）
   - `checks`: 運営が確認すべきポイントの提案（例: 「公式Instagramの最新投稿を確認」）
4. 結果を書き込む:
   ```sql
   update corrections
   set ai_review = $json, status = 'ai_checked'
   where id = $id and status = 'pending';
   ```
   （`spam` 判定でも自動 reject はせず、`ai_review` に記録して運営判断に委ねる。運用が安定したら
   明白なスパムのみ自動 reject する運用へ段階的に移行を検討）
5. 運営はダッシュボードで `ai_checked` の提案と `ai_review` を見て、`apply_correction` / `reject_correction` を実行

## セキュリティ

- Function は service_role キーで DB にアクセス（RLS バイパス。書き込みは `ai_review`/`status` のみに限定する）
- プロンプトに個人情報を含めない（`submitter_id` は渡さない）
