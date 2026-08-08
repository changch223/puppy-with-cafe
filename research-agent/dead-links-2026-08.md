# 死リンク（切れリンク）掃除レポート（2026-08-08）

`data/master/cafes.csv` の `link_website / link_tabelog / link_instagram / link_instagram_post / link_x` と `data/master/sources.csv` の `reference`（出典URL）から抽出したURLを curl で疎通確認し、高確度で死んでいるものだけ `cafes.csv` の該当セルを空にした。**`sources.csv` は監査証跡のため一切変更していない**。

## サマリ

| 項目 | 件数 |
|---|---|
| チェックしたユニークURL | **1,062件**（`cafes.csv` link_* 由来488件 / `sources.csv` reference 由来768件、重複194件） |
| ALIVE（生存） | 1,048件 |
| DEAD（確定死＝掃除対象） | 9件（`cafes.csv` 由来7件・`sources.csv` 由来2件） |
| BLOCKED/UNCERTAIN（判定保留・温存） | 5件 |
| `cafes.csv` で掃除した `link_*` セル | **7件**（すべて `link_website` 列） |

> 抽出時の注記: `link_instagram` 列は**107件が `@handle` 形式**（フルURLではなくハンドルのみ）で保存されており、これらはURLではないためチェック対象外・掃除対象外とした（`@handle` を疎通確認しようとするとDNS解決不能になり誤ってDEAD判定されるバグを事前に検出し除外した）。

## 判定方法

- `curl -sSL -A "Mozilla/5.0 ..." --max-time 15 -o /dev/null -w "%{http_code}"`（`-L` でリダイレクト追跡）
- DEAD候補（curl exit 6＝DNS解決不能、または最終HTTP 404/410）は**1.5秒間隔で2回リトライし、両方とも DEAD候補と再現した場合のみ確定**。今回のレポート作成では、さらに掃除実行前に**手動で3回目の独立確認**も全9件で実施し、全件が同じ結果（DNS不能 or 404）を再現したことを確認済み。
- 401/403/429/999、タイムアウト（exit 28）、SSLエラー（exit 35/60）、connection refused（exit 7）、その他5xx等の曖昧な結果はすべて **BLOCKED＝温存**（掃除しない）。
- 並列数15、対象サーバへの負荷を抑制。

## 掃除した `link_*` 一覧（cafes.csv・7件）

| カフェ名 | 列 | 消したURL | DEAD理由 |
|---|---|---|---|
| T.Y.HARBOR | link_website | https://www.tyharborbrewing.co.jp/tyharbor/ | DNS解決不能 |
| 炭火×薪火×レストラン RIDE 品川 天王洲店 | link_website | https://ride-tennoz.com/ | DNS解決不能 |
| breadworks 天王洲 | link_website | https://www.tyharborbrewing.co.jp/breadworks/ | DNS解決不能 |
| nakameguro SLOW TABLE | link_website | https://yoyaku.toreta.in/slowtable | HTTP 404 |
| 洋食屋クリスマス亭 | link_website | https://christmas-tei.com/ | HTTP 404 |
| ハーベステラス 昭島アウトドアヴィレッジ店 | link_website | https://store.montbell.jp/harvesterrace/ | HTTP 404 |
| MAISON KAYSER 五反田店 | link_website | https://maisonkayser.jp/brands/bakery/167/ | HTTP 404 |

すべて `link_website`（公式サイト）列のみが対象。`link_tabelog / link_instagram / link_instagram_post / link_x` に確定DEADはなかった。

## 出典（sources.csv）の死リンク一覧（削除していない・要再調査）

**`sources.csv` は変更していない。**以下は将来の再調査バッチ向けの参考リストのみ（出典・確認日・provenanceの監査証跡として保持）。

| カフェ名 | cafe_id | URL | 理由 |
|---|---|---|---|
| Ralph's Coffee Omotesando | beef0000-0000-4000-8000-000000000088 | https://omotesando-blog.com/ralphs-coffee-omotesando/ | DNS解決不能 |
| rice cafe | beef0000-0000-4000-8000-000000000649 | https://kinarino.jp/cat4/16698 | HTTP 404 |

## BLOCKED（判定保留・温存）5件

いずれも tabelog / Instagram のbot弾きではなく、個別サイトのタイムアウト・5xx・不明瞭な応答によるもの。**掃除せず現状維持**。

| URL | 理由 |
|---|---|
| https://pizzeriapicchi.jp/index.html | タイムアウト（15秒以内に応答なし） |
| https://paceitalianlounge.com/ | HTTP 403 |
| http://cafe-earth.com/index.php?id=23 | 応答が曖昧（5xx系・非確定） |
| https://retty.me/area/PRE13/ARE20/SUB2005/100000111393/ | 応答が曖昧（5xx系・非確定） |
| https://4travel.jp/dm_shisetsu/11570101 | HTTP 403 |

> 補足: `tabelog.com`（195件）・`www.instagram.com`（95件）は、想定していた bot 弾き（403/429）はほぼ発生せず、ブラウザUAでのGETで大半が200を返した。上記BLOCKED5件はこの2ドメインとは無関係の個別サイト。

## 検証

- `python3 tools/export_cafes.py --check` → **0エラー**確認
- 本実行で `data/cafes.json`・`DokoWanCafe/DokoWanCafe/Resources/cafes.json`・`data/CHANGELOG.md` を再生成
