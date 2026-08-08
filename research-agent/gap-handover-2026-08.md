# データギャップ補完 ハンドオーバー（研究エージェント向け・2026-08-08 / 総数594件）

既存594件の**未収集項目を埋める**調査依頼。新規カフェの追加ではなく、**既存カフェ行の空欄を埋める**作業。
まず必ず `research-agent/README.md`（絶対ルール）と `tools/README.md`（CSV列仕様）を読むこと。

## 絶対ルール（README.md より・厳守）
- **推測禁止**。確認できた事実のみ記入。確認できなければ**空欄のまま**（空欄＝不明であり「不可/なし」ではない）。
- 犬同伴可否・設備に関わる事実は**出典URL＋確認日が必須**。`sources.csv` に出典行を追加する。
- provenance は **`aggregated` 固定**。source type は `official_hp / sns / google_map / tabelog / blog / other` のいずれか。
- **画像・文章の転載禁止**。事実を自分の言葉で要約し出典URLを添えるのはOK。食べログ/Googleは「記載の有無を確認して事実とURLを記録」に留める。
- **コミットしない**。作業は `data/master/cafes.csv` / `data/master/sources.csv` の該当行を編集するだけ。運営がレビューして反映＝承認。
- 自己検証: 編集後に `python3 tools/export_cafes.py --check` を実行し **0エラー**を確認してから納品する。CSVは `csv.DictReader/DictWriter` で列順・クオート・改行を保つこと。

## 対象行の特定
既存行の編集なので、**id または name で行を一意特定**して該当セルだけ埋める（他列・他行は触らない）。同名が複数ある場合は area/sub_area/address で区別し、区別できなければスキップして報告。

---

## バッチF: Instagram 代表投稿URL（52件・最優先/短時間）
- **対象**: `link_instagram` が入っているが `link_instagram_post` が空の行。
  抽出: `python3 -c "import csv;[print(r['name']) for r in csv.DictReader(open('data/master/cafes.csv')) if r['link_instagram'].strip() and not r['link_instagram_post'].strip()]"`
- **集めるもの**: そのカフェの**公式アカウント本人**が公開している投稿/リールのURL 1本（店内・テラス・犬の様子など雰囲気が伝わるものが望ましい）。
- **記入列**: `link_instagram_post` に `https://www.instagram.com/p/<code>/` または `https://www.instagram.com/reel/<code>/` へ正規化して記入（ユーザー名付き形式は `/p/<code>/` へ・クエリ除去）。
- **厳守**: 非公開アカウント・**本人以外（客/ファン）の投稿は採用しない**→空欄のまま。憶測・別アカウント代用は禁止（過去に客の投稿を誤採用した事例あり）。
- sources.csv 追加は不要（可否の主張ではないため）。

## バッチC: 大型犬OK（448件・高価値/フィルタ解禁の残り）
- **対象**: `dog_large` が空の行。
  抽出: `python3 -c "import csv;print(sum(1 for r in csv.DictReader(open('data/master/cafes.csv')) if not r['dog_large'].strip()))"`
- **集めるもの**: 公式サイト/公式SNS/信頼できる媒体で「大型犬可否」「同伴できる犬のサイズ」の記載を確認。
- **記入列**: `dog_large` に **`true`（大型犬OK）/ `false`（小型のみ等で大型不可）/ 空欄（記載なし＝不明）**。tri-state。**記載が無ければ必ず空欄**（推測で true/false にしない）。
  - 併せて `dog_size_limit`（例: 「小型・中型のみ」「抱っこ必須」）や `dog_note` に一次情報の要約を足してよい。
- **sources.csv 追加**: 可否・設備に関わる新事実を確認した場合は出典行を追加（`cafe_id, type, reference=URL, claimed_status, claimed_condition, verified_at=確認日(YYYY-MM-DD), provenance=aggregated`）。

## バッチE: リンク皆無の補完（138件）
- **対象**: `link_website / link_instagram / link_x / link_tabelog` が**すべて空**の行。
  抽出: `python3 -c "import csv;print(sum(1 for r in csv.DictReader(open('data/master/cafes.csv')) if not any(r[c].strip() for c in ['link_website','link_instagram','link_x','link_tabelog'])))"`
- **集めるもの**: 公式サイト / Instagram / 食べログ の URL（見つかった分だけ）。
- **記入列**: `link_website=https://…` / `link_instagram=@ハンドル`（または `https://www.instagram.com/ハンドル/`）/ `link_tabelog=https://tabelog.com/…`。無いものは空欄。
- 併せてその公式ページで犬同伴可否が確認できたら、バッチCと同様に `sources.csv` に出典行を追加すると価値が高い。
- 効果: アプリの「参考記事カード/写真プレビュー（OGP）」の原資が増える。

## バッチD: 営業時間の構造化（テキストのみ446件＋情報なし73件）
- **D-1（Web調査ほぼ不要・機械変換）**: `hours_text` があり構造化列が空の446件。`hours_text` の原文を各曜日列へ構造化する。
  - **記入列**: `hours_mon … hours_sun` に `H:MM-HH:MM`（**24時間表記・0〜23時・開店<閉店**・複数帯はカンマ区切り 例 `11:00-15:00,17:00-22:00`）。定休日は `定休`、不明は空欄。
  - **注意（重要）**: **深夜24:00以降・日跨ぎ営業（例 17:00-24:00, 18:00-翌2:00）は構造化列に入れない**（バリデータが 0-23時/開店<閉店を要求しエラーになる）。その場合は該当曜日を**空欄のままにし、原文は `hours_text` に残す**。
  - `hours_text` が曖昧・複雑で機械変換が難しいものは無理に構造化せず残す。
- **D-2（要調査）**: 営業時間情報が全く無い73件。公式サイト/食べログ/Googleで確認して `hours_text`（＋可能なら構造化列）を埋める。
- 効果: アプリの「営業中」バッジ・「営業中優先」ソートが実用になる。

---

## 優先度と進め方（推奨）
1. **F**（52件・短時間で完了・IG埋め込みの原資）
2. **C**（448件・大型犬OKフィルタの実用性を上げる・分割並列向き）
3. **E**（138件・写真プレビューの原資）
4. **D-1**（機械変換・大量・調査ほぼ不要）→ **D-2**（73件・要調査）

大量バッチは **10〜15件/エージェントで並列**し、**結果はまず構造化で集約→CSV反映は1エージェントに集約**（並列書き込み禁止）、反映後 `export_cafes.py --check` 0エラー確認、の運用実績あり。

## 納品
`data/master/cafes.csv` / `sources.csv` を編集した diff（＋どの列を何件埋めたかのサマリ）を提出。コミットは運営が実施する。
