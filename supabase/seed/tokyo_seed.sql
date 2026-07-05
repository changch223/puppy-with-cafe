-- tokyo_seed.sql — 開発・検証用サンプルデータ（T011）
--
-- ⚠️ 重要（憲章 原則I / FR-021）:
-- このファイルの店舗はすべて【架空】の開発用サンプルです。実在のカフェ情報ではありません。
-- 本番リリース前に、運営が実際に確認した東京の犬同伴カフェ（数十件）で置き換えること。
-- 実データ整備の際は必ず 出典(reference)・確認日(verified_at)・由来(provenance) を記録する。
--
-- 検証観点（quickstart.md 対応）: conditional 1件以上 / 出典矛盾 1件以上 / ai_inferred 1件以上 /
--                                 unverified 1件以上 / 古い確認日 1件以上 を含む。

begin;

-- ---- カフェ（架空・東京駅〜銀座周辺） -------------------------------------

insert into cafes (id, place_id, name, latitude, longitude, address, contact,
                   dog_policy_status, dog_policy_condition, last_verified, area) values
  ('c0000000-0000-4000-8000-000000000001', 'sample-place-1',
   'サンプル・ドッグテラス丸の内', 35.6820, 139.7650,
   '東京都千代田区丸の内1-0-0（架空）', 'https://example.com/marunouchi',
   'allowed', null, current_date - 20, 'tokyo'),

  ('c0000000-0000-4000-8000-000000000002', 'sample-place-2',
   'サンプルカフェ 八重洲テラス', 35.6800, 139.7710,
   '東京都中央区八重洲1-0-0（架空）', null,
   'conditional', 'テラス席のみ犬同伴可（架空の条件）', current_date - 45, 'tokyo'),

  ('c0000000-0000-4000-8000-000000000003', 'sample-place-3',
   'サンプル珈琲 日本橋', 35.6840, 139.7740,
   '東京都中央区日本橋1-0-0（架空）', null,
   'allowed', null, current_date - 10, 'tokyo'),

  ('c0000000-0000-4000-8000-000000000004', 'sample-place-4',
   'サンプル・レトロ喫茶 銀座', 35.6717, 139.7650,
   '東京都中央区銀座4-0-0（架空）', null,
   'allowed', null, current_date - 500, 'tokyo'),

  ('c0000000-0000-4000-8000-000000000005', 'sample-place-5',
   'サンプルベーカリー 京橋', 35.6770, 139.7700,
   '東京都中央区京橋2-0-0（架空）', null,
   'allowed', null, current_date - 30, 'tokyo'),

  ('c0000000-0000-4000-8000-000000000006', 'sample-place-6',
   'サンプル喫茶 神田', 35.6910, 139.7700,
   '東京都千代田区神田1-0-0（架空）', null,
   'unverified', null, null, 'tokyo'),

  ('c0000000-0000-4000-8000-000000000007', 'sample-place-7',
   'サンプルティールーム 有楽町', 35.6750, 139.7630,
   '東京都千代田区有楽町1-0-0（架空）', null,
   'not_allowed', null, current_date - 60, 'tokyo');

-- ---- 出典 -------------------------------------------------------------------

insert into sources (id, cafe_id, type, reference, claimed_status, verified_at, provenance) values
  -- 丸の内: 公式（運営確認）
  ('a0000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000001',
   'official_hp', 'https://example.com/marunouchi', 'allowed', current_date - 20, 'operator_verified'),

  -- 八重洲: 公式＋食べログ集約（一致・条件付き）
  ('a0000000-0000-4000-8000-000000000021', 'c0000000-0000-4000-8000-000000000002',
   'official_hp', 'https://example.com/yaesu', 'conditional', current_date - 45, 'operator_verified'),
  ('a0000000-0000-4000-8000-000000000022', 'c0000000-0000-4000-8000-000000000002',
   'tabelog', 'https://example.com/yaesu-tabelog', 'conditional', current_date - 90, 'aggregated'),

  -- 日本橋: 【矛盾サンプル】公式は可（新）、ブログは不可（古）→ has_conflict がトリガで真になる
  ('a0000000-0000-4000-8000-000000000031', 'c0000000-0000-4000-8000-000000000003',
   'official_hp', 'https://example.com/nihonbashi', 'allowed', current_date - 10, 'operator_verified'),
  ('a0000000-0000-4000-8000-000000000032', 'c0000000-0000-4000-8000-000000000003',
   'blog', 'https://example.com/nihonbashi-blog', 'not_allowed', current_date - 200, 'aggregated'),

  -- 銀座: 古い確認日（FR-010 の警告検証用）
  ('a0000000-0000-4000-8000-000000000041', 'c0000000-0000-4000-8000-000000000004',
   'sns', 'https://example.com/ginza-sns', 'allowed', current_date - 500, 'human_verified'),

  -- 京橋: 【AI推測サンプル】（FR-012 の区別表示検証用）
  ('a0000000-0000-4000-8000-000000000051', 'c0000000-0000-4000-8000-000000000005',
   'other', null, 'allowed', current_date - 30, 'ai_inferred'),

  -- 有楽町: 不可（人手確認）
  ('a0000000-0000-4000-8000-000000000071', 'c0000000-0000-4000-8000-000000000007',
   'google_map', 'https://example.com/yurakucho', 'not_allowed', current_date - 60, 'human_verified');

-- ---- 代表出典の紐付け（FR-013: 採用根拠をたどれる） --------------------------

update cafes set representative_source_id = 'a0000000-0000-4000-8000-000000000011'
  where id = 'c0000000-0000-4000-8000-000000000001';
update cafes set representative_source_id = 'a0000000-0000-4000-8000-000000000021'
  where id = 'c0000000-0000-4000-8000-000000000002';
update cafes set representative_source_id = 'a0000000-0000-4000-8000-000000000031'
  where id = 'c0000000-0000-4000-8000-000000000003';
update cafes set representative_source_id = 'a0000000-0000-4000-8000-000000000041'
  where id = 'c0000000-0000-4000-8000-000000000004';
update cafes set representative_source_id = 'a0000000-0000-4000-8000-000000000051'
  where id = 'c0000000-0000-4000-8000-000000000005';
update cafes set representative_source_id = 'a0000000-0000-4000-8000-000000000071'
  where id = 'c0000000-0000-4000-8000-000000000007';

commit;
