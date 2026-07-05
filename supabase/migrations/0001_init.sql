-- 0001_init.sql — 基盤スキーマ（contracts/db-schema.md 準拠）
-- 適用方法: Supabase ダッシュボードの SQL Editor で実行、または supabase CLI の migration として適用

create extension if not exists postgis;

-- カフェ（憲章 原則I: 可否・確認日・出典を必須の構造で担保）
create table cafes (
  id uuid primary key default gen_random_uuid(),
  place_id text,
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  -- lat/lng を単一の真実として geography を生成（周辺検索・近接名寄せ用）
  geo geography(Point, 4326) generated always as (
    st_setsrid(st_makepoint(longitude, latitude), 4326)::geography
  ) stored,
  address text,
  contact text,
  dog_policy_status text not null
    check (dog_policy_status in ('allowed', 'conditional', 'not_allowed', 'unverified')),
  dog_policy_condition text,
  last_verified date,
  representative_source_id uuid,
  has_conflict boolean not null default false,
  is_closed boolean not null default false,
  area text not null default 'tokyo',
  updated_at timestamptz not null default now(),
  -- 条件付きは条件テキスト必須（FR-007）
  constraint conditional_requires_condition
    check (dog_policy_status <> 'conditional' or dog_policy_condition is not null),
  -- 確認日の無い情報は「未確認」でなければならない（FR-009）
  constraint verified_requires_date
    check (dog_policy_status = 'unverified' or last_verified is not null)
);

create unique index cafes_place_id_uniq on cafes (place_id) where place_id is not null;
create index cafes_geo_gist on cafes using gist (geo);
create index cafes_area_idx on cafes (area);

-- 出典（憲章 原則I: 由来 provenance で AI推測を明示区別）
create table sources (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references cafes (id) on delete cascade,
  type text not null
    check (type in ('official_hp', 'sns', 'google_map', 'tabelog', 'blog', 'other')),
  reference text,
  claimed_status text not null
    check (claimed_status in ('allowed', 'conditional', 'not_allowed', 'unverified')),
  verified_at date,
  provenance text not null
    check (provenance in ('official', 'operator_verified', 'human_verified',
                          'user_submitted_verified', 'aggregated', 'ai_inferred'))
);

create index sources_cafe_idx on sources (cafe_id);

-- 修正提案（FR-023〜027: v1 は運営承認、applied 以外は表示に反映されない）
create table corrections (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references cafes (id) on delete cascade,
  submitter_type text not null check (submitter_type in ('user', 'operator')),
  submitter_id uuid,
  proposed_status text
    check (proposed_status in ('allowed', 'conditional', 'not_allowed', 'unverified')),
  proposed_condition text,
  note text,
  status text not null default 'pending'
    check (status in ('pending', 'ai_checked', 'operator_checked', 'applied', 'rejected')),
  ai_review jsonb,
  operator_review text,
  applied_at timestamptz,
  created_at timestamptz not null default now()
);

create index corrections_cafe_status_idx on corrections (cafe_id, status);
