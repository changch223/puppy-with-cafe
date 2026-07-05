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
| hours_mon 〜 hours_sun | `9:00-18:00`（複数帯は `,` 区切り）/ `定休` / 空=不明 | `9:00-12:00,13:00-18:00` |
| link_website / link_instagram / link_x / link_tabelog | URL | https://... |
| dog_indoor / dog_terrace / dog_large / dog_menu | true / false / 空=不明 | true |
| dog_note | 文字列 | カート必須・ワクチン証明の提示あり |
| info_verified | YYYY-MM-DD | 営業時間等・基本情報の確認日 |
| insta_note | 文字列 | 公式Instagramで確認した内容の転記 |
| insta_note_date | YYYY-MM-DD | **insta_note がある場合は必須**（無いと配信エラー） |

- 曜日別（hours_mon〜sun）を1曜日でも入れると、アプリに「🟢営業中／営業時間外／本日定休」バッジが出る（入れない店はバッジなし＝推測しない）
- 日跨ぎ営業（例: 22:00-2:00）は構造化不可 → `hours_text` で表現する

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
