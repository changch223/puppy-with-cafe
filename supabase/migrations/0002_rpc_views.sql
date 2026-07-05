-- 0002_rpc_views.sql — 矛盾ビュー・周辺検索RPC・矛盾フラグ同期（contracts/db-schema.md 準拠）

-- 同一カフェで claimed_status が2種以上 → 矛盾（FR-011）
create view cafe_conflicts as
select cafe_id, count(distinct claimed_status) as distinct_status_count
from sources
where claimed_status <> 'unverified'
group by cafe_id
having count(distinct claimed_status) > 1;

-- sources の変更時に cafes.has_conflict を自動同期
create or replace function recompute_cafe_conflict()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  target := coalesce(new.cafe_id, old.cafe_id);
  update cafes
  set has_conflict = exists (select 1 from cafe_conflicts where cafe_id = target)
  where id = target;
  return null;
end;
$$;

create trigger sources_conflict_sync
after insert or update or delete on sources
for each row execute function recompute_cafe_conflict();

-- 周辺検索 RPC（FR-001/002, contracts/api-contracts.md #1）
-- 注意（憲章 原則III）: 引数の現在地は検索にのみ使用し、保存・記録しない。
-- 注意（FR-022）: v1 は東京のみのため area を固定。エリア拡大時はパラメータ化する（analysis I5）。
create or replace function nearby_cafes(
  lat double precision,
  lng double precision,
  radius_m integer,
  only_dog_ok boolean default true
)
returns table(cafe cafes, distance_m double precision)
language sql
stable
as $$
  select c, st_distance(c.geo, st_setsrid(st_makepoint(lng, lat), 4326)::geography) as distance_m
  from cafes c
  where c.area = 'tokyo'
    and c.is_closed = false
    and st_dwithin(c.geo, st_setsrid(st_makepoint(lng, lat), 4326)::geography, radius_m)
    and (only_dog_ok = false or c.dog_policy_status in ('allowed', 'conditional'))
  order by distance_m asc;
$$;
