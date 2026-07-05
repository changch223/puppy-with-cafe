# 🐶 カフェ調査エージェント ブリーフ — Puppy With Cafe データベース構築

**このファイルを読めば、そのまま調査作業を開始できる。** 不明点があれば依頼者（運営）に質問してから進めること。

## 1. プロジェクトは何か・いまどこか

- **Puppy With Cafe**（コードネーム DokoWanCafe）: 愛犬と入れるカフェを現在地から地図で探せる iOS アプリ。
- 解決するペイン: 犬同伴情報は HP/SNS/食べログ/ブログに**散乱**していて、**何が最新で正しいか分からない**。生成AIは「実際は犬OKなのに不可」と**誤答**する。
- だからこのプロジェクトの生命線は**データの信頼性**。全情報に「出典URL・確認日・由来」を付け、**推測で『犬OK』と書くことを絶対に禁止**している（プロジェクト憲章 原則I）。
- 現状: アプリ本体は完成済み・動作中。データは**天王洲アイルの5件のみ**（`data/master/cafes.csv` 参照 — これが記入のお手本）。
- **ゴール: 東京の犬同伴可カフェを網羅した CSV データベースを作ること。** あなたの仕事はその調査・記入。

## 2. あなたのミッション

指定されたエリア（`research-agent/progress.md` の担当行）について:
1. **犬同伴可（可能性含む）のカフェ・レストランを Web 調査**で洗い出す
2. 各店の情報を `data/master/cafes.csv`（店舗）と `data/master/sources.csv`（出典）に**追記**する
3. `python3 tools/export_cafes.py --check` で検証を通す
4. 差分と調査サマリを報告する（**コミットはしない** — 運営レビュー後に反映される）

## 3. 🔒 絶対ルール（違反したデータは配信されない）

1. **推測禁止**: 出典に「犬同伴可」と*明記*されている場合だけ記録する。「ペット可っぽい」「テラスがあるから多分OK」は禁止。曖昧なら `claimed_status=unverified` にするか記録しない。
2. **全ての可否情報に出典URL＋確認日**: sources.csv に1行。確認日（verified_at）は**あなたがそのページを実際に閲覧した日**。
3. **provenance（由来）は必ず `aggregated`**: あなたはWeb収集エージェントなので、公式HPを読んだ場合でも `aggregated`（機械収集・人手未確認）を使う。`official`/`operator_verified`/`human_verified` は運営が一次確認した時だけ昇格させる。`ai_inferred` は使わない（推測自体が禁止のため）。
4. **矛盾は両方記録**: 公式は「可」・ブログは「不可」なら sources に**2行**書く。どちらを表示するかはスクリプトが自動判定する（確認日が新しい方→由来の信頼順→確定不能なら未確認）。あなたが取捨選択しない。
5. **不明は空欄 or `unknown`**: 空欄=「不明」として表示される。「✕/なし」と書いてよいのは出典に不可と明記がある場合だけ。
6. **著作権・規約**: サイトの一括スクレイピング・文章の丸写し・画像の転載は禁止。**事実（犬OK/営業時間等）を自分の言葉で要約し、出典URLを添える**のはOK。食べログ/Googleマップは「犬可の記載があるか確認して事実とURLを記録」に留める（データの機械的大量取得はしない）。

## 4. 集める情報（CSV列と優先度）

記入先: `data/master/cafes.csv`（1行=1店舗・全35列）。**お手本は既存の5行（天王洲）**。

### 🔴 必須（無いと登録できない）
| 列 | 内容・形式 |
|---|---|
| name | 店名（正式表記） |
| latitude / longitude | 緯度経度（Googleマップで店を検索→ピンの座標。小数5桁程度） |
| area | `tokyo` 固定 |
| id | 空欄でOK（自動採番）。**既存行の修正時は既存IDを変えない** |

### 🟠 最重要（アプリの価値の核心）
| 列 | 内容・形式 |
|---|---|
| （sources.csv） | **犬同伴可否の出典**。下記 §5 参照。これが無い店は「未確認」表示になる |
| dog_indoor / dog_terrace | 店内OK / テラスOK（true / false / 空=不明） |
| dog_large / dog_menu | 大型犬OK / 犬用メニュー（同上） |
| dog_size_limit | サイズ制限の説明（例: 小型・中型のみ、抱っこ・カート推奨） |
| dog_note | その他の犬条件（例: リード必須・ワクチン証明提示・混雑時テラスのみ） |
| sub_area | 地区名（例: 代官山・自由が丘）。progress.md のエリア名と揃える |

### 🟡 重要（「行くか決められる」情報）
| 列 | 内容・形式 |
|---|---|
| address | 住所 |
| hours_text | 営業時間（自由記述。例: `11:00〜18:00（L.O.17:30）`） |
| hours_mon 〜 hours_sun | 曜日別 `9:00-18:00`（複数帯は`,`区切り）/ `定休` / 空=不明。**分かる場合のみ**（これがあると🟢営業中バッジが出る）。深夜跨ぎ（22:00-2:00）は入れずに hours_text へ |
| holiday_note | 定休日メモ（例: 不定休・月曜休） |
| phone | 電話番号 |
| link_website / link_instagram / link_x / link_tabelog | 公式リンク。Instagram は `@ハンドル` だけでOK |
| description | 店の一言紹介（**自分の言葉で**。例: 運河沿いのベーカリーカフェ） |
| info_verified | 基本情報（営業時間等）を確認した日 `YYYY-MM-DD` |

### ⚪ 任意
reservation（予約情報）/ insta_note＋insta_note_date（公式SNSで確認した特記事項＋確認日。**メモを書いたら日付必須**）/ place_id / contact / is_closed

## 5. 出典の書き方（`data/master/sources.csv`・1行=1出典）

| 列 | 値 |
|---|---|
| cafe_id | cafes.csv の id（**id を空欄自動採番にした場合は、自分で UUID を振って両方に書く方が楽**。例: `beef0000-0000-4000-8000-000000000006` 形式で連番） |
| type | `official_hp` / `sns` / `google_map` / `tabelog` / `blog` / `other` |
| reference | 出典ページのURL |
| claimed_status | その出典が示す可否: `allowed`（明記で可）/ `conditional`（条件付き）/ `not_allowed`（不可）/ `unverified`（記載曖昧） |
| claimed_condition | conditional のとき**必須**（例: テラス席のみ犬同伴可） |
| verified_at | あなたが閲覧した日 `YYYY-MM-DD`（unverified 以外は必須） |
| provenance | **`aggregated` 固定**（§3-3） |

**探す優先順位**: ① 公式HP（「ペット」「犬」「ドッグ」でページ内検索）→ ② 公式 Instagram/X（プロフィールや固定投稿）→ ③ 犬お出かけ専門サイト（gowithdog・ワンコnowa・いぬときどきカフェ等）→ ④ 食べログ（こだわり条件「ペット可」）/ Googleマップの属性 → ⑤ 個人ブログ（新しいものだけ・日付確認）。
複数見つかったら**複数行**書く（公式＋専門サイトの2出典が理想）。

## 6. 作業手順（1エリアごと）

```bash
# 0) 前提確認（リポジトリルートで）
python3 tools/export_cafes.py --check     # 現状が検証OKであること

# 1) Web調査 → data/master/cafes.csv と sources.csv に追記
#    （既存行は変更しない。追記のみ。エンコーディングはUTF-8のまま）

# 2) 検証（エラーが出たら修正して再実行）
python3 tools/export_cafes.py --check

# 3) 検証が通ったら本出力（差分がCHANGELOGに記録される）
python3 tools/export_cafes.py

# 4) progress.md の担当エリア行を更新（状態・件数）
# 5) 報告（§8）。git commit はしない
```

**よくある検証エラー**: conditional なのに claimed_condition が空／unverified 以外なのに verified_at が空／同名の店が50m以内に2行（重複→統合）／時刻形式（`9:00-18:00` 形式・開店<閉店）。

## 7. 1店舗のチェックリスト

- [ ] 犬同伴可否の**明記**を出典で確認した（推測していない）
- [ ] sources.csv に 出典URL・claimed_status・閲覧日・aggregated を書いた
- [ ] 座標を Googleマップで確認した（±50m 精度目安）
- [ ] 店内/テラス/大型犬/サイズ制限を出典の記載どおりに記入（無い項目は空欄）
- [ ] 営業時間・定休日と info_verified を記入（分かる範囲で）
- [ ] description は自分の言葉で1文（コピペしない）
- [ ] 閉店していないか確認（閉店情報があれば is_closed=true＋出典）

## 8. 完了報告フォーマット

```
## 調査報告: <エリア名>（YYYY-MM-DD）
- 追加: N件（うち 店内OK: n / テラスのみ: n / 未確認: n）
- 出典内訳: 公式HP n / 専門サイト n / 食べログ n / その他 n
- 検証: --check 通過（エラー0）／CHANGELOG 差分: 追加N
- 判断に迷った店・要運営確認: <店名と理由>
- 見つけたが登録しなかった店: <店名と理由（明記なし等）>
```

## 9. 参照ファイル

| ファイル | 内容 |
|---|---|
| `data/master/cafes.csv` / `sources.csv` | **記入先**（天王洲5件が記入例） |
| `research-agent/progress.md` | エリア分担・進捗表（担当行を更新する） |
| `tools/README.md` | 列仕様の詳細・データ運用フロー |
| `.specify/memory/constitution.md` | プロジェクト憲章（原則I=データ信頼性が最上位） |
| `specs/001-dog-cafe-map/spec.md` / `specs/002-cafe-rich-info/spec.md` | 何を作っているかの仕様 |
| `CLAUDE.md` | プロジェクト全体の技術方針 |
