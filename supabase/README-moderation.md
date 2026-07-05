# 運営モデレーション手順（v1: 運営承認のみ）— T042

v1 では専用の運営コンソールを作らず、**Supabase ダッシュボードを流用**して審査する（spec.md Assumptions「運用の最小化」）。
利用者からの修正提案は `corrections` テーブルに `pending`（審査中）で入り、**承認されるまで表示には一切反映されない**（FR-024, SC-008）。

## 日常の審査フロー

1. **審査待ちの確認** — ダッシュボード > SQL Editor で:

   ```sql
   select c.id, cf.name as cafe_name, c.proposed_status, c.proposed_condition,
          c.note, c.created_at
   from corrections c
   join cafes cf on cf.id = c.cafe_id
   where c.status = 'pending'
   order by c.created_at asc;
   ```

2. **内容を確認** — 対象カフェの現状・出典と突き合わせ、可能なら一次情報（公式HP/SNS・電話）で裏取りする（憲章 原則I）。

3. **承認する場合**:

   ```sql
   select apply_correction('<correction_id>', '公式SNSで確認済み');
   ```

   - カフェ本体に反映され、`last_verified` が今日に更新される
   - 由来 `user_submitted_verified`（運営自身の提案なら `operator_verified`）の出典が追加され、採用根拠（`representative_source_id`）になる（FR-025）
   - ⚠️ `proposed_status = 'conditional'` なのに条件テキストが無い場合、CHECK 制約で失敗する。その場合は提案者の意図を確認し、`proposed_condition` を補ってから承認する。

4. **却下する場合**（不正確・スパム・根拠不明）:

   ```sql
   select reject_correction('<correction_id>', '根拠が確認できないため');
   ```

   - 却下された提案は**決して表示に反映されない**（FR-027）

## 運営による直接編集（FR-026）

ダッシュボードの Table Editor で `cafes` / `sources` を直接編集できる（service_role は RLS をバイパス）。
編集時は必ず:
- `last_verified` を更新する
- `sources` に由来 `operator_verified` の出典行を追加する（確認日・参照つき）

## 運用目安（SC-009）

- **週1回以上**、審査待ちを確認する
- 妥当な提案は**提出から7日以内**の反映を目安とする（SC-009: 90%以上）
- 迷ったら反映しない＝「未確認」に倒す（憲章 原則I: 憶測で「可」にしない）

## 第2段階（AIスクリーニング導入後）

`supabase/functions/ai-screen/README.md` を参照。AI が一次判定（`ai_review` に記録、`status = 'ai_checked'`）した後も、
**最終承認は必ず運営が行う**。AI 単独で `applied` にしない（FR-024 の不変条件を維持）。
