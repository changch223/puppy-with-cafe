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
- ⚠️ 残課題（**この PR で対応**）: `StaticCafeRepository.swift` の NSLock 警告10件（Swift 6 言語モードでエラー化する）／初回読み込みが最大15秒（リモート取得のタイムアウト待ちが初回表示を遅らせる）
- ✅ 公開物: リポジトリ(public)・README・プライバシーポリシー

### 環境・URL
- リポジトリ: https://github.com/changch223/puppy-with-cafe （public / GitHubアカウント: changch223）
- データ配信: https://changch223.github.io/puppy-with-cafe/data/cafes.json
- プライバシーポリシー: https://changch223.github.io/puppy-with-cafe/docs/privacy.html
- Bundle ID: `com.dokowancafe.app` / 表示名: Puppy With Cafe / 最小iOS: 16
- 現在の実データ（`data/master/cafes.csv` / `sources.csv`。件数は 2026-10-07 に origin/main で再集計したもの、出典件数・曜日別営業時間・営業時間情報なしの件数は 2026-10-20 時点）:
  - **594件**（すべて東京都内・`sub_area` 83種）、出典 **1427件**
  - 大型犬可否 `dog_large` 記入済み **254件**（true 229 / false 25、空欄 340）
  - 曜日別営業時間（構造化）**463件**（D-1 で330件追加、バッチD-2・H で増加）。`hours_text` のみ118件、営業時間情報なし13件（うち9店は閉店・休業で非表示、表示中は4店）
  - Instagram 代表投稿URL 135件、リンク皆無 138件
  - **座標**: 2026-10-17 に abr-geocoder（デジタル庁ABR）＋国土地理院住所検索でも同じ点を確認（同系統データのため独立検証ではない）して住所と突き合わせ、一致した167件を住所由来の座標に更新（台帳の内訳: fix 169＝abr_geocoder 167＋住所修正2、keep 274、manual 40、町字止まり keep_coarse 92）。続けて同日、manual 40店のうち38店を食べログ等の**店舗ページのピン2出典**で照合して更新（method=shop_pin、fix 計207・manual 残り2。採否ルールは `tools/README.md`）。2026-10-18 に町字止まり keep_coarse 92店も店舗ピンで更新（83店＝2出典が100m以内、4店＝公式埋め込みとの食い違いは食べログ採用、5店＝単一出典で GSI 町丁目一致のみを根拠に採用〔method=shop_pin_single〕。全店を国土地理院の逆ジオコーダで町丁目照合済み。台帳の現在の内訳: fix 300＝abr_geocoder 167＋住所修正2＋shop_pin 126＋shop_pin_single 5、keep 274、manual 1、keep_coarse 0。2026-10-20 に ERIC ROSE を食べログのピンで更新）。住所修正2店は CHUM APARTMENT（移転、公式サイトで目黒本町4-12-17）と Le Calin（番地訂正 2-1-6→2-2-43、複数出典で確認）（出典台帳 `data/master/coord_sources.csv`）。更新しなかった店は `legacy_estimate`（照合で許容内・または manual/keep_coarse）。GPS実測ではない

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
- **D-2 / バッチH（2026-10-20）**: 営業時間情報が全く無かった73件は調査済みで、現在の「営業時間情報なし」は13件（うち9店は閉店・休業で非表示、表示中は Cafe' Roju・豊島屋・ふる浜売店・喫茶 ならの木の4店）。バッチH では曖昧表記（「要確認」「程度」等）の店を再調査して解消した。**バッチH で unresolved（出典不足・出典同士の食い違い）として現状維持にした店**（公式・店舗ページで確定できる情報が得られたら更新する）:
  - ミルリトンカフェ（…0264）: 食べログ（毎日11:30〜21:00）と犬情報サイト inunavi（平日〜19:00・土日祝〜21:00）が平日の閉店時刻で食い違い、公式に全営業時間の記載なし。
  - Le Calin（…0005）: 食べログ（11:00〜22:00・不定休）とホットペッパー（11:00〜18:00・定休なし）が食い違い、公式サイト・公式SNSなし。
  - ブリコラージュ ブレッド アンド カンパニー（…0182）: 公式は「季節によって変動」とのみで具体時刻なし（参考: 食べログ 火〜日7:00〜19:00・月曜定休）。
  - Cafe' Roju（…0625）: 公式に開店・閉店時刻の記載なし。公式サイトの営業日は月ごとのスケジュール（10月は金・土・日・月曜と隔週火曜）で週の定休として固定できないため holiday_note も空のまま。営業日は流動的で Instagram @caferoju1997 で告知。
  - Sammy331（…0960）: 現行の営業時間を文字で確認できず（プレオープン時の11:30〜17:00のまま。公式 Instagram のハイライト「10月営業時間」〔画像〕を目視で確認する必要あり）。
  - 豊島屋（…0964）: 公式・食べログ・ぐるなび等の店舗ページが見つからない（石神井公園案内所への問い合わせが確実）。
  - ふる浜売店（…1010）: 売店の営業時間の掲載なし（公園の開園時間は売店の営業時間ではない。公園管理事務所へ要確認）。
  - 喫茶 ならの木（…1168）: 公式サイト・SNS・グルメサイトに営業時間の掲載なし（電話確認が必要）。
  - まんまる庵（…1223）: 食べログの日曜が「11:09〜17:09」と不自然で確定できず（現状値は火曜11:00〜15:00・日曜11:00〜17:00）。
- **PR #17 のマージ判断**（運営）: 表示テキストの調査メモ除去・閉店/陳腐化データの是正。レビュー中。
- **個別の確認事項**: Snow Peak Cafe の店内可否は**電話確認**／Aoi Coffee Stand の営業実態は**現地確認**。
- **dog_large 空欄（340件）**: 収穫率が約13%と低いため**保留**（費用対効果で再開を判断）。
- **座標の残課題**: abr-geocoder + GSI で突き合わせ済み（`tools/README.md` の「座標の突き合わせ」）。`coord_sources.csv` の `decision` が `manual`（残り1店。keep_coarse は 2026-10-18 に全店解消）の店は、必要なら Google Maps 等で手動確認。
  - **manual の残り1店: パークス光が丘（…1262）**（2026-10-20 のバッチH再調査でも解消できず）。食べログ＝Yahoo!マップ＝エキテンの系統（35.76472, 139.62973）と、ホットペッパー＝rtrp の系統（35.76779, 139.62922。住所が「光が丘4-1 光が丘公園内」と公園全体の粒度）が約344m不一致。独立した第3の店舗ピンは得られず（Google 埋め込みは表示中心の値で place 座標とは言えない）。現行座標（35.76376, 139.62857）は食べログ系統から約149m。実座標を Google Maps 等で確認して `cafes.csv` を更新し、`coord_sources.csv` も合わせる。
  - **ERIC ROSE（…0087）は解消済み（2026-10-20）**: 食べログのピン（35.667827, 139.713483）を採用。食べログ・公式サイトの Google 埋め込み・さんたつの3本が22m以内で一致（ぐるなびのみ約151m外れ）、ゲートG（港区 北青山三丁目）通過。あわせて hours_text を公式（ericrose.jp）・食べログの「9:00〜19:00」に修正（旧値 8:00〜20:30）。残り40→1店の大半は店舗ページのピン2出典（method=shop_pin）で更新済み。
- **休業による一時非表示4店（再開を確認したら `is_closed=false` に戻す）**（2026-10-18・運営方針: 公式の休業告知が継続中で再開未確認の店は来店の空振り防止のため一時非表示。根拠は `sources.csv` に追記済み）:
  - わんすたCafe＆酒場（…0741）: 公式X 2024-02-07「2/29をもって休業」、再開確認なし — https://x.com/onestacafeskb
  - MILLS COFFEE（…0547）: 公式Instagramが「休業中」（9月中旬再開予定が未確認のまま） — https://www.instagram.com/millscoffeetokyo/
  - nakameguro SLOW TABLE（…0065）: 公式Instagram「5月10日〜休業 リニューアルまで」、再開告知なし — https://www.instagram.com/nakameguro_slow_table/
  - WANKOIWA DOG Caffe（…1291）: 公式サイト2026-04-11付「しばらくの間、休業」、再開告知なし — https://www.wankoiwa-caffe.com/299/
- **閉店による非表示（2026-10-18）**: AINA CAFE（…0626）— 公式サイトのお知らせ https://ainacafe.com/daytime/news/news20261003.html（2026.10.03付）の「2026年10月20日（火）をもちまして閉店」を根拠に is_closed=true。**閉店日（10/20）より前に、リリース作業をまとめるため非表示にした**（閉店予定日の前倒し。再開の見込みはない）。
- **evergreen EBISU（…0104）は非表示にした（2026-10-20・is_closed=true）**: 掲載していた店（犬同伴の条件・営業時間とも旧店のもの）は ぐるなびの店舗お知らせ（https://r.gnavi.co.jp/gj8a300/）で「最終営業日 8/30・リニューアル OPEN 今秋予定」として営業を休止（食べログも「リニューアルの為営業を一時休止」）。公式サイト evergreen-pet.com は「当サイトは閉鎖いたしました」のみ（cafes.csv の link_website は空。sources.csv の過去の official_hp 行は根拠として残置）、公式 Instagram @evergreen_cafe_ebisu のプロフィールは「NEW OPEN！ スープ生パスタ専門店」に変わっているが、新業態の住所・営業時間・**犬を連れての入店可否**が公式で未確認のため、旧店の犬同伴情報を新店に当てはめられない（原則I）。公式 Instagram は同じブランド名で「愛犬も一緒に楽しめるペット用パスタ」をうたっているため、リニューアル後の住所・営業時間・犬を連れての入店可否が公式で確認できたら、早めに再掲載（is_closed=false と内容更新）を検討する。
  - 参考（変更なし）: Cafe' Roju は営業継続（8月の臨時休業のみ。2026-10-10 に営業再開）、SHAPLA-INDIA（…0884）は閉店報道（2021-03-27付の記事で同日閉店予定と報道）と食べログの掲載保留表示のみで、公式の閉店告知・食べログの閉店表示がないため表示継続・保留。
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
- **残りはユーザー作業**: Apple Developer 加入・App Store Connect 登録、スクリーンショット撮影、App Privacy 入力、Archive・提出。

### 🟡 C. Google フォーム作成（T071・後日。v1.0 はフォームなしで提出）
- **v1.0 はフォームなしで App Store に提出する**。問い合わせ・誤り報告の窓口は GitHub Issues（https://github.com/changch223/puppy-with-cafe/issues）で、`docs/privacy.html` / `docs/support.html` に記載済み（GitHub アカウントが必要・内容は公開される旨も明記）。アプリ内の「情報の誤りを報告」ボタンは `AppEnvironment.defaultReportFormTemplate` が `nil` の間は自動で非表示。審査メモ・ストア文面もフォームなし前提に修正済み（`docs/appstore/`）。
- フォームは**未作成**。後日導入する場合の手順書: `docs/appstore/google-form-setup.md`（`tools/README.md` 手順2 も参照）。導入時は、プリフィルURL（https）を `AppEnvironment.defaultReportFormTemplate`（`DokoWanCafe/DokoWanCafe/App/AppConfig.swift`）に設定し、docs の GitHub Issues 記載をフォームへ更新、審査メモも更新して新版として出す。

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
