-- contract_tests.sql — バックエンド契約テスト（T059）
--
-- 対象（contracts/api-contracts.md「契約テスト観点」）:
--   1) nearby_cafes: 半径・only_dog_ok・距離昇順・登録データの表示漏れなし（SC-005）
--   2) RLS: 未認証(anon)の corrections insert が拒否される
--   3) RLS: 認証ユーザーは自身の pending 提案のみ作成できる（他人ID・pending以外は拒否）
--   4) 未承認提案が cafes に反映されない／apply_correction で反映される（SC-008, FR-024/025）
--
-- 実行方法: Supabase の SQL Editor に貼り付けて実行（マイグレーション 0001〜0004 適用後）。
-- 全体が rollback されるため、実データへの影響はない。
-- すべて成功すると最後に「ALL CONTRACT TESTS PASSED」の NOTICE が出る。失敗時は例外で停止する。

begin;

-- ---- テストフィクスチャ（テスト用の座標: 架空の基準点 35.7000, 139.5000 周辺） ----
insert into cafes (id, place_id, name, latitude, longitude, dog_policy_status, dog_policy_condition, last_verified, area) values
  ('ffff0000-0000-4000-8000-000000000001', 'test-p1', 'テスト近距離・可',     35.7000, 139.5000, 'allowed',     null,             current_date, 'tokyo'),
  ('ffff0000-0000-4000-8000-000000000002', 'test-p2', 'テスト中距離・条件付き', 35.7090, 139.5000, 'conditional', 'テラスのみ',      current_date, 'tokyo'),
  ('ffff0000-0000-4000-8000-000000000003', 'test-p3', 'テスト近距離・不可',   35.7010, 139.5000, 'not_allowed', null,             current_date, 'tokyo'),
  ('ffff0000-0000-4000-8000-000000000004', 'test-p4', 'テスト遠距離・可',     35.8000, 139.5000, 'allowed',     null,             current_date, 'tokyo'),
  ('ffff0000-0000-4000-8000-000000000005', 'test-p5', 'テスト閉店・可',       35.7005, 139.5000, 'allowed',     null,             current_date, 'tokyo');
update cafes set is_closed = true where id = 'ffff0000-0000-4000-8000-000000000005';

-- ---- 1) nearby_cafes の契約 --------------------------------------------------
do $$
declare
  cnt integer;
  ordered boolean;
begin
  -- 半径3km・犬OKのみ: 近距離可(1) + 中距離条件付き(2) の2件。
  -- 不可(3)は only_dog_ok で除外 / 遠距離(4)は半径外 / 閉店(5)は除外
  select count(*) into cnt
  from nearby_cafes(35.7000, 139.5000, 3000, true) n
  where (n.cafe).id::text like 'ffff0000%';
  if cnt <> 2 then
    raise exception 'nearby_cafes 件数が契約と不一致: expected 2, got %', cnt;
  end if;

  -- 表示漏れなし（SC-005）: only_dog_ok=false なら不可も含め3件
  select count(*) into cnt
  from nearby_cafes(35.7000, 139.5000, 3000, false) n
  where (n.cafe).id::text like 'ffff0000%';
  if cnt <> 3 then
    raise exception 'nearby_cafes(only_dog_ok=false) 件数が契約と不一致: expected 3, got %', cnt;
  end if;

  -- 距離昇順
  select bool_and(distance_m >= prev_distance) into ordered
  from (
    select n.distance_m,
           lag(n.distance_m, 1, 0) over (order by n.distance_m) as prev_distance
    from nearby_cafes(35.7000, 139.5000, 3000, false) n
    where (n.cafe).id::text like 'ffff0000%'
  ) t;
  if not coalesce(ordered, false) then
    raise exception 'nearby_cafes が距離昇順になっていない';
  end if;

  -- 閉店は返さない
  select count(*) into cnt
  from nearby_cafes(35.7000, 139.5000, 3000, false) n
  where (n.cafe).id = 'ffff0000-0000-4000-8000-000000000005';
  if cnt <> 0 then
    raise exception '閉店したカフェが nearby_cafes に含まれている';
  end if;

  raise notice 'TEST 1 PASSED: nearby_cafes の契約（半径・可否フィルタ・距離昇順・閉店除外・表示漏れなし）';
end $$;

-- ---- 2) RLS: 未認証(anon)は修正提案を作成できない ----------------------------
set local role anon;
do $$
begin
  begin
    insert into corrections (cafe_id, submitter_type, submitter_id, proposed_status, status)
    values ('ffff0000-0000-4000-8000-000000000001', 'user',
            '11111111-1111-1111-1111-111111111111', 'not_allowed', 'pending');
    raise exception 'RLS違反: anon の insert が成功してしまった';
  exception
    when insufficient_privilege then
      raise notice 'TEST 2 PASSED: anon の corrections insert は拒否される（FR-028）';
  end;
end $$;
reset role;

-- ---- 3) RLS: 認証ユーザーは自身の pending 提案のみ作成できる -------------------
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  -- 自身の pending 提案 → 成功
  insert into corrections (id, cafe_id, submitter_type, submitter_id, proposed_status, note, status)
  values ('ffff0000-0000-4000-8000-00000000c001',
          'ffff0000-0000-4000-8000-000000000001', 'user',
          '11111111-1111-1111-1111-111111111111', 'conditional', 'テラスのみ可でした', 'pending');
  raise notice 'TEST 3a PASSED: 認証ユーザーは自身の pending 提案を作成できる';

  -- pending 以外での作成 → 拒否（FR-024/027）
  begin
    insert into corrections (cafe_id, submitter_type, submitter_id, proposed_status, status)
    values ('ffff0000-0000-4000-8000-000000000001', 'user',
            '11111111-1111-1111-1111-111111111111', 'allowed', 'applied');
    raise exception 'RLS違反: status=applied の insert が成功してしまった';
  exception
    when insufficient_privilege then
      raise notice 'TEST 3b PASSED: pending 以外の状態での作成は拒否される（FR-024）';
  end;

  -- 他人の submitter_id → 拒否
  begin
    insert into corrections (cafe_id, submitter_type, submitter_id, proposed_status, status)
    values ('ffff0000-0000-4000-8000-000000000001', 'user',
            '22222222-2222-2222-2222-222222222222', 'allowed', 'pending');
    raise exception 'RLS違反: 他人のIDでの insert が成功してしまった';
  exception
    when insufficient_privilege then
      raise notice 'TEST 3c PASSED: 他人の submitter_id での作成は拒否される';
  end;

  -- 利用者による審査状態の変更（update）→ ポリシーなしのため 0行（変更不可, FR-027）
  update corrections set status = 'applied'
  where id = 'ffff0000-0000-4000-8000-00000000c001';
  if found then
    raise exception 'RLS違反: 利用者が審査状態を変更できてしまった';
  end if;
  raise notice 'TEST 3d PASSED: 利用者は審査状態を変更できない（FR-027）';
end $$;
reset role;

-- ---- 4) 未承認は非反映・承認で反映（SC-008, FR-024/025） -----------------------
do $$
declare
  status_before text;
  status_after text;
  corr_status text;
  prov text;
begin
  -- pending のままでは cafes に反映されない
  select dog_policy_status into status_before
  from cafes where id = 'ffff0000-0000-4000-8000-000000000001';
  if status_before <> 'allowed' then
    raise exception '未承認の提案が表示情報へ反映されている（SC-008違反）: %', status_before;
  end if;
  raise notice 'TEST 4a PASSED: pending の提案は表示情報へ反映されない（SC-008）';

  -- 運営が承認 → 反映され、由来と確認日が記録される
  perform apply_correction('ffff0000-0000-4000-8000-00000000c001', 'テストとして承認');

  select dog_policy_status into status_after
  from cafes where id = 'ffff0000-0000-4000-8000-000000000001';
  if status_after <> 'conditional' then
    raise exception 'apply_correction 後に反映されていない: %', status_after;
  end if;

  select status into corr_status
  from corrections where id = 'ffff0000-0000-4000-8000-00000000c001';
  if corr_status <> 'applied' then
    raise exception 'correction の状態が applied になっていない: %', corr_status;
  end if;

  select provenance into prov
  from sources
  where id = (select representative_source_id from cafes
              where id = 'ffff0000-0000-4000-8000-000000000001');
  if prov <> 'user_submitted_verified' then
    raise exception '由来が「利用者提案(検証済み)」として記録されていない: %', prov;
  end if;

  raise notice 'TEST 4b PASSED: 承認で反映され、由来・確認日・採用根拠が記録される（FR-025）';
  raise notice '=== ALL CONTRACT TESTS PASSED ===';
end $$;

rollback;
