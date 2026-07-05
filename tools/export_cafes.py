#!/usr/bin/env python3
"""
export_cafes.py — Google Sheet(CSV) → 検証済み cafes.json 生成（T062, FR-032/033）

役割（憲章 原則I をここで担保する検証ゲート）:
  1. cafes.csv / sources.csv を読み込み、スキーマ・整合を検証（不正なら配信させない）
  2. FR-013 と同一規則で代表可否・矛盾・最終確認日を導出（アプリの ConflictResolver と同一）
  3. FR-030 と同一規則で重複（名寄せ）を検出（place_id 一致 / 正規化名称＋50m 近接 → エラーで運営に修正を促す）
  4. 既存 cafes.json との差分（追加/変更/削除）を検出し、data/CHANGELOG.md に追記（FR-033）
  5. data/cafes.json を生成し、アプリの Resources/ にもコピー（バンドル用）

使い方:
  python3 tools/export_cafes.py                     # 既定パスで実行
  python3 tools/export_cafes.py --sample            # サンプルデータとしてマーク（バナー表示）
  python3 tools/export_cafes.py --cafes path.csv --sources path.csv

Google Sheet 運用: シートの「ファイル > ダウンロード > CSV」で2タブをそれぞれ保存して実行する。
列仕様は tools/README.md を参照。
"""

import argparse
import csv
import json
import math
import sys
import unicodedata
import uuid
from datetime import datetime, timezone, date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

DEFAULT_CAFES_CSV = ROOT / "tools" / "sheet_template" / "cafes.csv"
DEFAULT_SOURCES_CSV = ROOT / "tools" / "sheet_template" / "sources.csv"
DEFAULT_OUT = ROOT / "data" / "cafes.json"
DEFAULT_CHANGELOG = ROOT / "data" / "CHANGELOG.md"
DEFAULT_APP_COPY = ROOT / "DokoWanCafe" / "DokoWanCafe" / "Resources" / "cafes.json"

# data-model.md の列挙型と一致させる
DOG_POLICY_STATUSES = {"allowed", "conditional", "not_allowed", "unverified"}
SOURCE_TYPES = {"official_hp", "sns", "google_map", "tabelog", "blog", "other"}
PROVENANCES = {
    "official": 5,
    "operator_verified": 5,
    "human_verified": 4,
    "user_submitted_verified": 3,
    "aggregated": 2,
    "ai_inferred": 1,
}

UUID_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_DNS, "puppywithcafe.dokowan")
PROXIMITY_METERS = 50.0  # FR-030 / research.md R6


def fail(errors):
    print("\n❌ 検証エラー（配信は中止されました。Sheet を修正して再実行してください）:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)


def haversine_m(lat1, lng1, lat2, lng2):
    r = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def normalized_name(name):
    # アプリの CafeDeduplicator.normalizedName と同一規則（NFKC・小文字化・空白除去）
    folded = unicodedata.normalize("NFKC", name).lower()
    return "".join(folded.split())


def parse_date(value, label, errors):
    if not value:
        return None
    try:
        return date.fromisoformat(value.strip())
    except ValueError:
        errors.append(f"{label}: 日付は YYYY-MM-DD 形式で入力してください（入力値: {value!r}）")
        return None


def parse_bool(value):
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def stable_uuid(*parts):
    return str(uuid.uuid5(UUID_NAMESPACE, "|".join(p or "" for p in parts)))


def load_cafes(path, errors):
    cafes = {}
    with open(path, newline="", encoding="utf-8-sig") as f:
        for i, row in enumerate(csv.DictReader(f), start=2):
            name = (row.get("name") or "").strip()
            if not name:
                errors.append(f"cafes.csv 行{i}: name は必須です")
                continue
            label = f"cafes.csv 行{i}（{name}）"
            try:
                lat = float(row.get("latitude") or "")
                lng = float(row.get("longitude") or "")
            except ValueError:
                errors.append(f"{label}: latitude/longitude は数値で入力してください")
                continue
            if not (-90 <= lat <= 90 and -180 <= lng <= 180):
                errors.append(f"{label}: 緯度経度が範囲外です ({lat}, {lng})")
                continue

            place_id = (row.get("place_id") or "").strip() or None
            cafe_id = (row.get("id") or "").strip()
            if cafe_id:
                try:
                    cafe_id = str(uuid.UUID(cafe_id))
                except ValueError:
                    errors.append(f"{label}: id が UUID 形式ではありません（空欄なら自動採番されます）")
                    continue
            else:
                # 空欄なら place_id（無ければ 名称+座標）から決定論的に採番（再実行しても同じIDになる）
                cafe_id = stable_uuid("cafe", place_id or f"{normalized_name(name)}@{lat:.5f},{lng:.5f}")

            if cafe_id in cafes:
                errors.append(f"{label}: id が重複しています（{cafe_id}）")
                continue

            area = (row.get("area") or "").strip() or "tokyo"
            cafes[cafe_id] = {
                "id": cafe_id,
                "place_id": place_id,
                "name": name,
                "latitude": lat,
                "longitude": lng,
                "address": (row.get("address") or "").strip() or None,
                "contact": (row.get("contact") or "").strip() or None,
                "is_closed": parse_bool(row.get("is_closed")),
                "area": area,
            }
    return cafes


def load_sources(path, cafes, errors):
    sources_by_cafe = {cid: [] for cid in cafes}
    with open(path, newline="", encoding="utf-8-sig") as f:
        for i, row in enumerate(csv.DictReader(f), start=2):
            label = f"sources.csv 行{i}"
            cafe_id = (row.get("cafe_id") or "").strip()
            if cafe_id not in cafes:
                errors.append(f"{label}: cafe_id {cafe_id!r} が cafes.csv に存在しません")
                continue
            stype = (row.get("type") or "").strip()
            if stype not in SOURCE_TYPES:
                errors.append(f"{label}: type {stype!r} が不正です（{sorted(SOURCE_TYPES)}）")
                continue
            claimed = (row.get("claimed_status") or "").strip()
            if claimed not in DOG_POLICY_STATUSES:
                errors.append(f"{label}: claimed_status {claimed!r} が不正です")
                continue
            provenance = (row.get("provenance") or "").strip()
            if provenance not in PROVENANCES:
                errors.append(f"{label}: provenance {provenance!r} が不正です（{sorted(PROVENANCES)}）")
                continue
            condition = (row.get("claimed_condition") or "").strip() or None
            if claimed == "conditional" and not condition:
                # FR-007: 条件付きは条件テキスト必須
                errors.append(f"{label}: claimed_status=conditional には claimed_condition が必須です")
                continue
            verified_at = parse_date(row.get("verified_at"), label, errors)
            reference = (row.get("reference") or "").strip() or None

            sources_by_cafe[cafe_id].append({
                "id": stable_uuid("source", cafe_id, stype, reference, claimed,
                                  verified_at.isoformat() if verified_at else "", provenance),
                "cafe_id": cafe_id,
                "type": stype,
                "reference": reference,
                "claimed_status": claimed,
                "_claimed_condition": condition,   # 導出専用（JSONには cafe 側の条件として出力）
                "verified_at": verified_at.isoformat() if verified_at else None,
                "provenance": provenance,
            })
    return sources_by_cafe


def resolve_policy(cafe, sources, errors):
    """FR-013 と同一規則（アプリ ConflictResolver と一致させること）"""
    meaningful = [s for s in sources if s["claimed_status"] != "unverified"]
    if not meaningful:
        return {"status": "unverified", "condition": None, "last_verified": None,
                "representative_id": None, "has_conflict": False}

    has_conflict = len({s["claimed_status"] for s in meaningful}) > 1

    def sort_key(s):
        d = s["verified_at"] or "0000-00-00"
        return (d, PROVENANCES[s["provenance"]])

    ordered = sorted(meaningful, key=sort_key, reverse=True)
    top = ordered[0]
    peers = [s for s in ordered if sort_key(s) == sort_key(top)]
    if len({s["claimed_status"] for s in peers}) > 1:
        # 同順位で可否が割れる → 未確認（憶測で「可」にしない）
        return {"status": "unverified", "condition": None, "last_verified": None,
                "representative_id": None, "has_conflict": True}

    status = top["claimed_status"]
    if not top["verified_at"]:
        # FR-009: 確認日の無い情報を確定情報として配信しない
        errors.append(f"{cafe['name']}: 代表出典（{top['type']}）に verified_at がありません。"
                      f"確認日を入れるか claimed_status を unverified にしてください")
        return None
    condition = top["_claimed_condition"] if status == "conditional" else None
    return {"status": status, "condition": condition, "last_verified": top["verified_at"],
            "representative_id": top["id"], "has_conflict": has_conflict}


def check_duplicates(cafes, errors):
    """FR-030: place_id 一致 / 正規化名称＋近接 は同一店舗の疑い → 運営に統合を促す"""
    items = list(cafes.values())
    seen_place = {}
    for c in items:
        if c["place_id"]:
            if c["place_id"] in seen_place:
                errors.append(f"重複疑い: place_id {c['place_id']!r} が「{seen_place[c['place_id']]}」と「{c['name']}」で重複しています")
            else:
                seen_place[c["place_id"]] = c["name"]
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            a, b = items[i], items[j]
            if a["place_id"] and b["place_id"]:
                continue  # place_id 同士は上で判定済み
            if normalized_name(a["name"]) == normalized_name(b["name"]):
                d = haversine_m(a["latitude"], a["longitude"], b["latitude"], b["longitude"])
                if d <= PROXIMITY_METERS:
                    errors.append(f"重複疑い: 「{a['name']}」と「{b['name']}」は同名かつ {d:.0f}m の近接です。1行に統合してください")


def compute_diff(old_cafes, new_cafes):
    old_by_id = {c["id"]: c for c in old_cafes}
    new_by_id = {c["id"]: c for c in new_cafes}
    added = [new_by_id[i]["name"] for i in new_by_id.keys() - old_by_id.keys()]
    removed = [old_by_id[i]["name"] for i in old_by_id.keys() - new_by_id.keys()]
    changed = []
    for cid in new_by_id.keys() & old_by_id.keys():
        o, n = old_by_id[cid], new_by_id[cid]
        fields = [k for k in n if k != "sources" and o.get(k) != n.get(k)]
        if o.get("sources") != n.get("sources"):
            fields.append("sources")
        if fields:
            changed.append((n["name"], fields))
    return added, removed, changed


def main():
    ap = argparse.ArgumentParser(description="Sheet CSV → 検証済み cafes.json")
    ap.add_argument("--cafes", type=Path, default=DEFAULT_CAFES_CSV)
    ap.add_argument("--sources", type=Path, default=DEFAULT_SOURCES_CSV)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--app-copy", type=Path, default=DEFAULT_APP_COPY)
    ap.add_argument("--changelog", type=Path, default=DEFAULT_CHANGELOG)
    ap.add_argument("--sample", action="store_true", help="架空サンプルデータとしてマーク（アプリにバナー表示）")
    args = ap.parse_args()

    errors = []
    cafes = load_cafes(args.cafes, errors)
    sources_by_cafe = load_sources(args.sources, cafes, errors)
    if errors:
        fail(errors)

    check_duplicates(cafes, errors)
    if errors:
        fail(errors)

    out_cafes = []
    for cid, cafe in cafes.items():
        srcs = sources_by_cafe.get(cid, [])
        policy = resolve_policy(cafe, srcs, errors)
        if policy is None:
            continue
        out_cafes.append({
            **cafe,
            "dog_policy_status": policy["status"],
            "dog_policy_condition": policy["condition"],
            "last_verified": policy["last_verified"],
            "representative_source_id": policy["representative_id"],
            "has_conflict": policy["has_conflict"],
            "sources": [{k: v for k, v in s.items() if not k.startswith("_")} for s in srcs],
        })
    if errors:
        fail(errors)

    out_cafes.sort(key=lambda c: c["name"])

    # 差分検出（FR-033）
    old_cafes = []
    if args.out.exists():
        try:
            old_cafes = json.loads(args.out.read_text(encoding="utf-8")).get("cafes", [])
        except (json.JSONDecodeError, OSError):
            print("⚠️ 既存 cafes.json を読めなかったため、差分は全件追加扱いになります", file=sys.stderr)
    added, removed, changed = compute_diff(old_cafes, out_cafes)

    payload = {
        "format_version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "is_sample_data": args.sample,
        "cafes": out_cafes,
    }
    text = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n"

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text, encoding="utf-8")
    args.app_copy.parent.mkdir(parents=True, exist_ok=True)
    args.app_copy.write_text(text, encoding="utf-8")

    # CHANGELOG 追記（差分がある場合のみ）
    if added or removed or changed:
        stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
        lines = [f"\n## {stamp} — 追加 {len(added)} / 変更 {len(changed)} / 削除 {len(removed)}"
                 + ("（サンプルデータ）" if args.sample else "")]
        lines += [f"- ➕ 追加: {n}" for n in sorted(added)]
        lines += [f"- ✏️ 変更: {n}（{', '.join(f)}）" for n, f in sorted(changed)]
        lines += [f"- ➖ 削除: {n}" for n in sorted(removed)]
        if not args.changelog.exists():
            args.changelog.parent.mkdir(parents=True, exist_ok=True)
            args.changelog.write_text(
                "# データ変更履歴（自動生成）\n\n"
                "`tools/export_cafes.py` 実行時の差分が追記される。git のコミット履歴とあわせて追跡・共有できる。\n",
                encoding="utf-8")
        with open(args.changelog, "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

    # サマリ表示
    print(f"✅ 検証OK: カフェ {len(out_cafes)}件 / 出典 {sum(len(c['sources']) for c in out_cafes)}件"
          + ("【サンプルデータ】" if args.sample else ""))
    print(f"   出力: {args.out.relative_to(ROOT)} ＋ {args.app_copy.relative_to(ROOT)}（アプリバンドル用）")
    if added or removed or changed:
        print(f"   差分: 追加 {len(added)} / 変更 {len(changed)} / 削除 {len(removed)} → {args.changelog.relative_to(ROOT)} に追記")
        for n in sorted(added):
            print(f"     ➕ {n}")
        for n, f_ in sorted(changed):
            print(f"     ✏️ {n}（{', '.join(f_)}）")
        for n in sorted(removed):
            print(f"     ➖ {n}")
    else:
        print("   差分: なし")


if __name__ == "__main__":
    main()
