# 🤝 引き継ぎドキュメント — Puppy With Cafe

> **別PC・別AIセッションへの引き継ぎ用**。このファイルとリポジトリを渡せば作業を継続できる。
> 最終更新: 2026-10-07 / 状態: **MVP実装完了・データ配信本稼働・594件到達・データ品質改善（ギャップ補完）フェーズ**
> （PR #17「表示テキストの調査メモ除去と閉店・陳腐化是正」は**レビュー中**＝未マージの可能性あり。`gh pr list` で確認）

## 0. まず読む順番（新しいAIへ）

1. **このファイル（HANDOFF.md）** — 現状と次の作業
2. `CLAUDE.md` — 技術方針・重要な設計判断のサマリ
3. `.specify/memory/constitution.md` — プロジェクト憲章（**原則I=データ信頼性が最上位・絶対**）
4. `README.md` — プロジェクト概要
5. 作業内容に応じて `specs/001-dog-cafe-map/` `specs/002-cafe-rich-info/`（仕様）、`research-agent/README.md`（データ収集）

## 1. これは何か・どうなりたいか

- **Puppy With Cafe**（コードネーム DokoWanCafe）: 愛犬と入れるカフェを現在地から地図で探す iOS アプリ。
- 生命線は**データの信頼性**: 全情報に「出典URL・確認日・由来」を付け、**推測で『犬OK』と書くことを禁止**（憲章 原則I）。既存の類似手段（散乱・不正確・AIの誤答）を解決するのが存在意義。
- ゴール: 東京の犬同伴可カフェを網羅 → App Store リリース → エリア拡大。

## 2. いま完成しているもの（コード面はほぼ完了）

- ✅ iOSアプリ全機能: 地図(MKMapView橋渡し+クラスタ)・一覧・詳細・可否4値・出典/確認日/矛盾/AI区別・営業時間(営業中バッジ)・犬設備・電話/リンク・オフライン・a11y・日本語ファースト・**アプリアイコン**
- ✅ 2026-07〜10 の追加機能（PR #2/#4/#9/#13）: IG投稿埋め込み・OGP写真プレビュー、Google Maps流UI（下部シート2段）、住所・**駅名検索**、経路選択、お気に入り画面（遷移修正済み）、参考記事カード、詳細画面の再構成、営業時間の**日跨ぎ対応**、「大型犬OK」フィルタ
- ✅ データ基盤（サーバーレス構成B）: `data/master/*.csv` → `tools/export_cafes.py`（検証・矛盾解決・差分CHANGELOG）→ `data/cafes.json`
- ✅ **データ配信 本稼働**: GitHub Pages で `cafes.json` を配信。アプリが起動時に取得（アプリ審査なしで更新反映）
- ✅ テスト: 2026-10-17 に XCTest 156件 全緑（Xcode 26.6、iPhone 17 シミュレータ）。`.xcodeproj` は `DokoWanCafe/` 配下。
- ⚠️ 残課題: `StaticCafeRepository.swift` の NSLock 警告10件（Swift 6 言語モードでエラー化する）
- ✅ 公開物: リポジトリ(public)・README・プライバシーポリシー

### 環境・URL
- リポジトリ: https://github.com/changch223/puppy-with-cafe （public / GitHubアカウント: changch223）
- データ配信: https://changch223.github.io/puppy-with-cafe/data/cafes.json
- プライバシーポリシー: https://changch223.github.io/puppy-with-cafe/docs/privacy.html
- Bundle ID: `com.dokowancafe.app` / 表示名: Puppy With Cafe / 最小iOS: 16
- 現在の実データ（`data/master/cafes.csv` / `sources.csv`、origin/main を 2026-10-07 に再集計）:
  - **594件**（すべて東京都内・`sub_area` 83種）、出典 **1355件**
  - 大型犬可否 `dog_large` 記入済み **257件**（true 229 / false 28、空欄 337）
  - 曜日別営業時間（構造化）**405件**（D-1 で330件追加）。`hours_text` のみ116件、営業時間情報なし73件
  - Instagram 代表投稿URL 135件、リンク皆無 138件
  - **座標**: 2026-10-17 に abr-geocoder（デジタル庁ABR）＋国土地理院住所検索でも同じ点を確認（同系統データのため独立検証ではない）して住所と突き合わせ、一致した167件を住所由来の座標に更新（台帳の内訳: fix 169＝abr_geocoder 167＋住所修正2、keep 274、manual 40、町字止まり keep_coarse 92）。続けて同日、manual 40店のうち38店を食べログ等の**店舗ページのピン2出典**で照合して更新（method=shop_pin、fix 計207・manual 残り2。採否ルールは `tools/README.md`）。住所修正2店は CHUM APARTMENT（移転、公式サイトで目黒本町4-12-17）と Le Calin（番地訂正 2-1-6→2-2-43、複数出典で確認）（出典台帳 `data/master/coord_sources.csv`）。更新しなかった店は `legacy_estimate`（照合で許容内・または manual/keep_coarse）。GPS実測ではない

## 3. 別PCでの環境セットアップ（新PCで最初にやること）

```bash
# 1) クローン
git clone https://github.com/changch223/puppy-with-cafe.git
cd puppy-with-cafe

# 2) 必要ツール
#    - Xcode 26+（iOS 16+ シミュレータ）
#    - Python 3（標準ライブラリのみ。追加パッケージ不要）
#    - gh CLI（push用。`gh auth login` で changch223 アカウントにログイン）

# 3) ビルド & テスト（全件緑を確認）
cd DokoWanCafe
xcodebuild test -project DokoWanCafe.xcodeproj -scheme DokoWanCafe \
  -destination 'platform=iOS Simulator,name=iPhone 17'
cd ..

# 4) データ検証（現状OKを確認）
python3 tools/export_cafes.py --check
```
- 外部パッケージ依存ゼロ・シークレット無し（そのままクローンで動く）。
- アプリはバックエンド無しで動く（バンドルJSON＋Pages配信）。

## 4. 次にやる作業（優先度順）

### 🔴 A. データ品質の残課題（調査エージェント `.claude/agents/cafe-researcher.md`、sonnet 固定）
- **進め方・ルール**: `research-agent/gap-handover-2026-08.md`（バッチ別の対象・記入列・2026-10 追加ルール・D-1 変換ルール）と `research-agent/README.md`（絶対ルール）。他AIツールならこれをそのまま渡す。
- **D-2**: 営業時間情報が全く無い73件を公式/食べログ/Google で Web 調査し `hours_text`（＋可能なら曜日別構造化）を埋める。
- **PR #17 のマージ判断**（運営）: 表示テキストの調査メモ除去・閉店/陳腐化データの是正。レビュー中。
- **個別の確認事項**: Snow Peak Cafe の店内可否は**電話確認**／Aoi Coffee Stand の営業実態は**現地確認**。
- **dog_large 空欄（337件）**: 収穫率が約13%と低いため**保留**（費用対効果で再開を判断）。
- **座標の残課題**: abr-geocoder + GSI で突き合わせ済み（`tools/README.md` の「座標の突き合わせ」）。`coord_sources.csv` の `decision` が `keep_coarse`（町字止まり）・`manual`（残り2店）の店は、必要なら Google Maps 等で手動確認。
  - **manual の残り2店（2026-10-17 時点・店舗ピン2出典で解消できなかった分）**: ERIC ROSE（食べログとぐるなびが約151m不一致・旧座標から最寄りピンまで約680m）／パークス光が丘（食べログとホットペッパーが約344m不一致・公園内で旧座標の近く約144m）。いずれも実座標を Google Maps 等で確認して `cafes.csv` を更新し、`coord_sources.csv` も合わせる。残り40→2店の大半は店舗ページのピン2出典（method=shop_pin）で更新済み。
- **鉄則**: 推測禁止／出典URL+確認日必須／provenance=`aggregated`固定／矛盾は両方記録／**エージェントはcommitしない**（運営がdiffレビューして反映＝承認）。
- 新規エリア・店の追加（wave）は随時。リリースは全網羅を待たなくてよい。

### 🔴 B. App Store 提出手続き（ユーザー=changch223 本人の作業）
- **進捗: 未確認**（本ドキュメント更新時点でリポジトリ上に記録なし。着手状況は本人に確認すること）。
1. **Apple Developer Program 加入**（$99/年・審査1-2日）
2. App Store Connect でアプリ登録（Bundle ID `com.dokowancafe.app` / 名前「Puppy With Cafe」の空き確認）
3. ストア素材（スクショ・説明文・キーワード）→ 下書き: `docs/appstore/store-listing.md`
4. App Privacy 申告 → **「データを収集していません」**（方針・根拠は `docs/appstore/app-privacy.md`。現在地は端末内のみで処理し送信・保存しない）
5. Xcode で Archive → アップロード → 審査提出（審査メモ: `docs/appstore/review-notes.md`、全手順: `docs/appstore/submission-checklist.md`）

**App Store 準備の現状（ブランチ `feat/appstore-readiness`）**
- アプリ側で対応済み: 誤り報告フォーム未設定時は報告ボタンを非表示（「準備中」画面に到達しない）／「このアプリについて」画面（地図画面右上「…」メニュー内。バージョン・プライバシーポリシー・サポート・出典クレジット）／`PrivacyInfo.xcprivacy` を収集なしに是正／Instagram 埋め込みの WebView を非永続化／キャッシュに距離を保存しない／リモート取得のタイムアウト15秒＋失敗後5分は再取得しない／`MARKETING_VERSION=1.0.0`・`ITSAppUsesNonExemptEncryption=NO`／日本語のみ（`ja.lproj` 生成・`en` 廃止）。
- 公開ページ・ストア文面は `docs/`（`privacy.html` / `support.html` / `appstore/`）に作成済み。
- **残りはユーザー作業**: Apple Developer 加入・App Store Connect 登録、Google フォーム作成（下記 C）と URL 差し替え、スクリーンショット撮影、App Privacy 入力、Archive・提出。

### 🟡 C. Google フォーム作成（T071・ユーザー作業）
- 誤り報告の受付。**フォームは未作成**（CLAUDE.md にも未作成と明記）。手順書: `docs/appstore/google-form-setup.md`、全体の流れ: `docs/appstore/submission-checklist.md`（`tools/README.md` 手順2 も参照）。
- 作成後、プリフィルURL（https）を `AppEnvironment.defaultReportFormTemplate`（`DokoWanCafe/DokoWanCafe/App/AppConfig.swift`）に設定。**未設定の間は店詳細の「情報の誤りを報告」ボタン自体が表示されない**（アプリは壊れない）。ただしストア説明文・support.html・privacy.html・審査メモはフォームがある前提なので、**App Store 提出前に設定必須**（`docs/appstore/submission-checklist.md` の最終ゲート。docs の `{{FORM_URL}}` 差し替えも同時に）。

### ⚪ D. v2候補（リリース後）
AIスクリーニング（設計済: `supabase/functions/ai-screen/`）・エリア拡大・営業中/設備フィルタの拡充。

## 5. データ更新の作業フロー（誰がやっても同じ）

```bash
# 1) data/master/cafes.csv / sources.csv を編集（列仕様: tools/README.md）
# 2) 検証（エラーなく通るまで直す）
python3 tools/export_cafes.py --check
# 3) 本出力（cafes.json 生成＋アプリへコピー＋差分をCHANGELOGに記録）
python3 tools/export_cafes.py
# 4) レビュー & 反映
git add -A && git commit -m "data: <エリア> N件追加" && git push
#   → main へのマージ（push）で GitHub Pages が更新され、全ユーザーのアプリに反映（審査不要）
```
- **これがこのプロジェクトの心臓**。CSV → 検証 → JSON → マージ（＝配信）。

### 大量バッチの運用（2026-08〜10 の実績。cc-crew で回す）
1. **scope-planner / architect** でバッチの対象・ルールを確定（`research-agent/gap-handover-2026-08.md` を更新）。
2. **調査は CSV に直接書かず、JSON で納品**する（10〜15件/エージェントで並列可。並列でのCSV書き込みは禁止）。
3. **反映は1体（builder）に集約**して `cafes.csv` / `sources.csv` に書き込み、`export_cafes.py --check` で 0エラーを確認。
4. **qa-reviewer（builder とは別体）が原文突き合わせ QA**（出典URL・条件の要約・調査メモの混入など）。FAIL は builder に戻す。
5. **PR を作成**（shipper）。**運営がレビューしてマージ ＝ 承認 ＝ Pages 配信**。調査エージェント・builder は main へ直接 push しない。
- **座標の突き合わせ（abr-geocoder + GSI）**: `tools/geocheck_coords.py report` → `gsi` → `report --gsi-json` → `apply [--write]` → `export_cafes.py --check`。abrg は **Node 22 必須・`-c` に東京都62市区町村を個別指定・`-t 1`**（詳細は `tools/README.md`）。出典台帳は `data/master/coord_sources.csv`。地番由来の座標は使わない。
- **営業時間の構造化（バッチD）**は**二重独立変換**: 同じ原文を2担当が独立に変換し、**7曜日が完全一致かつ1曜日以上が非空の店だけ採用**。不一致は不採用として一覧化。一致後も原文（`hours_text` / `holiday_note`）との突き合わせ QA を必須とする。変換ルールは `gap-handover-2026-08.md` のバッチD参照。
- 新規出典が**代表可否（allowed/conditional 等）を動かす**場合は、運営レビュー対象として報告に明記する。

## 6. 未決事項（判断が要る・保留中）
- **T056**: 外部データAPI（住所/座標の補助集約）の採否 — 規約/コスト/法務の判断。MVPのブロッカーではない（手動で成立）。
- **初期データの取り方**: 6000件規模を効率よく集める方法は継続検討（現状は 594件。調査エージェント＋cc-crew 運用で積み上げ）。

## 7. 触るときの注意（落とし穴）
- **憲章 原則I は絶対**: 「推測で犬OK」「出典/確認日なしの確定情報」を作らない。これを破るデータはエクスポート検証が拒否する設計。
- Xcode プロジェクトは `FileSystemSynchronizedRootGroup` 方式。`DokoWanCafe/DokoWanCafe/` 以下にファイルを置けば自動でターゲットに入る（pbxproj 手編集ほぼ不要）。
- テストは凍結フィクスチャ（`DokoWanCafeTests/Fixtures/cafes.json`）を使う。アプリ本体の `Resources/cafes.json`（実データ）とは別物。
- 旧A案（Supabase）の `supabase/` `Services/Supabase*` `AuthService` 等は**保管**。v1では未使用（規模拡大時の移行先）。research.md R11 参照。
- コミットは `Co-Authored-By` 行付き。データ収集エージェントは**コミットしない**。

## 8. ファイル地図（どこに何があるか）
| パス | 役割 |
|---|---|
| `DokoWanCafe/` | Xcode プロジェクト（アプリ本体・テスト） |
| `data/master/*.csv` | **データの正本**（ここを編集） |
| `data/cafes.json` / `CHANGELOG.md` | 生成物・変更履歴 |
| `tools/export_cafes.py` / `README.md` | 変換スクリプト・列仕様 |
| `research-agent/` | データ収集ブリーフ・進捗表・ギャップ補完ハンドオーバー（`gap-handover-2026-08.md`） |
| `.claude/agents/cafe-researcher.md` | 調査エージェント定義 |
| `specs/001-*` `specs/002-*` | 仕様・設計・タスク |
| `docs/privacy.html` | プライバシーポリシー（Pages公開） |
| `supabase/` | 旧A案（保管・未使用） |
