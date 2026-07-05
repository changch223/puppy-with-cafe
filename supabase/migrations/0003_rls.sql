-- 0003_rls.sql — Row-Level Security（contracts/db-schema.md 準拠）
-- 方針（FR-024/026/027/028）:
--   閲覧は誰でも / 修正提案の作成は認証ユーザーのみ（pending 固定）/
--   承認・編集は運営（service_role / ダッシュボード）のみ

alter table cafes enable row level security;
alter table sources enable row level security;
alter table corrections enable row level security;

-- 閲覧は匿名でも可能（FR-028: 閲覧・検索はサインイン不要）
create policy cafes_public_read on cafes
  for select using (true);

create policy sources_public_read on sources
  for select using (true);

-- cafes / sources に insert/update/delete のポリシーは定義しない
-- → anon / authenticated からの書き込みは不可。
--   運営は service_role（RLS バイパス）またはダッシュボードから編集する（FR-026）。

-- 修正提案: 認証ユーザーのみ、自身の提案を pending 状態でのみ作成できる（FR-024/028）
create policy corrections_insert_own on corrections
  for insert to authenticated
  with check (
    submitter_type = 'user'
    and submitter_id = auth.uid()
    and status = 'pending'
  );

-- 自身の提案のみ閲覧できる（運営は service_role で全件閲覧）
create policy corrections_select_own on corrections
  for select to authenticated
  using (submitter_id = auth.uid());

-- corrections に update/delete のポリシーは定義しない
-- → 利用者は審査状態を変更できない（FR-027: 状態遷移は運営のみ）
