# データ運用手順（構成B: Sheet → cafes.json → 配信）— T064

Puppy With Cafe のカフェデータは **Google Sheet をマスター**とし、検証スクリプトを通った
`cafes.json` だけが配信される（憲章 原則I: 検証を通らないデータは配信されない）。

## 全体フロー

```
① Google Sheet を編集（cafes / sources の2タブ）
② 2タブを CSV でダウンロード（ファイル > ダウンロード > .csv）
③ python3 tools/export_cafes.py --cafes <cafes.csv> --sources <sources.csv>
   → 検証・矛盾/代表算出・差分検出・cafes.json 生成（アプリにも自動コピー）
④ 差分を確認（画面表示 & data/CHANGELOG.md & git diff）
⑤ git commit & push
   → GitHub Pages の cafes.json が更新され、アプリが次回起動時に取得（アプリ審査不要で即反映）
```

誤り報告は Google フォーム → 回答が Sheet に自動集約 → 内容を確認して ①〜⑤ を実施（＝承認・反映）。
却下する場合は何もしない（マスターに反映しない限り表示は変わらない）。

## Google Sheet の列仕様

### タブ1: cafes（1行=1店舗）

| 列 | 必須 | 説明 |
|---|---|---|
| id | | UUID。**空欄なら自動採番**（place_id または名称+座標から決定論的に生成） |
| place_id | | 外部の場所ID（あれば。名寄せの主キー, FR-030） |
| name | ✅ | 店名 |
| latitude / longitude | ✅ | 緯度・経度（小数） |
| address | | 住所 |
| contact | | 電話または URL |
| is_closed | | 閉店なら `true`（表示から除外） |
| area | | 提供エリア。既定 `tokyo` |

※ **犬同伴可否は cafes タブに書かない**。可否は必ず sources タブの出典から導出される（憶測で「可」にしない仕組み）。

### タブ2: sources（1行=1出典。1店舗に複数可）

| 列 | 必須 | 説明 |
|---|---|---|
| cafe_id | ✅ | cafes タブの id |
| type | ✅ | `official_hp / sns / google_map / tabelog / blog / other` |
| reference | | 出典URL |
| claimed_status | ✅ | この出典が示す可否 `allowed / conditional / not_allowed / unverified` |
| claimed_condition | 条件付き時✅ | 条件テキスト（例: テラス席のみ） |
| verified_at | ✅※ | 確認日 `YYYY-MM-DD`（※unverified 以外は必須） |
| provenance | ✅ | 由来 `official / operator_verified / human_verified / user_submitted_verified / aggregated / ai_inferred` |

### 自動導出されるもの（スクリプトが計算・Sheet に書かない）

- 代表可否・条件・最終確認日・採用根拠（FR-013: 確認日最新 → 由来の信頼順 → 確定不能なら未確認）
- 矛盾フラグ（出典間で可否が割れている場合、アプリに「食い違いあり」と表示される）

### 検証でエラーになる例（＝配信されない）

- `conditional` なのに条件テキストが無い / `unverified` 以外なのに確認日が無い
- enum 値の打ち間違い / 緯度経度が数値でない
- 同じ place_id が2行 / 同名の店が 50m 以内に2行（名寄せ疑い → 統合を促す）

## 差分の共有・追跡（FR-033）

- スクリプト実行時に **追加/変更/削除を画面表示**し、`data/CHANGELOG.md` に自動追記
- `cafes.json` は git 管理なので **コミット履歴＝完全な変更履歴**（GitHub 上で誰でも diff を確認できる）

## 初回セットアップ（未完了のもの）

1. **Google Sheet 作成**: `tools/sheet_template/cafes.csv` / `sources.csv` を Google Sheets にインポート（タブ2つ）
2. **Google フォーム作成**: 質問例「店名（自動入力）／正しい犬同伴可否／条件／根拠・気づいたこと」。
   回答先を上記 Sheet の新タブに設定。「事前入力したURLを取得」で店名の entry ID を確認し、
   アプリの `AppConfig.reportFormURLTemplate` に `https://docs.google.com/forms/d/e/<FORM_ID>/viewform?usp=pp_url&entry.<ID>={cafe_name}` を設定
3. **GitHub Pages**: リポジトリを GitHub に push → Settings > Pages を有効化 →
   `https://<user>.github.io/<repo>/data/cafes.json` を `AppConfig.defaultCafesDataURL` に設定

## 追加列（002-cafe-rich-info: 営業時間・公式情報・犬向け設備）

cafes タブに以下を追加（**すべて任意**。空欄＝不明として扱われ、「なし/✕」とは表示されない）:

| 列 | 形式 | 例 |
|---|---|---|
| phone | 文字列 | 03-1234-5678（詳細でタップ発信） |
| reservation | 文字列 | 予約可（電話・当日可） |
| hours_text | 文字列 | 9:00〜18:00（不定休あり）※構造化が難しい店向け |
| hours_mon 〜 hours_sun | `9:00-18:00`（複数帯は `,` 区切り）/ `定休` / 空=不明。閉店は `24:00` まで可、開店>=閉店（例 `18:00-2:00`）は日跨ぎ営業として構造化可 | `9:00-12:00,13:00-18:00` / `18:00-2:00` |
| link_website / link_instagram / link_x / link_tabelog | URL | https://... |
| link_instagram_post | URL | https://www.instagram.com/p/Cxxxxxxxxxxx/（IG投稿/リールのURLのみ許可。ユーザー名付き `https://www.instagram.com/店アカウント/p/...` も可・自動正規化） |
| dog_indoor / dog_terrace / dog_large / dog_menu | true / false / 空=不明 | true |
| dog_note | 文字列 | カート必須・ワクチン証明の提示あり |
| info_verified | YYYY-MM-DD | 営業時間等・基本情報の確認日 |
| insta_note | 文字列 | 公式Instagramで確認した内容の転記 |
| insta_note_date | YYYY-MM-DD | **insta_note がある場合は必須**（無いと配信エラー） |

- 曜日別（hours_mon〜sun）を1曜日でも入れると、アプリに「🟢営業中／営業時間外／本日定休」バッジが出る（入れない店はバッジなし＝推測しない）
- 日跨ぎ営業（例: `22:00-2:00`）・24:00終端（例: `17:00-24:00`）は構造化して入れられる（S4）。判定は `OpeningHoursEvaluator` が日跨ぎ対応

## 実データ対応の追加列（FR-107・2026-07-05）

| 列 | 形式 | 例 |
|---|---|---|
| sub_area | 文字列 | 天王洲アイル（表示用の地区名。area はサービス圏コード `tokyo` のまま） |
| description | 文字列 | アートギャラリー併設のカフェ（店舗紹介・詳細ヘッダーに表示） |
| dog_size_limit | 文字列 | 小型・中型（抱っこ・カート推奨） |
| holiday_note | 文字列 | 不定休（展示入れ替え・貸切で休館あり） |

- `link_instagram` は **@ハンドルだけでもOK**（`@shop_name` → `https://www.instagram.com/shop_name/` に自動変換）
- どの項目も `unknown` / `不明` / `-` は**空欄と同じ扱い**（アプリでは「不明」表示。「なし/✕」にはならない）

## マスターCSVの場所（Google Sheet 移行まで）

- **実データの正本**: `data/master/cafes.csv` / `data/master/sources.csv`（`export_cafes.py` の既定入力）
- テンプレート: `tools/sheet_template/*.csv`（Google Sheets へのインポート用・架空サンプル入り）
- 運用: `data/master/*.csv` を直接編集 → `python3 tools/export_cafes.py` → 差分確認 → commit

## 座標の突き合わせ（geocheck_coords.py・デジタル庁 abr-geocoder + 国土地理院）

掲載店の座標（`cafes.csv` の latitude/longitude）を、住所を abr-geocoder（アドレス・ベース・レジストリ）で
ジオコードした座標と突き合わせて判定し、さらに国土地理院の住所検索（msearch.gsi.go.jp）でも同じ点を確認できた `fix` だけを書き戻す（GSI と ABR は同系統の位置参照データのため独立検証ではなく、abrg の誤りを防ぐ確認程度）。
出典台帳は `data/master/coord_sources.csv`。

### 出典・ライセンス
- ABR データは「公共データ利用規約（第1.0版）（PDL1.0）」（https://www.digital.go.jp/policies/base_registry_address_tos）。
  表記は「位置情報の一部は、デジタル庁『アドレス・ベース・レジストリ』を Puppy With Cafe 運営が加工して作成」（`docs/privacy.html` に掲載）。
- abr-geocoder 本体は MIT。開発用ツールでありアプリには同梱しない。
- **地番（coordinate_level=parcel）由来の座標は fix に使わない**（登記所備付地図データの規約・住居表示と地番の取り違えを避けるため）。台帳の `geocoded_address`/`level` に parcel が現れるのは照合記録のみで、cafes.csv に書き込まれる座標は住居表示（residential_*）由来に限る。

### abrg のセットアップ（作業用ディレクトリに作る。リポジトリには入れない）
- **Node.js 22 LTS が必須**（24 は依存の uWebSockets.js が非対応で起動しない）。グローバル導入せず、公式 tarball を作業ディレクトリに展開して PATH を通すだけでよい。
- `npm install --save-exact @digital-go-jp/abr-geocoder@2.3.1`（deprecated 表示だが v2.3.1 で動作確認済み）
- データ取得は **`-c` に東京都62市区町村の LG code を個別に指定**し、**`-t 1`** で実行する（約86MB・DB約670MB）:
  `abrg download -d <dir> -c 131016 131024 ... 134210 -t 1 --silent`
  - `-c 130001`（都道府県コード）だと、住居表示（街区・住居）が DB に取り込まれずエラーも出ない。
  - 市区町村コードは `<dir>/download/mt_city_pref13.csv` の `lg_code` 列から取れる。既定スレッド数だと `SQLITE_BUSY` で落ちる。

### 使い方（レポート → GSI 確認 → 再レポート → 書き戻し）
```bash
python3 tools/geocheck_coords.py report --abrg-bin <abrg> --abrg-dir <dir> --save-geo-json geo_raw.json --out pre.csv   # fix 候補は gsi_pending
python3 tools/geocheck_coords.py gsi --report pre.csv --out gsi.json                                               # 1秒1件
python3 tools/geocheck_coords.py report --geo-json geo_raw.json --gsi-json gsi.json --out geocheck.csv             # 最終判定
python3 tools/geocheck_coords.py apply --report geocheck.csv [--write]                                             # 既定 dry-run
python3 tools/export_cafes.py --check
```
- 判定（上から順）: closed→skip / 明示 manual 指定（`--force-manual`、QA 指定の14件）→manual / 住所空 or 精度C→keep_coarse / 市区町村不一致 or d>5000m→investigate / abrg の `others` に番号が残る→manual（部分一致）/ 施設F かつ d≤300→keep・超→manual / A かつ d≤50→keep、B かつ d≤100→keep / 超過は **fix 候補**。
- fix 候補の関門: 旧座標の lat か lng が小数5桁以上（`--precise-decimals`、末尾の 0 は数えない。小数4桁以下は丸めた概算座標とみなして上書き対象）→ d≤300 keep・超→manual / 地番座標→manual / GSI と abrg の距離が150m以下のときだけ fix（超過・GSI 結果なしは manual）。
- 精度クラスは abrg の `match_level` かつ `coordinate_level` で決める（地番一致でも地番位置データが無い地域は町字代表点＝C）。
- 施設フラグ F は name / address（番地より前の町名部分と「〜通り」は除外）/ description から施設語（公園・モール・ヒルズ・グランベリー・ソラマチ・スカイツリー・タワー等）を検索。「タワー」は name/address のみ、「SC」は英字に挟まれない場合のみ。汎用語の「テラス」は「テラス席」で全店に当たるため施設語から外している（「テラス棟」「シーズンテラス」は対象）。
- `apply` は cafes.csv を読み書きしてバイト一致することを事前確認し、fix 行の latitude/longitude セルだけを小数5桁で置換する（CRLF 維持）。gsi_pending が残っていると中止する。
- `export_cafes.py` は、座標が東京都本土範囲外・coord_sources.csv の cafe_id 不在/座標ずれ（1m超）を**警告のみ**で表示する（配信は止まらない）。

### coord_sources.csv の列
`cafe_id,name,latitude,longitude,method,level,geocoded_address,distance_m,gsi_distance_m,decision,ref,verified_at,note`
- `method`: fix 行＝`abr_geocoder`（座標を ABR 由来に更新した）、それ以外＝`legacy_estimate`（従来の概算座標のまま）。
- `latitude`/`longitude`: 現在 cafes.csv にある座標（fix は新座標）。
- **`distance_m`: 旧座標（apply 前の cafes.csv の座標）と abrg 照合結果の距離（m）**。fix 行では「どれだけ動かしたか」、それ以外では「照合結果とどれだけ離れているか」。`level`/`geocoded_address` は照合に使った abrg 結果の精度（coordinate_level）と正規化住所で、`legacy_estimate` 行の座標自体の精度ではない。
- `gsi_distance_m`: abrg と GSI 住所検索の距離（m）。GSI 照合を行った fix 候補のみ記録。
- `decision`: keep / fix / keep_coarse / manual / investigate。

### 実績（2026-10-17・初回適用）
- 594行: keep 276 / **fix 167（cafes.csv の座標を更新）** / manual 40 / keep_coarse 92 / skip（closed）19 / investigate 0。
- fix の移動距離: 中央値 366m、最大 3847m。abrg と GSI の距離は最大 2.4m。
- 残りの概算座標は coord_sources.csv の `decision` が manual（施設内・地番座標・部分一致・QA 指定）/ keep_coarse（町字代表点止まり）の店。
