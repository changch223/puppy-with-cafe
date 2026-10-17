#!/usr/bin/env python3
"""
geocheck_coords.py — 掲載店の座標をデジタル庁 abr-geocoder の住所ジオコード結果と突き合わせる

役割:
  data/master/cafes.csv の latitude/longitude と、address を abr-geocoder（アドレス・ベース・レジストリ）で
  ジオコードした座標との距離を測り、各店を keep / fix / manual / investigate 等に判定する。
  fix 候補は国土地理院の住所検索（msearch.gsi.go.jp）でも同じ点を確認し、一致したものだけを fix とする
  （同系統の位置参照データのため独立検証ではなく、abrg の誤りを防ぐ確認程度の意味）。
  report / gsi はマスターCSVを一切書き換えない。座標の書き戻しは apply サブコマンド（--write 指定時のみ）。

出典表記（ライセンス）:
  位置情報の一部は、デジタル庁「アドレス・ベース・レジストリ」（公共データ利用規約（第1.0版）PDL1.0。
  https://www.digital.go.jp/policies/base_registry_address_tos 参照）を Puppy With Cafe 運営が加工して作成。
  abr-geocoder 本体は MIT。地番（parcel）由来の座標は fix に使わない（登記所備付地図データの規約を避けるため）。

使い方（3 段階。fix 候補は GSI 照合を通ったものだけが fix になる）:
  1) python3 tools/geocheck_coords.py report --abrg-bin <abrg> --abrg-dir <dir> --out geocheck_pre.csv
       → GSI 未照合の fix 候補は decision=gsi_pending になる
  2) python3 tools/geocheck_coords.py gsi --report geocheck_pre.csv --out gsi.json      # 1 秒 1 件
  3) python3 tools/geocheck_coords.py report --geo-json geo_raw.json --gsi-json gsi.json --out geocheck.csv
  4) python3 tools/geocheck_coords.py apply --report geocheck.csv            # dry-run（既定）
     python3 tools/geocheck_coords.py apply --report geocheck.csv --write    # cafes.csv の座標更新 + coord_sources.csv 出力

abrg の実行には Node.js 20+（推奨 22 LTS。24 は uWebSockets.js 非対応で不可）が必要。PATH に node が通っていること。
abrg の出力フィールド（実機確認済み, v2.3.1）:
  query.input / result.output / result.match_level / result.coordinate_level / result.lat / result.lon /
  result.lg_code / result.pref / result.county / result.city / result.ward / result.others / result.score
精度クラス（match_level が A/B 相当、かつ coordinate_level で分類。座標精度が粗ければ C に落とす）:
  A = residential_detail（住居表示の号まで）/ parcel（地番）
  B = residential_block（街区=番まで）
  C = machiaza_detail / machiaza / city 以下 / 解析不能
  注: parcel でも地番位置参照データが無い地域は coordinate_level=machiaza_detail（町字代表点）になるため C

判定（上から順）:
  closed→skip / 明示 manual 指定→manual / 住所空 or C→keep_coarse / 区市町村不一致 or d>investigate_over→investigate /
  abrg の others に番号が残る（部分一致）→manual / 施設F かつ d≤300→keep・>300→manual /
  A かつ d≤50→keep / B かつ d≤100→keep / それ以外（A・B で超過）は fix 候補。fix 候補は次の関門を順に通る:
    既存ピン精密（旧座標の lat か lng が小数5桁以上）: d≤300→keep・>300→manual
    地番座標（coordinate_level=parcel）→manual
    GSI 確認: abrg と GSI の距離が 150m 以下のときだけ fix。超過・GSI 結果なしは manual
"""

import argparse
import csv
import io
import json
import re
import statistics
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

# tools/export_cafes.py の既存関数を再利用する（同じ ROOT 規約）
from export_cafes import ROOT, haversine_m, parse_bool

DEFAULT_CAFES_CSV = ROOT / "data" / "master" / "cafes.csv"
DEFAULT_COORD_SOURCES_CSV = ROOT / "data" / "master" / "coord_sources.csv"
DEFAULT_REF = "abr-geocoder 2.3.1 / ABR データ 2026-10-16"
GSI_URL = "https://msearch.gsi.go.jp/address-search/AddressSearch?q="

OUT_COLUMNS = [
    "id", "name", "address", "is_closed", "lat", "lng", "geo_lat", "geo_lng",
    "level_class", "facility_flag", "distance_m", "decision", "reason",
    # 以下は gsi / apply（coord_sources.csv 出力）用の補助列
    "geo_address", "geo_level", "gsi_distance_m",
]

COORD_SOURCE_COLUMNS = [
    "cafe_id", "name", "latitude", "longitude", "method", "level", "geocoded_address",
    "distance_m", "gsi_distance_m", "decision", "ref", "verified_at", "note",
]

#: match_level → 精度クラス（abrg v2.3.1 の MatchLevel 文字列）
LEVEL_CLASS = {
    "residential_detail": "A",
    "parcel": "A",
    "residential_block": "B",
}

#: 施設フラグ F を立てる語（name / address / description を検索。--facility-words で追加可能）
FACILITY_WORDS = [
    "公園", "庭園", "緑地", "河川敷", "駅構内", "エキナカ", "モール", "ショッピングセンター",
    "アウトレット", "動物園", "霊園", "スタジアム", "広場", "キャンプ場", "テラス棟",
    "デックス", "東急スクエア", "シーズンテラス", "グランベリー", "臨海公園", "アクアシティ",
    "ダイバーシティ", "駅ビル", "ソラマチ", "スカイツリー", "タワー", "ヒルズ", "ららぽーと", "S.C.", "S・C",
    "ショッピングパーク",
]
#: 汎用語の「テラス」は施設語に含めない（description の「テラス席」でほぼ全店に当たるため。施設としては「テラス棟」「シーズンテラス」で判定）
#: description では判定しない語（name / address のみ）。例: 「東京タワーを望む」の誤爆を避ける
NAME_ADDRESS_ONLY_WORDS = {"タワー"}
#: 英字に挟まれない単独の "SC" だけを施設語として扱う
_SC_RE = re.compile(r"(?<![A-Za-z])SC(?![A-Za-z])")
#: 「〜通り」（例: 公園通り）は施設語の判定から外す
_DORI_RE = re.compile(r"[ぁ-んァ-ヶー一-龥A-Za-z0-9]{0,4}通り")

#: QA で「座標は main のまま」と明示された店 14 件（id 末尾）。--force-manual で上書き可
FORCE_MANUAL_DEFAULT = ["0140", "0141", "0142", "0143", "0363", "1110", "1111", "0226", "0625", "0084", "0087",
                        "0482", "0700", "0085"]


# --- 住所の整形 ------------------------------------------------------------------------

_POSTAL_RE = re.compile(r"〒?\s*\d{3}-?\d{4}\s*")
# 町名の後ろの「番地部分」: 数字(-数字…) / 丁目・番・番地・号・の を含む連なり。以降(ビル名・階)は切り捨てる
_NUM_RE = re.compile(
    r"^(?P<head>\D+?)(?P<num>\d+(?:\s*(?:丁目|番地|番|号|の|[-‐−–—ー])\s*\d+)*\s*(?:丁目|番地|番|号)?)"
)
_DIGITS_RE = re.compile(r"\d+")


def _normalize_address(address):
    a = unicodedata.normalize("NFKC", address or "").strip()
    a = _POSTAL_RE.sub("", a, count=1) if a.startswith("〒") else a
    return a.strip()


def clean_address(address):
    """郵便番号とビル名・階数・部屋番号を除いた「ジオコード用の住所」を返す（NFKC 正規化済み）。
    番地は先頭 3 つの数字（丁目-番-号）までで、4 つ目以降（例: 台場1-3-5-103 の -103）は除去する"""
    a = _normalize_address(address)
    m = _NUM_RE.match(a)
    if not m:
        return a
    num = m.group("num")
    runs = list(_DIGITS_RE.finditer(num))
    if len(runs) > 3:
        end = runs[2].end()
        suffix = re.match(r"(丁目|番地|番|号)", num[end:])  # 3 つ目の直後の「号」等は残す
        num = num[: end + (len(suffix.group(0)) if suffix else 0)]
    return (m.group("head") + num).replace(" ", "")


def has_block_number(cleaned):
    """番地(番・号)まで書かれているか。町名の直後に「N丁目」だけ、または数字なしなら False"""
    m = _NUM_RE.match(cleaned)
    if not m:
        return False
    num = m.group("num")
    return not re.fullmatch(r"\d+丁目", num)


# --- abrg 呼び出し ---------------------------------------------------------------------

def run_abrg(queries, abrg_bin, abrg_dir, work_dir, target):
    """住所リストを abrg CLI に一括投入し {query: result dict} を返す"""
    work_dir.mkdir(parents=True, exist_ok=True)
    in_path = work_dir / "geocheck_queries.txt"
    in_path.write_text("\n".join(queries) + "\n", encoding="utf-8")
    cmd = [str(abrg_bin), str(in_path), "-d", str(abrg_dir), "--silent", "-f", "json", "--target", target]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    if proc.returncode != 0:
        sys.exit(f"abrg が失敗しました (exit {proc.returncode}):\n{proc.stderr[-2000:]}")
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        sys.exit(f"abrg の出力が JSON ではありません:\n{proc.stdout[:500]}\n{proc.stderr[-500:]}")
    return {item["query"]["input"]: item["result"] for item in data}


# --- 判定 ------------------------------------------------------------------------------

def city_of(result):
    return "".join(x for x in (result.get("county"), result.get("city"), result.get("ward")) if x)


def city_matches(cleaned, result):
    """住所文字列が abrg の解析した市区町村で始まるか（都道府県名の後ろを比較）"""
    rest = cleaned
    pref = result.get("pref") or ""
    if pref and rest.startswith(pref):
        rest = rest[len(pref):]
    names = [city_of(result), (result.get("city") or "") + (result.get("ward") or ""), result.get("city") or ""]
    return any(n and rest.startswith(n) for n in names)


def facility_hits(row, words):
    """name / address / description から施設語を探す。address は町名部分（番地より前。例: 芝公園・上野公園）を除外し、
    全項目から「〜通り」を除外する。"SC" は英字に挟まれない場合のみ一致"""
    name = unicodedata.normalize("NFKC", row.get("name") or "")
    addr = _normalize_address(row.get("address"))
    m = _NUM_RE.match(addr)
    addr = addr[len(m.group("head")):] if m else ""  # 番地以降（ビル名など）だけを見る。番地が無い住所は町名のみなので対象外
    desc = unicodedata.normalize("NFKC", row.get("description") or "")
    text = " ".join(_DORI_RE.sub("", t) for t in (name, addr, desc))
    na_text = " ".join(_DORI_RE.sub("", t) for t in (name, addr))
    hits = [w for w in words if w in (na_text if w in NAME_ADDRESS_ONLY_WORDS else text)]
    if _SC_RE.search(text):
        hits.append("SC")
    return hits


def decimals(cell):
    """セル文字列の小数桁数（末尾の 0 は除く。35.62160 → 4）"""
    s = (cell or "").strip()
    if "." not in s:
        return 0
    return len(s.split(".", 1)[1].rstrip("0"))


def others_has_partial(level, geo):
    """abrg が番号を解釈しきれていない（others に数字が残る）か。
    A は数字が残れば部分一致。B（街区止まり）は号が残るのが通常なので「-N」ひとつだけは許容し、それ以上を部分一致とする"""
    joined = "".join(geo.get("others") or [])
    if not re.search(r"\d", joined):
        return False
    if level == "B":
        return not re.fullmatch(r"[-‐−–—ー]?\d+", joined)
    return True


def gsi_first(gsi_entry):
    """GSI 結果の先頭候補 (lat, lng, title)。結果なしは None"""
    res = (gsi_entry or {}).get("res") or []
    if not res:
        return None
    f = res[0]
    lng, lat = f["geometry"]["coordinates"]
    return lat, lng, (f.get("properties") or {}).get("title", "")


def judge(row, geo, cleaned, args, words, gsi_entry, has_gsi, forced):
    """1店分の判定。dict を返す（level_class, fac, dist, decision, reason, glat, glng, gsi_d）"""
    closed = parse_bool(row.get("is_closed"))
    lat, lng = float(row["latitude"]), float(row["longitude"])
    hits = facility_hits(row, words)
    no_block = bool(cleaned) and not has_block_number(cleaned)
    if no_block:
        hits = hits + ["住所に番・号なし"]
    fac = bool(hits)

    def out(level, decision, reason, d="", glat="", glng="", gsi_d=""):
        return {"level": level, "fac": fac, "d": d, "decision": decision, "reason": reason,
                "glat": glat, "glng": glng, "gsi_d": gsi_d}

    if closed:
        return out("", "skip", "is_closed=true")
    if not cleaned:
        return out("C", "keep_coarse", "住所が空")

    # 精度は coordinate_level（座標そのものの精度）を採用する。地番(parcel)で名寄せできても、
    # 地番位置参照データが無いと座標は町字代表点（coordinate_level=machiaza_detail 以下）になるため C 扱い
    ml = (geo or {}).get("match_level")
    cl = (geo or {}).get("coordinate_level")
    level = LEVEL_CLASS.get(cl, "C") if LEVEL_CLASS.get(ml) else "C"
    glat, glng = (geo or {}).get("lat"), (geo or {}).get("lon")
    has_geo = glat is not None and glng is not None
    d = haversine_m(lat, lng, glat, glng) if has_geo else None
    ddisp = f"{d:.1f}" if d is not None else ""
    detail = f"{ml}/{cl}; {(geo or {}).get('output', '')}"

    if forced:
        return out(level if has_geo else "C", "manual", f"明示指定(QA); {detail}", ddisp, glat or "", glng or "")
    if level == "C" or not has_geo:
        why = "ジオコード不能" if not geo or not has_geo else f"粗い精度(match={ml}, coord={cl})"
        return out("C", "keep_coarse", why, "", glat if has_geo else "", glng if has_geo else "")

    def o(decision, reason, gsi_d=""):
        return out(level, decision, f"{reason}; {detail}", ddisp, glat, glng, gsi_d)

    if not city_matches(cleaned, geo):
        return o("investigate", f"市区町村不一致 ({city_of(geo)})")
    if d > args.investigate_over:
        return o("investigate", f"{args.investigate_over:g}m超")
    if others_has_partial(level, geo):
        return o("manual", f"部分一致 (others={''.join(geo.get('others') or [])})")
    if fac:
        if d <= args.facility_keep:
            return o("keep", f"施設({'/'.join(hits)}) {args.facility_keep:g}m以内")
        return o("manual", f"施設({'/'.join(hits)}) {args.facility_keep:g}m超")
    if level == "A":
        if d <= args.a_keep:
            return o("keep", f"A {args.a_keep:g}m以内")
        cand = f"A {args.a_keep:g}m超"
    else:  # level == "B"
        if d <= args.b_keep:
            return o("keep", f"B {args.b_keep:g}m以内")
        cand = f"B {args.b_keep:g}m超"

    # --- fix 候補の関門 ---
    if max(decimals(row.get("latitude")), decimals(row.get("longitude"))) >= args.precise_decimals:
        if d <= args.precise_keep:
            return o("keep", f"既存ピン精密 {args.precise_keep:g}m以内")
        return o("manual", f"既存ピン精密 {args.precise_keep:g}m超 (小数{args.precise_decimals}桁以上の旧座標を上書きしない)")
    if cl == "parcel":
        return o("manual", "地番座標 (地番由来の座標は fix に使わない)")
    if not has_gsi:
        return o("gsi_pending", f"{cand} GSI未照合")
    g = gsi_first(gsi_entry)
    if g is None:
        return o("manual", "GSIなし (GSI に結果が無い)")
    gd = haversine_m(glat, glng, g[0], g[1])
    if gd > args.gsi_tolerance:
        return o("manual", f"GSI不一致 (abrgとGSIが{gd:.0f}m離れている; GSI={g[2]})", f"{gd:.1f}")
    return o("fix", cand, f"{gd:.1f}")


# --- report ----------------------------------------------------------------------------

def cmd_report(args):
    with open(args.cafes, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    cleaned = {}
    for i, row in enumerate(rows):
        closed = parse_bool(row.get("is_closed"))
        cleaned[i] = "" if closed else clean_address(row.get("address"))
    queries = sorted({c for c in cleaned.values() if c})

    work_dir = Path(args.work_dir) if args.work_dir else Path(args.out).resolve().parent
    if args.geo_json:
        geo_map = json.loads(Path(args.geo_json).read_text(encoding="utf-8"))
        if any(q not in geo_map for q in queries):
            sys.exit("--geo-json に無い住所があります（cafes.csv が変わった？ abrg で再ジオコードしてください）")
    else:
        geo_map = run_abrg(queries, args.abrg_bin, args.abrg_dir, work_dir, args.target)
        if args.save_geo_json:
            Path(args.save_geo_json).write_text(json.dumps(geo_map, ensure_ascii=False), encoding="utf-8")

    gsi_map = json.loads(Path(args.gsi_json).read_text(encoding="utf-8")) if args.gsi_json else {}
    suffixes = args.force_manual if args.force_manual is not None else FORCE_MANUAL_DEFAULT
    forced_ids = {r["id"] for r in rows if any(r["id"].endswith("-" + sfx.zfill(12)) for sfx in suffixes)}
    if len(forced_ids) != len(suffixes):
        print(f"警告: --force-manual の {len(suffixes)} 件中 {len(forced_ids)} 件しか cafes.csv に見つかりません", file=sys.stderr)

    words = [w for w in FACILITY_WORDS if w not in (args.drop_facility_words or [])] + list(args.facility_words or [])
    out_rows = []
    for i, row in enumerate(rows):
        geo = geo_map.get(cleaned[i]) or {}
        entry = gsi_map.get(row.get("id", ""))
        if entry is not None and entry.get("q") != cleaned[i]:
            entry = None  # 住所が変わった古い GSI 結果は使わない
        j = judge(row, geo_map.get(cleaned[i]), cleaned[i], args, words, entry, bool(args.gsi_json), row["id"] in forced_ids)
        out_rows.append({
            "id": row.get("id", ""), "name": row.get("name", ""), "address": row.get("address", ""),
            "is_closed": row.get("is_closed", ""), "lat": row.get("latitude", ""), "lng": row.get("longitude", ""),
            "geo_lat": j["glat"], "geo_lng": j["glng"], "level_class": j["level"],
            "facility_flag": "F" if j["fac"] else "", "distance_m": j["d"], "decision": j["decision"],
            "reason": j["reason"],
            "geo_address": geo.get("output", "") if cleaned[i] else "",
            "geo_level": geo.get("coordinate_level", "") if cleaned[i] else "",
            "gsi_distance_m": j["gsi_d"],
        })

    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=OUT_COLUMNS)
        w.writeheader()
        w.writerows(out_rows)

    # --- 標準出力サマリ
    print(f"対象 {len(rows)} 行 / ジオコード対象ユニーク住所 {len(queries)} 件 → {args.out}")
    counts = Counter(r["decision"] for r in out_rows)
    tags = Counter((r["decision"], r["reason"].split(";")[0]) for r in out_rows)
    for k in ("keep", "fix", "gsi_pending", "manual", "investigate", "keep_coarse", "skip"):
        if k == "gsi_pending" and not counts.get(k):
            continue
        print(f"  {k:12s} {counts.get(k, 0)}")
        for (dec, tag), n in sorted(tags.items(), key=lambda x: -x[1]):
            if dec == k:
                print(f"      {tag}: {n}")
    print("  精度クラス別:", dict(sorted(Counter(r["level_class"] or "-" for r in out_rows).items())),
          "/ 施設フラグ:", sum(1 for r in out_rows if r["facility_flag"]))
    fix_d = sorted(float(r["distance_m"]) for r in out_rows if r["decision"] == "fix")
    if fix_d:
        print(f"  fix の距離: 中央値 {statistics.median(fix_d):.1f}m / 最大 {max(fix_d):.1f}m / 件数 {len(fix_d)}")
    else:
        print("  fix: 0件")


# --- gsi -------------------------------------------------------------------------------

def gsi_fetch(q):
    req = urllib.request.Request(GSI_URL + urllib.parse.quote(q), headers={"User-Agent": "puppy-with-cafe-geocheck"})
    last = None
    for _ in range(3):
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return json.loads(r.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            last = e
            time.sleep(2)
    raise RuntimeError(f"GSI 問い合わせに失敗: {q}: {last}")


def cmd_gsi(args):
    """report の fix 候補（decision=gsi_pending）だけを GSI 住所検索へ問い合わせ、{id: {q, res}} をJSON保存する。
    既存の出力JSON（同じ住所のもの）は再利用する。1 秒 1 件"""
    with open(args.report, newline="", encoding="utf-8-sig") as f:
        report = [r for r in csv.DictReader(f) if r["decision"] in args.decisions]
    cache = {}
    if args.out.exists():
        cache = json.loads(args.out.read_text(encoding="utf-8"))
    fetched = 0
    for r in report:
        q = clean_address(r["address"])
        e = cache.get(r["id"])
        if e and e.get("q") == q and e.get("res") is not None:
            continue
        if fetched:
            time.sleep(args.interval)
        cache[r["id"]] = {"q": q, "res": gsi_fetch(q)}
        fetched += 1
        if fetched % 20 == 0:
            args.out.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    args.out.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    print(f"GSI: 対象 {len(report)} 件 / 新規問い合わせ {fetched} 件 / 再利用 {len(report) - fetched} 件 → {args.out}")


# --- apply -----------------------------------------------------------------------------

def _read_csv_bytes(path):
    raw = Path(path).read_bytes()
    text = raw.decode("utf-8")
    return raw, list(csv.reader(io.StringIO(text, newline="")))


def _dump_csv(rows):
    out = io.StringIO(newline="")
    csv.writer(out, lineterminator="\r\n").writerows(rows)
    return out.getvalue().encode("utf-8")


def cmd_apply(args):
    """report CSV の decision=fix 行だけを cafes.csv の latitude/longitude に反映し、coord_sources.csv を出力する。
    --write なしは dry-run（何も書かない）。"""
    raw, rows = _read_csv_bytes(args.cafes)
    # 事前確認: 読み込み→そのまま書き戻しでバイト一致しなければ中止（書式・改行・引用の差異で巨大diffになるのを防ぐ）
    if _dump_csv(rows) != raw:
        sys.exit("中止: cafes.csv を csv で読み書きしたとき元とバイト一致しません（書式が想定外）。何も書き込んでいません")
    header = rows[0]
    try:
        i_id, i_name = header.index("id"), header.index("name")
        i_lat, i_lng = header.index("latitude"), header.index("longitude")
    except ValueError as e:
        sys.exit(f"中止: cafes.csv に必要な列がありません: {e}")
    by_id = {r[i_id]: r for r in rows[1:]}
    if len(by_id) != len(rows) - 1:
        sys.exit("中止: cafes.csv の id が重複または空です")

    with open(args.report, newline="", encoding="utf-8-sig") as f:
        report = list(csv.DictReader(f))
    if any(rp["decision"] == "gsi_pending" for rp in report):
        sys.exit("中止: report に GSI 未照合（gsi_pending）の行があります。gsi → report --gsi-json をやり直してください")

    new_rows = [list(r) for r in rows]
    new_by_id = {r[i_id]: r for r in new_rows[1:]}
    changed_cells = 0
    fix_ids = []
    for rp in report:
        if rp["decision"] != "fix":
            continue
        cid = rp["id"]
        row = new_by_id.get(cid)
        if row is None:
            sys.exit(f"中止: report の id が cafes.csv にありません: {cid} {rp['name']}")
        if row[i_name] != rp["name"] or row[i_lat] != rp["lat"] or row[i_lng] != rp["lng"]:
            sys.exit(f"中止: report が cafes.csv と食い違っています（report が古い？）: {cid} {rp['name']}")
        new_lat, new_lng = f"{float(rp['geo_lat']):.5f}", f"{float(rp['geo_lng']):.5f}"
        changed_cells += (row[i_lat] != new_lat) + (row[i_lng] != new_lng)
        row[i_lat], row[i_lng] = new_lat, new_lng
        fix_ids.append(cid)

    # 検証: 変更されたセルは fix 対象行の latitude/longitude だけ
    diff_cells = 0
    for old, new in zip(rows[1:], new_rows[1:]):
        for ci, (a, b) in enumerate(zip(old, new)):
            if a != b:
                diff_cells += 1
                if old[i_id] not in fix_ids or ci not in (i_lat, i_lng):
                    sys.exit(f"中止: 想定外のセルが変わります: {old[i_id]} 列 {header[ci]}")
    if diff_cells != changed_cells:
        sys.exit(f"中止: 変更セル数が一致しません（数え上げ {changed_cells} / 差分 {diff_cells}）")

    # coord_sources.csv（skip 以外の全行。fix は新座標、それ以外は現座標）
    # method: fix 行=abr_geocoder（座標を ABR 由来に更新）/ それ以外=legacy_estimate（従来の概算座標のまま）
    # level / geocoded_address / distance_m / gsi_distance_m は「照合に使った abrg・GSI の結果」の記録であり、
    # method=legacy_estimate の行では座標自体の精度ではない（distance_m = 旧座標と abrg 結果の距離）
    cs_rows = [COORD_SOURCE_COLUMNS]
    for rp in report:
        if rp["decision"] == "skip":
            continue
        row = new_by_id[rp["id"]]
        is_fix = rp["decision"] == "fix"
        note = f"座標を更新（旧 {rp['lat']},{rp['lng']}）" if is_fix else ""
        cs_rows.append([
            rp["id"], rp["name"], row[i_lat], row[i_lng], "abr_geocoder" if is_fix else "legacy_estimate",
            rp.get("geo_level", ""), rp.get("geo_address", ""), rp["distance_m"], rp.get("gsi_distance_m", ""),
            rp["decision"], args.ref, args.verified_at, note,
        ])

    print(f"{'WRITE' if args.write else 'DRY-RUN'}: fix {len(fix_ids)} 行 / 変更セル {changed_cells}"
          f"（期待 最大 {2 * len(fix_ids)}）/ coord_sources {len(cs_rows) - 1} 行")
    if not args.write:
        print("  --write を付けると cafes.csv と coord_sources.csv を書き込みます")
        return
    Path(args.cafes).write_bytes(_dump_csv(new_rows))
    Path(args.coord_sources).write_bytes(_dump_csv(cs_rows))
    print(f"  書き込み: {args.cafes} / {args.coord_sources}")


def build_parser():
    p = argparse.ArgumentParser(description="掲載店の座標を abr-geocoder / 国土地理院の住所ジオコードと突き合わせる")
    sub = p.add_subparsers(dest="command", required=True)

    r = sub.add_parser("report", help="判定レポートCSVを出力する（マスターは変更しない）")
    r.add_argument("--cafes", type=Path, default=DEFAULT_CAFES_CSV, help="読み取る cafes.csv（既定: マスター）")
    r.add_argument("--out", type=Path, required=True, help="出力CSV")
    r.add_argument("--abrg-bin", default="abrg", help="abrg コマンドのパス（既定: PATH 上の abrg）")
    r.add_argument("--abrg-dir", help="abrg データディレクトリ（abrg download -d で作ったもの）")
    r.add_argument("--target", default="all", choices=["all", "residential", "parcel"], help="abrg の検索ターゲット")
    r.add_argument("--work-dir", default=None, help="abrg 入力ファイルの置き場（既定: 出力CSVのあるディレクトリ）")
    r.add_argument("--geo-json", help="保存済みジオコード結果JSON（指定時は abrg を実行しない）")
    r.add_argument("--save-geo-json", help="ジオコード結果を {クエリ: result} のJSONで保存する")
    r.add_argument("--gsi-json", help="gsi サブコマンドの結果JSON（未指定だと fix 候補は gsi_pending になる）")
    r.add_argument("--a-keep", type=float, default=50.0, help="A: keep とする上限距離 m（既定 50）")
    r.add_argument("--b-keep", type=float, default=100.0, help="B: keep とする上限距離 m（既定 100）")
    r.add_argument("--facility-keep", type=float, default=300.0, help="施設F: keep とする上限距離 m（既定 300）")
    r.add_argument("--investigate-over", type=float, default=5000.0, help="これを超えると investigate（既定 5000）")
    r.add_argument("--precise-decimals", type=int, default=5, help="旧座標の lat/lng がこの小数桁数以上なら精密ピンとみなす（既定 5。小数4桁以下は丸めた概算座標として上書き対象）")
    r.add_argument("--precise-keep", type=float, default=300.0, help="精密ピンを keep とする上限距離 m（既定 300。超過は manual）")
    r.add_argument("--gsi-tolerance", type=float, default=150.0, help="abrg と GSI の許容距離 m（既定 150。超過は manual）")
    r.add_argument("--force-manual", nargs="*", default=None,
                   help="明示的に manual とする id 末尾（既定: QA 指定の11件）。空にするには引数なしで指定")
    r.add_argument("--facility-words", nargs="*", help="施設フラグ語を追加")
    r.add_argument("--drop-facility-words", nargs="*", help="既定の施設フラグ語から外す語（感度分析用）")
    r.set_defaults(func=cmd_report)

    g = sub.add_parser("gsi", help="fix 候補を国土地理院の住所検索へ問い合わせ、結果をJSON保存する（1秒1件）")
    g.add_argument("--report", type=Path, required=True, help="GSI 未照合で出した report CSV")
    g.add_argument("--out", type=Path, required=True, help="結果JSON（既存なら同じ住所の分は再利用）")
    g.add_argument("--decisions", nargs="+", default=["gsi_pending"], help="問い合わせ対象の decision（既定 gsi_pending）")
    g.add_argument("--interval", type=float, default=1.0, help="問い合わせ間隔 秒（既定 1.0）")
    g.set_defaults(func=cmd_gsi)

    a = sub.add_parser("apply", help="report の decision=fix 行を cafes.csv に反映し coord_sources.csv を出力（既定 dry-run）")
    a.add_argument("--report", type=Path, required=True, help="report が出力したCSV")
    a.add_argument("--cafes", type=Path, default=DEFAULT_CAFES_CSV, help="更新する cafes.csv（既定: マスター）")
    a.add_argument("--coord-sources", type=Path, default=DEFAULT_COORD_SOURCES_CSV, help="出力する coord_sources.csv")
    a.add_argument("--ref", default=DEFAULT_REF, help="coord_sources の ref 列")
    a.add_argument("--verified-at", default=date.today().isoformat(), help="coord_sources の verified_at 列（既定: 今日）")
    a.add_argument("--write", action="store_true", help="実際に書き込む（無ければ dry-run）")
    a.set_defaults(func=cmd_apply)
    return p


def main():
    args = build_parser().parse_args()
    if args.command == "report" and not args.geo_json and not args.abrg_dir:
        sys.exit("--abrg-dir か --geo-json のどちらかが必要です")
    args.func(args)


if __name__ == "__main__":
    main()
