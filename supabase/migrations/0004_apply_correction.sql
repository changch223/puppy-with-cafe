-- 0004_apply_correction.sql — 修正提案の承認・却下（T043, FR-025/026/027）
-- 実行者: 運営のみ（ダッシュボードの SQL Editor / service_role）。
-- anon / authenticated からの実行は revoke 済み。

-- 承認: 提案内容をカフェへ反映し、由来・確認日を記録する（FR-025）
create or replace function apply_correction(
  correction_id uuid,
  reviewer_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  corr corrections%rowtype;
  new_source_id uuid;
  prov text;
begin
  select * into corr from corrections where id = correction_id for update;
  if not found then
    raise exception '修正提案 % が見つかりません', correction_id;
  end if;
  if corr.status in ('applied', 'rejected') then
    raise exception '修正提案 % は既に処理済みです（%）', correction_id, corr.status;
  end if;

  -- 由来: 利用者提案(検証済み) or 運営確認（FR-025/026）
  prov := case when corr.submitter_type = 'operator'
               then 'operator_verified'
               else 'user_submitted_verified' end;

  -- 反映内容を出典として記録（憲章 原則I: 出典・確認日・由来を保持）
  insert into sources (cafe_id, type, reference, claimed_status, verified_at, provenance)
  values (
    corr.cafe_id,
    'other',
    null,
    coalesce(corr.proposed_status, (select dog_policy_status from cafes where id = corr.cafe_id)),
    current_date,
    prov
  )
  returning id into new_source_id;

  -- カフェ本体へ反映。
  -- 注意: proposed_status = 'conditional' で条件が無い場合は cafes の CHECK 制約で失敗する。
  --       その場合は proposed_condition を確認してから再実行すること（README-moderation.md 参照）。
  update cafes set
    dog_policy_status = coalesce(corr.proposed_status, dog_policy_status),
    dog_policy_condition = coalesce(corr.proposed_condition, dog_policy_condition),
    last_verified = current_date,
    representative_source_id = new_source_id,
    updated_at = now()
  where id = corr.cafe_id;

  update corrections
  set status = 'applied',
      applied_at = now(),
      operator_review = coalesce(reviewer_note, operator_review)
  where id = correction_id;
end;
$$;

-- 却下: 表示には一切反映しない（FR-027, SC-008）
create or replace function reject_correction(
  correction_id uuid,
  reviewer_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update corrections
  set status = 'rejected',
      operator_review = coalesce(reviewer_note, operator_review)
  where id = correction_id
    and status not in ('applied', 'rejected');
  if not found then
    raise exception '修正提案 % は存在しないか、既に処理済みです', correction_id;
  end if;
end;
$$;

-- 利用者からは実行不可（運営のみ）
revoke execute on function apply_correction(uuid, text) from public, anon, authenticated;
revoke execute on function reject_correction(uuid, text) from public, anon, authenticated;
