# Contract: Backend DB Schema (Supabase / PostgreSQL + PostGIS)

クライアントが依存するサーバ側スキーマの契約。実装は `supabase/migrations/` の SQL として版管理する。ここでは形（テーブル・制約・RLS）を規定する。

## 拡張
- `create extension if not exists postgis;`

## テーブル

### cafes
```sql
create table cafes (
  id uuid primary key default gen_random_uuid(),
  place_id text,
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  geo geography(Point, 4326) not null,
  address text,
  contact text,
  dog_policy_status text not null
    check (dog_policy_status in ('allowed','conditional','not_allowed','unverified')),
  dog_policy_condition text,
  last_verified date,
  representative_source_id uuid,
  has_conflict boolean not null default false,
  is_closed boolean not null default false,
  area text not null default 'tokyo',
  updated_at timestamptz not null default now(),
  -- 条件付きは条件必須（FR-007）
  check (dog_policy_status <> 'conditional' or dog_policy_condition is not null),
  -- 出典・確認日が無ければ未確認（FR-009）
  check (dog_policy_status = 'unverified' or last_verified is not null)
);
create unique index cafes_place_id_uniq on cafes(place_id) where place_id is not null;
create index cafes_geo_gist on cafes using gist (geo);
create index cafes_area_idx on cafes(area);
```

### sources
```sql
create table sources (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references cafes(id) on delete cascade,
  type text not null
    check (type in ('official_hp','sns','google_map','tabelog','blog','other')),
  reference text,
  claimed_status text not null
    check (claimed_status in ('allowed','conditional','not_allowed','unverified')),
  verified_at date,
  provenance text not null
    check (provenance in ('official','operator_verified','human_verified',
                          'user_submitted_verified','aggregated','ai_inferred'))
);
create index sources_cafe_idx on sources(cafe_id);
```

### corrections
```sql
create table corrections (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references cafes(id) on delete cascade,
  submitter_type text not null check (submitter_type in ('user','operator')),
  submitter_id uuid,                     -- 利用者提案は auth.uid()（FR-028）
  proposed_status text
    check (proposed_status in ('allowed','conditional','not_allowed','unverified')),
  proposed_condition text,
  note text,
  status text not null default 'pending'
    check (status in ('pending','ai_checked','operator_checked','applied','rejected')),
  ai_review jsonb,
  operator_review text,
  applied_at timestamptz,
  created_at timestamptz not null default now()
);
create index corrections_cafe_status_idx on corrections(cafe_id, status);
```

## ビュー（矛盾提示 / FR-011）
```sql
-- 同一カフェで claimed_status が2種以上 → 矛盾
create view cafe_conflicts as
select cafe_id, count(distinct claimed_status) as distinct_status_count
from sources group by cafe_id having count(distinct claimed_status) > 1;
```

## 周辺検索 RPC（FR-001/002, R2）
```sql
-- 現在地(lat,lng)から半径 radius_m 内のカフェを距離つきで返す
create or replace function nearby_cafes(lat double precision, lng double precision,
                                        radius_m integer, only_dog_ok boolean default true)
returns table(cafe cafes, distance_m double precision)
language sql stable as $$
  select c, st_distance(c.geo, st_point(lng, lat)::geography) as distance_m
  from cafes c
  where c.area = 'tokyo' and c.is_closed = false
    and st_dwithin(c.geo, st_point(lng, lat)::geography, radius_m)
    and (only_dog_ok = false or c.dog_policy_status in ('allowed','conditional'))
  order by distance_m asc;
$$;
```
> 注: 現在地は引数として渡すのみで**保存しない**（憲章III）。

## Row-Level Security（RLS）ポリシー
- **cafes / sources**: `select` は全員可（匿名閲覧, FR-028）。`insert/update/delete` は**運営ロールのみ**。
- **corrections**:
  - `insert`: **認証済みユーザーのみ**（`auth.uid() = submitter_id`）＝投稿時サインイン必須（FR-028）。
  - `select`: 自分の提案のみ（運営ロールは全件）。
  - `update`（承認/却下・状態遷移）: **運営ロールのみ**（FR-024/026/027）。
- クライアントSDKからは `applied` への直接遷移を不可能にし、反映は運営操作/サーバ側でのみ行う。

## 反映処理（承認時）
- 運営が `corrections.status` を `applied` にすると、対象 `cafes`/`sources` を更新し、由来を `user_submitted_verified`（利用者提案）または `operator_verified`（運営編集）で記録、`last_verified` を更新（FR-025/026）。トリガ or 運営操作手順として実装（v1は手順でも可）。
