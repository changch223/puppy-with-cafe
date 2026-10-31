# 🤝 引き継ぎドキュメント — Puppy With Cafe

> **別PC・別AIセッションへの引き継ぎ用**。このファイルとリポジトリを渡せば作業を継続できる。
> 最終更新: 2026-10-31 / 状態: **MVP実装完了・画面の再設計（段階1〜4）完了・データ配信本稼働・693件到達・データ品質改善（ギャップ補完）フェーズ・App Store 提出準備**

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

- ✅ iOSアプリ全機能: 地図(MKMapView橋渡し・形と色のピン)・3段の一覧シート・詳細（答えのカード）・可否4値・出典/確認日/矛盾/AI区別・営業時間(営業中の判定)・犬設備・電話/リンク・オフライン・a11y・日本語ファースト・**アプリアイコン**
- ✅ 2026-07〜10 の追加機能（PR #2/#4/#9/#13）: IG投稿埋め込み・OGP写真プレビュー、住所・**駅名検索**、経路選択、参考記事カード、営業時間の**日跨ぎ対応**、「大型犬OK」フィルタ
- ✅ **画面の再設計（段階1〜4・2026-10-24〜26・PR #31/#33/#34/#35＋段階4）**: 「うちの子と、今、入れる？」に3タップで答える構成に作り直した（再設計案は利用者承認済み）。下のタブ3つ（さがす／保存／うちの子）・検索バー＋条件チップ（いつ行く？・うちの子OK・営業中・店内OK・テラス・大型犬OK・犬メニュー）・3段の一覧シート（見出しだけ／半分／ほぼ全画面）・ピンのカード・詳細の答えのカード（根拠の1行→根拠のシート）・「いつ行く？」（日時で絞る）・「行きたい／行った」（旧お気に入り）・「うちの子」（犬の大きさ・過ごし方の設定と入れるかの判定）。段階4（提出前の仕上げ）で積み残しの解消・未使用コードの削除・文字列カタログの同期・ライト/ダーク×最大文字サイズの通し確認・提出資料の更新を行った。画面構成と主要ファイルは §2.5。
- ✅ データ基盤（サーバーレス構成B）: `data/master/*.csv` → `tools/export_cafes.py`（検証・矛盾解決・差分CHANGELOG）→ `data/cafes.json`
- ✅ **データ配信 本稼働**: GitHub Pages で `cafes.json` を配信。アプリが起動時に取得（アプリ審査なしで更新反映）
- ✅ テスト: 2026-10-26（再設計 段階4）に XCTest 434件 全緑（Xcode 26、iPhone 17 シミュレータ）、ビルド警告なし。最小 iOS は 17。`.xcodeproj` は `DokoWanCafe/` 配下。
- ✅ 公開物: リポジトリ(public)・README・プライバシーポリシー

### 2.5 画面構成と主要ファイル（再設計 段階1〜4 完了時点）

アプリは下の3タブ（`App/RootView.swift`）。さがす・保存の両方から店の詳細へ進める（タブごとに NavigationStack）。純ロジックは `Core/` に隔離して XCTest で検証する（憲章 原則IV）。

| 画面 | 主要ファイル | 役割 |
|---|---|---|
| **さがす**タブ | `Features/Map/SearchTabView.swift`・`SearchTopBar.swift`（`HomeSearchBar`・`FilterChipsView`）・`MapView.swift`（`CafeMapView`）・`MapPinRenderer.swift`・`CafeBottomSheet.swift`（3段シート）・`PlaceCardView.swift`（ピンのカード）・`Features/CafeList/CafeSearchView.swift`（検索画面）・`SearchStateView.swift`（読み込み中・圏外・位置情報なし・エラー）・`CafeListView.swift`（`CafeRowView`＝一覧の行） | 地図を常時ベースに、検索バー・条件チップ・3段の一覧シート。ピンを選ぶとシートの中身が店のカードに変わる |
| **いつ行く？** | `Features/Map/PlanTimeSheet.swift`・`Core/TargetTime.swift`・`Features/Common/TargetTimeEnvironment.swift` | 日（今・今日・明日・その先の曜日）と時刻を選ぶと、その時刻に営業中の店だけを表示。対象時刻は保存しない。詳細の「今日」タイルも対象時刻を反映する |
| **店の詳細** | `Features/CafeDetail/CafeDetailView.swift`・`CafeDetailComponents.swift`（答えのカード・要点タイル・根拠のシート）・`CafeDetailMyDogLine.swift`・`Core/CafeDetailAnswer.swift`（答えと根拠の1行）・`Core/CafeDetailSummary.swift`（要点タイル・曜日表・わんちゃん向け情報・共有文） | 先頭に答え（「店内で一緒に過ごせます」等）と根拠の1行。根拠をタップすると参考記事・食い違いの説明（`CafeDetailEvidenceSheet`） |
| **保存**タブ | `Features/Saved/SavedView.swift`・`Services/SavedPlacesStore.swift`・`Core/SavedPlaces.swift` | 「行きたい」（追加が新しい順）／「行った」（行った日が新しい順）。端末内のみ（UserDefaults）。旧お気に入りは初回に「行きたい」へ移行 |
| **うちの子**タブ | `Features/About/MyDogView.swift`・`MyDogSetupSheet.swift`・`Services/DogProfileStore.swift`・`Core/DogProfile.swift`・`Core/DogFit.swift` | 犬の大きさ・過ごし方の設定（端末内のみ）、データ更新日・再読み込み、ピンの見かた、このアプリについて。`DogFit` が席（店内・テラス）ごとに「入れると明記／入れないと明記／分からない」を判定（推測で「うちの子OK」と言わない） |
| 共通 | `Core/CafePresentation.swift`（行・カードのタグ最大2つ・営業の行・VoiceOver 文）・`Core/SheetHeadline.swift`（見出し）・`Core/CafeFilter.swift`・`Features/CafeList/CafeListViewModel.swift`・`Features/Common/CafeRowParts.swift`・`DogProfileEnvironment.swift`・`BrandStyle.swift`・`Features/CafeList/RowStatusIcons.swift` | 地図・一覧・保存は同一の `CafeListViewModel`（`displayedResults`）を共有し、乖離させない（FR-003） |

- **初回の2問**（`RootView.presentOnboardingIfNeeded`）: データを表示できたあと、どのモーダル（検索画面・「いつ行く？」・共有シート・アプリ内ブラウザなど）も出ていないときに一度だけ「うちの子のことを教えてください」を出す。出せなかったら閉じるのを待って出し直す。
- **文字列**: 日本語の文字列リテラルがそのままキー。`Resources/Localizable.xcstrings` は段階4で現在のコードと同期済み（コードから消えた文字列は削除、新しい文字列は日本語＝キーで追加）。新しい文言を足したら Xcode でビルドして抽出・確認する（`SWIFT_EMIT_LOC_STRINGS=YES`）。
- **大きな文字サイズ**: 最大（accessibility-extra-extra-extra-large）まで拡大して確認済み。一覧の行・ピンのカード・操作ボタンは縦に積み、条件チップは最大まで拡大して横スクロールにする。**検索バー（地図の上の固定の帯）だけは xxxLarge で止める**（最大にすると帯が画面を占めるため）。「いつ行く？」の時刻選択は AX ではメニュー式、根拠のシート・「いつ行く？」シートは AX では全画面で開く。
- **提出資料**: `docs/appstore/`（`store-listing.md`・`screenshots.md`・`review-notes.md`・`submission-checklist.md`・`app-privacy.md`）。

### 環境・URL
- リポジトリ: https://github.com/changch223/puppy-with-cafe （public / GitHubアカウント: changch223）
- データ配信: https://changch223.github.io/puppy-with-cafe/data/cafes.json
- プライバシーポリシー: https://changch223.github.io/puppy-with-cafe/docs/privacy.html
- Bundle ID: `com.dokowancafe.app` / 表示名: Puppy With Cafe / 最小iOS: 17
- 現在の実データ（`data/master/cafes.csv` / `sources.csv`。件数は 2026-10-07 に origin/main で再集計したもの、曜日別営業時間・営業時間情報なしの件数は 2026-10-20 時点、出典件数・電話番号の件数は 2026-10-24 時点）:
  - **693件**（すべて東京都内・`sub_area` 83種。2026-10-24 に Communita Cafe、2026-10-30 にバッチR の16店とバッチS の40店、2026-10-31 にバッチT の42店を追加）、表示中 **660件**、出典 **1717件**（2026-10-31 時点。電話番号 `phone` 記入済み 557件、表示中の660店では 542件・空欄 118件）
  - 大型犬可否 `dog_large` 記入済み **257件**（true 232 / false 25、空欄 436）
  - 曜日別営業時間（構造化）**544件**（D-1 で330件追加、バッチD-2・H・R・S・T で増加）。`hours_text` のみ133件、営業時間情報なし16件（うち9店は閉店・休業で非表示、表示中は7店）
  - Instagram 代表投稿URL 135件、リンク皆無 138件
  - **座標**: 2026-10-17 に abr-geocoder（デジタル庁ABR）＋国土地理院住所検索でも同じ点を確認（同系統データのため独立検証ではない）して住所と突き合わせ、一致した167件を住所由来の座標に更新（台帳の内訳: fix 169＝abr_geocoder 167＋住所修正2、keep 274、manual 40、町字止まり keep_coarse 92）。続けて同日、manual 40店のうち38店を食べログ等の**店舗ページのピン2出典**で照合して更新（method=shop_pin、fix 計207・manual 残り2。採否ルールは `tools/README.md`）。2026-10-18 に町字止まり keep_coarse 92店も店舗ピンで更新（83店＝2出典が100m以内、4店＝公式埋め込みとの食い違いは食べログ採用、5店＝単一出典で GSI 町丁目一致のみを根拠に採用〔method=shop_pin_single〕。全店を国土地理院の逆ジオコーダで町丁目照合済み。台帳の現在の内訳: fix 300＝abr_geocoder 167＋住所修正2＋shop_pin 126＋shop_pin_single 5、keep 274、manual 1、keep_coarse 0。2026-10-20 に ERIC ROSE を食べログのピンで更新）。住所修正2店は CHUM APARTMENT（移転、公式サイトで目黒本町4-12-17）と Le Calin（番地訂正 2-1-6→2-2-43、複数出典で確認）（出典台帳 `data/master/coord_sources.csv`）。更新しなかった店は `legacy_estimate`（照合で許容内・または manual/keep_coarse）。GPS実測ではない

## 3. 別PCでの環境セットアップ（新PCで最初にやること）

```bash
# 1) クローン
git clone https://github.com/changch223/puppy-with-cafe.git
cd puppy-with-cafe

# 2) 必要ツール
#    - Xcode 26+（iOS 17+ シミュレータ）
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
- PR #17（表示テキストの調査メモ除去・閉店/陳腐化データの是正）は 2026-10-07 にマージ済み。
- **個別の確認事項**: Snow Peak Cafe の店内可否は**電話確認**／Aoi Coffee Stand の営業実態は**現地確認**。
- **dog_large 空欄（341件）**: 収穫率が約13%と低いため**保留**（費用対効果で再開を判断）。
- **座標の残課題**: abr-geocoder + GSI で突き合わせ済み（`tools/README.md` の「座標の突き合わせ」）。`coord_sources.csv` の `decision` が `manual` は 2026-10-24 に0店になった（keep_coarse は 2026-10-18 に全店解消）。台帳の内訳: fix 400（新規掲載の Communita Cafe と、2026-10-30 のバッチR の16店・バッチS の40店、2026-10-31 のバッチT の42店を含む）・keep 274・manual 0。
  - **パークス光が丘（…1262）は解消済み（2026-10-24）**: 運営が Google マップで売店（光が丘公園 売店）のピン（35.7647305, 139.6297057）を確認し、食べログのピン（35.764722, 139.629726）と2.1mで一致したため食べログを採用（method=shop_pin、ゲートG通過: 練馬区 光が丘四丁目）。旧座標から約149m移動。以下はバッチH時点の経緯: 食べログ＝Yahoo!マップ＝エキテンの系統（35.76472, 139.62973）と、ホットペッパー＝rtrp の系統（35.76779, 139.62922。住所が「光が丘4-1 光が丘公園内」と公園全体の粒度）が約344m不一致。独立した第3の店舗ピンは得られず（Google 埋め込みは表示中心の値で place 座標とは言えない）。現行座標（35.76376, 139.62857）は食べログ系統から約149m。
  - **ERIC ROSE（…0087）は解消済み（2026-10-20）**: 食べログのピン（35.667827, 139.713483）を採用。食べログ・公式サイトの Google 埋め込み・さんたつの3本が22m以内で一致（ぐるなびのみ約151m外れ）、ゲートG（港区 北青山三丁目）通過。あわせて hours_text を公式（ericrose.jp）・食べログの「9:00〜19:00」に修正（旧値 8:00〜20:30）。残り40→1店の大半は店舗ページのピン2出典（method=shop_pin）で更新済み。
- **休業による一時非表示4店（再開を確認したら `is_closed=false` に戻す）**（2026-10-18・運営方針: 公式の休業告知が継続中で再開未確認の店は来店の空振り防止のため一時非表示。根拠は `sources.csv` に追記済み）:
  - わんすたCafe＆酒場（…0741）: 公式X 2024-02-07「2/29をもって休業」、再開確認なし — https://x.com/onestacafeskb
  - MILLS COFFEE（…0547）: 公式Instagramが「休業中」（9月中旬再開予定が未確認のまま） — https://www.instagram.com/millscoffeetokyo/
  - nakameguro SLOW TABLE（…0065）: 公式Instagram「5月10日〜休業 リニューアルまで」、再開告知なし — https://www.instagram.com/nakameguro_slow_table/
  - WANKOIWA DOG Caffe（…1291）: 公式サイト2026-04-11付「しばらくの間、休業」、再開告知なし — https://www.wankoiwa-caffe.com/299/
- **閉店による非表示（2026-10-18）**: AINA CAFE（…0626）— 公式サイトのお知らせ https://ainacafe.com/daytime/news/news20261003.html（2026.10.03付）の「2026年10月20日（火）をもちまして閉店」を根拠に is_closed=true。**閉店日（10/20）より前に、リリース作業をまとめるため非表示にした**（閉店予定日の前倒し。再開の見込みはない）。
- **evergreen EBISU（…0104）は非表示にした（2026-10-20・is_closed=true）**: 掲載していた店（犬同伴の条件・営業時間とも旧店のもの）は ぐるなびの店舗お知らせ（https://r.gnavi.co.jp/gj8a300/）で「最終営業日 8/30・リニューアル OPEN 今秋予定」として営業を休止（食べログも「リニューアルの為営業を一時休止」）。公式サイト evergreen-pet.com は「当サイトは閉鎖いたしました」のみ（cafes.csv の link_website は空。sources.csv の過去の official_hp 行は根拠として残置）、公式 Instagram @evergreen_cafe_ebisu のプロフィールは「NEW OPEN！ スープ生パスタ専門店」に変わっているが、新業態の住所・営業時間・**犬を連れての入店可否**が公式で未確認のため、旧店の犬同伴情報を新店に当てはめられない（原則I）。公式 Instagram は同じブランド名で「愛犬も一緒に楽しめるペット用パスタ」をうたっているため、リニューアル後の住所・営業時間・犬を連れての入店可否が公式で確認できたら、早めに再掲載（is_closed=false と内容更新）を検討する。
  - 参考（変更なし）: Cafe' Roju は営業継続（8月の臨時休業のみ。2026-10-10 に営業再開）、SHAPLA-INDIA（…0884）は閉店報道（2021-03-27付の記事で同日閉店予定と報道）と食べログの掲載保留表示のみで、公式の閉店告知・食べログの閉店表示がないため表示継続・保留。
- **バッチI（電話番号・2026-10-24）**: 電話番号が空だった159店を調査し、**92店に `phone` を記入**（公式の番号 46店〔CAFE CHOU CHOU・Italian Dining Lui を含む〕／公式がなく独立した2サイトで一致 46店）。未解決67店は空欄のまま（うち4店は下記の理由で不採用）。出典は `sources.csv` に claimed_status=unverified・provenance=aggregated・verified_at=2026-10-24 で追記（犬の可否は確認していないため、既存行は unverified のものを除き日付を更新していない。ルール(b)の注記）。
  - **公式に 050 が明記されている店は公式の番号を採用**: RIDE 天王洲（…0003）・CLANN BY THE RIVER（…0126）・BESIDE SEASIDE（…0868）・Italian Kitchen VANSAN 大泉学園店（…0966）。
  - **予約用の転送番号は採用しない**: Italian Dining Lui（…0891）の公式ページ（Retty 提供の foodre.jp）は店の番号 03-6426-9486 と予約用 050-5262-1093 を分けて載せているため、店の番号 03-6426-9486（食べログ・るるぶとも一致）を採用。
  - **氷屋ぴぃす（…0045）は phone 空のまま**: Yahoo!マップ等に携帯番号があるが、食べログは「お問い合わせ 非公開」で予約は TableCheck 案内のため、店が電話を公開していないと判断。
  - **不採用（phone 空のまま）**: GRAPHY NEZU（…0306・公式に 050 が2つあり店の番号が不明）、YELLOW KOMAZAWA KOEN（…0647）・Pretty Things（…0648）・スパイスと創作料理 この一杯のために。（…0442）（2出典が転載関係とみられ独立とは言えない）。
  - **CAFE CHOU CHOU（…0827）を更新**: hours_text「11:00〜17:00(早めに閉店する場合あり)」・holiday_note「不定休(営業日はInstagramの投稿カレンダーで告知)」・曜日別は空・phone 042-673-3917（公式 lit.link）・link_instagram を公式 lit.link のリンク先 `cafe_chouchou.r` に修正。
  - **Vegeater（…0329）は変更なし**（営業中。臨時休業が多いが「不定休(営業日は公式ページで告知)」と矛盾しない。公式 Instagram の最終投稿は 2025-12-22 と古く、縮小営業の可能性あり）。
  - **非表示にした2店（`is_closed=true`）**: わいん＆野菜食堂 Cafeえにわん 新小岩（…1293）— 食べログが「移転前の店舗情報」と表示し、移転先「うたたねCafe えにわん」（鎌倉市雪ノ下5-4-3）が新小岩2-7-10からの移転を明記しており、東京都外への移転のため。Cyan coffee（…1096）— 公式 Instagram「2025.07.31〜 休業中」・食べログ掲載保留で、再開未確認（10/18 の運営方針と同じ。再開を確認したら `is_closed=false` に戻す）。
  - **閉店・店名変更の兆候があった5店の再確認（2026-10-24）**:
    - marble（蔵前・…0165）: 公式 Instagram のプロフィールに「2026年11月1日をもって閉店」、食べログ口コミにも同旨が多数 → **非表示**（閉店日の約1週間前。AINA CAFE と同じく前倒し）。都立大学の同名店（…1126）は別店で影響なし。
    - FITZROY（…0881）: 食べログが「休業期間未確定・移転閉店の事実確認できず」で掲載保留（最終編集 2021-10）、同じ住所（目黒2-11-3）に別店 Communita Cafe が 2023-01-18 から営業（食べログ） → **非表示**。Communita Cafe は食べログ備考に「ペット連れのお客様も店内ご利用いただけます」とあり、**新規掲載の候補**（別店として要調査）。
    - ピザとハイボール UN COEUR 東中野店（…1081）: 食べログ掲載保留、公式 Instagram の最新投稿 2018-11-04、それ以降の営業の根拠なし → **非表示**（再開・営業の根拠が見つかったら戻す）。
    - ヨガカフェ（…0465）: 同住所のヨガ・ピラティス教室は同じ運営会社（Always Laughing）の併設スタジオで、カフェは営業中。営業時間を公式（https://always-l.com/cafe/）の「平日10:00〜13:30・土日祝10:00〜15:00・火曜定休」に修正。
    - 九州酒場ささ（…0846・旧 さみしがりや酒房ささ）: 公式サイト sasa-gotanda.com と食べログで住所・電話が一致する同一店の店名変更 → 店名を「九州酒場ささ（旧 さみしがりや酒房ささ）」に、営業時間を「17:00〜24:00・日曜・祝日定休」に修正。犬同伴（外席のみ）は食べログ備考で継続。
    - **運営方針（2026-10-24 追加）**: 食べログが「掲載保留（休業期間未確定・閉店の事実確認できず）」で、かつ公式の発信が長期間（目安3年以上）途絶えている、または同じ住所で別の店が営業している店は、来店の空振り防止のため一時非表示にする。営業の根拠が見つかったら `is_closed=false` に戻す。
  - **据え置き（後続の確認対象）**: マイケルロック168 の住所表記（Instagram 1-14-11 と CSV・食べログ 1-4-11 の不一致）。
- **新規掲載: Communita Cafe（…1304・目黒2-11-3、2026-10-24）**: 同住所の旧店 FITZROY（非表示）とは別店。犬同伴は公式記事（Impact HUB Tokyo「店内はペットOK」）・公式 Instagram（@communita_cafe「ベビーカー/ペットOK」）・食べログ備考（「ペット連れのお客様も店内ご利用いただけます」）の3出典が一致（いずれも「ペット」表記で、犬種・サイズ・席の条件の記載なし）→ dog_indoor=true のみ記入。営業は水〜日11:00〜18:00・月曜定休（火曜はカフェ休みでカレーの間借り営業のみ）。座標は食べログの geo（HappyCow の Google マップと8m差・ゲートG通過: 目黒二丁目。台帳 coord_sources.csv に method=shop_pin で記録）。電話 03-6873-8531（食べログ・HappyCow・retro-kissa.tokyo で一致）。
- **バッチR（新規16店・2026-10-30）**: 人気エリアで未掲載だった犬同伴OKの店を試行調査し、16店を新規掲載した（id …1305〜…1320、`sub_area` は既存と同じ表記、`info_verified=2026-10-30`、座標は食べログ JSON-LD の単一出典で GSI 逆ジオコーダの町丁目一致を確認〔method=shop_pin_single・台帳に各店1行〕）。「公式あり」は公式サイト／公式 SNS で犬同伴を確認できた店、「食べログ（店舗会員公開）のみ」は犬同伴の根拠が店舗関係者が公開した食べログの記載だけの店。
  - 代官山: BISTRO FAVORI 代官山（公式あり・テラスのみ）、Mary Jane（食べログ店舗会員公開のみ・抱っこまたはキャリーで店内可、dog_size_max_indoor=small・dog_indoor_style=carrier|hold）、PRIM（食べログのみ・店内同伴可で条件記載なし）、COM DAIKANYAMA（食べログのみ・テラスのみ、店内は記載なしで dog_indoor 空）。
  - 中目黒: Mark Matsuoka Grill 中目黒（公式あり。公式は「ほぼ全席」なので conditional、条件文「店内・テラスのほぼ全席で同伴可（一部の席を除く）」。食べログは「全席」と記載）、NAKAMEGURO TERRACE（食べログのみ・テラス席）。
  - 吉祥寺: 牛たん うしすけ 吉祥寺店（店内のペット同伴用テーブル）、吉祥寺 井の頭テラス HONOO（テラス席のみ・1グループ2匹まで）、立飲ビストロ Ryo（テラス席）、肉Q（2階の掘りごたつ席のみ・事前連絡）、東京焼肉 黒乃 Beef up tokyo（ペットOKの個室）、北海道物産 吉祥寺（テラス席のみ）。いずれも食べログ（店舗会員公開）のみ。
  - 二子玉川: TOKIO フレンチ ルナティック（店内・テラスとも可）、Asian Cafe & Diner Vivid Ajia（テラス席のみ）、88 Asia（一部の席のみ・事前連絡。店内かテラスかの記載なしで dog_indoor/terrace は空。電話は公式サイトが「二子玉川店」の番号として掲載＝食べログと一致のため記入）、ALLO（テラス席）。いずれも食べログのみ。
  - **掲載しなかった店**: `candidate_weak` の Gelato 9.（二子玉川・食べログ備考のみ）とバビーズ 二子玉川（食べログ備考のみ）は掲載保留。`backlog`（犬の記載が食べログ備考のみで試行の上限により見送った店、例: テイストアンドセンス・ストリーマー・コーヒー・カンパニー 中目黒・トライアングルカフェ・アジアンビストロDai 二子玉川店・ELMO・東京ロア 吉祥寺店 など）は後続の候補。食べログが掲載保留の店（craft tea, coffee・Andy Cafe 二子玉川）と、食べログ備考で「テラスでも入店不可」と明記された CHICAMA は除外。
  - 構造化した営業時間の注意: NAKAMEGURO TERRACE（11:00-4:00）と HONOO（11:30-23:00）は定休日の記載がなく全曜日営業として入れている（結果どおり）。
- **バッチS（新規40店・2026-10-30）**: バッチR の続きで、人気エリアの未掲載の犬同伴OK店を調査し、40店を新規掲載した（id …1321〜…1360、`sub_area` は既存と同じ表記、`info_verified=2026-10-30`、座標は食べログ JSON-LD の単一出典で GSI 逆ジオコーダの町丁目一致を確認〔method=shop_pin_single・台帳に各店1行〕。Green Cafe 西郷山店だけは GSI が区境で鉢山町を返したが、食べログとホットペッパーのピンが約7mで一致のため method=shop_pin で採用）。「公式あり」は公式サイト／公式 SNS でも犬同伴を確認できた店、「食べログのみ」は根拠が店舗関係者公開の食べログの記載だけの店。
  - 代官山（5店）: Kuss代官山（公式あり・テラスのみ）、サリーヒルズ（公式あり・テラスのみ。貸切時は店内可）、Enso. 円相 代官山（公式あり・テラスのみ。電話は公式と食べログで食い違うため空）、ボンベイバザー（食べログのみ・店内可）、Green Cafe 西郷山店（食べログ＋ホットペッパー・テラス席。住所は目黒区青葉台だが `sub_area` は代官山）。
  - 中目黒（3店）: Arl Eee nakameguro（食べログのみ・店内可）、中目黒ひつじ 目黒川店（食べログのみ・全席可）、OVERWHELM 中目黒店（食べログのみ・全席可）。
  - 恵比寿・広尾（8店）: サンクスネイチャー 恵比寿店（食べログのみ・店内可。住所の町名どおり `sub_area` は恵比寿・広尾）、テトテ アパートメント（公式あり・店内もテラスも可）、WM 有無（食べログのみ・カートはテラス席）、恵比寿ビストロ 猫も杓子も（食べログのみ・テラス席）、mi:ne（食べログのみ・2階席。電話は運営会社の代表番号の可能性があるため空）、Baru Comodo（食べログのみ・テラスのみ）、Pebble Hiroo Terrace（食べログのみ・店内は小型犬のカゴ／バギー）、食酒場Nest広尾（食べログのみ・店内小型犬可）。
  - 表参道・青山（8店）: 南青山カフェ（食べログのみ・店内可・犬用メニューあり）、KOKKO KURKKU（食べログ＋TableCheck 予約ページ・カート／バッグで店内可）、& Yogurt 表参道店（公式あり・店内可）、NICE minamiaoyama（食べログのみ・店内可）、カフェレストラン フィガロ（食べログのみ・吠えない小型犬・席に限り）、南青山エッセンス・エル フォー ユー・アニヴェルセル カフェ 表参道（いずれも食べログのみ・テラス席）。
  - 自由が丘（8店）: DOG SIDE Lounge（公式あり・ドッグラウンジ）、mamocafe・MANDARINE BROTHERS 自由が丘（食べログのみ・店内可）、AMAZON POLPAS CAFE & MARKET 自由が丘（食べログのみ・店内は膝に乗る小型犬まで）、鶏バル 串サンロク（食べログのみ・店内は小型犬・テラスも可）、パンとエスプレッソと自由形 自由が丘店・カフェ ラ・ボエム 自由が丘・イル カンパネッロ（いずれも食べログのみ・テラスのみ）。
  - 三軒茶屋・下北沢（8店）: 3pmTOKYO（食べログのみ・大型犬もOK、`dog_large=true`・`dog_size_max_indoor=large`）、マジョレルカフェ（食べログのみ・店内可）、TIME, TIME, TIME.（食べログのみ・店内可）、MARY STAND（食べログのみ・場所の記載なし）、BURGERS TOKYO（食べログのみ・1階の店内席とテラス席）、meso（食べログのみ・席に限りあり・予約時に連絡）、RAINBOW CAFE＆WINE DINING 三軒茶屋（食べログのみ・1階席）、IL MARE AZZURRO（食べログのみ・「ペット（小型犬）入店可」。「のみ」の明記がないため大きさの上限は空）。
  - **ルール a で直した店**（結果の `claimed_status` と条件文をメインの方針で修正）: IL MARE AZZURRO は conditional → allowed（条件文なし。小型犬・2頭まで・衣類の条件は dog_note に残す）。AMAZON POLPAS・マジョレルカフェ・鶏バル 串サンロクは claimed_status は allowed のまま、大きさ・頭数・マナーだけの条件文を空にした（内容は dog_note に残る）。鶏バル 串サンロクは「小型犬OK」だけで「小型犬のみ」の明記がないため `dog_size_max_indoor` も空にした。
  - 構造化した営業時間の注意: 3pmTOKYO は `hours_text` に 17:00-23:00 と 23:00-4:00 が続けて書かれているため曜日列を 17:00-4:00 にまとめた。出典間で時間が食い違う・曜日の指定も定休日もない・不定休や日付告知などの店は、結果が空にした曜日を空のまま入れている（例: Arl Eee nakameguro・OVERWHELM 中目黒店・Pebble Hiroo Terrace・イル カンパネッロ・TIME, TIME, TIME.・MARY STAND の火曜）。
  - **掲載しなかった店**: 各結果の `candidate_weak`（紹介サイトのみ・公式／食べログで犬同伴を確認できず、計11店）と `excluded`（既存と同一・閉店・エリア外・犬不可など）。残りの候補は各 result の excluded / candidate_weak を参照（結果の原本はスクラッチパッド上の result-1〜3.json）。
- **バッチT（新規42店・2026-10-31）**: バッチR・S の続きで、人気エリアの未掲載の犬同伴OK店を調査し、42店を新規掲載した（id …1362〜…1406。QA 後に4店を見送ったため …1361・…1367・…1370・…1373 は欠番、`sub_area` は既存と同じ表記、`info_verified=2026-10-31`、座標は食べログ JSON-LD の単一出典で GSI 逆ジオコーダの町丁目一致を確認〔method=shop_pin_single・台帳に各店1行〕）。「公式あり」は公式サイト／公式ブログでも犬同伴を確認できた店、「食べログのみ」は根拠が店舗関係者公開の食べログの記載だけの店。
  - 代官山（1店）: 代官山 琴（食べログのみ・店内可。「テーブル席希望は電話」は席の制限ではないので allowed）。
  - 中目黒（4店）: The World Cafe 中目黒（食べログのみ・全席可）、F BULL'S Cafe（食べログのみ・店内可。犬用メニューあり `dog_menu=true`）・Kento's Burger（食べログのみ・店内可）、SLOWJAM GARAGE Singaporean cuisine（食べログのみ・店内可。電話は公式と食べログが一致）。
  - 恵比寿・広尾（1店）: milkygreek 恵比寿店（食べログのみ・店内可だが席に限りあり・電話予約。電話は転送番号のため空。犬用メニューあり `dog_menu=true`）。
  - 表参道・青山（1店）: BROOKS GREENLIT CAFE（公式あり・店内可）。
  - 自由が丘（2店）: better is・台湾 席茶 蓮月庭（いずれも食べログのみ・テラスのみ）。
  - 三軒茶屋・下北沢（3店）: cafe 明日も発酵ごはん nippon（食べログのみ・犬用メニューあり `dog_menu=true`、場所の記載なし）、LOOK UP COFFEE（食べログのみ・テラス席）、Nine9 Style hamburger&bar（食べログのみ・フロア可、場所の記載なし）。
  - 清澄白河・門前仲町（7店）: POSH（食べログのみ・テラス席。こだわり欄の「ペットOKのテラス席完備」を条件文に入れた。「のみ」の明記はないので dog_indoor は空）、est tokyo uno et001（公式あり・カート／バッグに入れて店内、予約時に電話。`dog_indoor_style=carrier`）、呑冨（NOMITOMI）（食べログのみ・店内可）、PARKSTAND Coffee & Bakery（公式あり・テラスのみ）、WINESTAND TEO（食べログのみ・「1階のみ」。店内かテラスかの明記がないため dog_indoor/terrace は空）、Bowery lane・RELAX Healthy Ice Cream（食べログのみ・テラスのみ）。
  - 浅草・蔵前（7店）: cacom（カコム）（公式あり・予約時に大きさ・頭数を連絡）、浅草 更科天狐（食べログのみ・店内可、混雑時は抱っこ `dog_indoor_style=hold`）、Café PA·TRI·CIAN（食べログのみ・入口付近の席に限る）、Bar B&W（食べログのみ・店内可）、浅草 たこ丸（食べログのみ・犬用たこ焼 `dog_menu=true`、場所の記載なし）、ORTIGA（オルティガ）（食べログのみ・「1階のみ」。dog_indoor/terrace は空）、友安製作所カフェ 浅草橋（食べログのみ・テラスのみ）。
  - 渋谷駅周辺（8店）: シーウルフダイナー（食べログのみ・店内もテラスも可。食べログに「定休日 なし」の明記があり `holiday_note=定休日なし`）、Tiki's Tokyo（食べログのみ・大型犬〔25kg以上〕はテラス席のみ・予約時に犬種と頭数を入力。`dog_large=true`・`dog_size_max_terrace=large`、conditional）、桜丘カフェ（食べログのみ・テラスのみ）、347CAFE＆LOUNGE（食べログのみ・テラス席の一部のみ・バギー／ペットバッグ必須）、attic room LOG（食べログのみ・全席可）、アティックルーム（食べログ備考＋ぐるなびの「店内OK」で `dog_indoor=true`。食べログに「定休日 なし」の明記があり `holiday_note=定休日なし`。大型犬OKはぐるなびのみなので `dog_large` は空）、cherry pick hills（食べログ＋ホットペッパー・店内はカバン等に入れて、テラスも可）、ココロゴトカフェ（食べログのみ・店内入口側のスペース。公式 FAQ は場所の限定がなく食い違うため公式行は入れていない）。
  - お台場・豊洲（8店）: ブルーボトルコーヒー 豊洲パークカフェ（公式ブログ2本・テラス席。店内は明記なしで空）、Ariake Miraie（公式あり・バッグ／カートで店内）、タールムビアンコ お台場店（食べログ・店内可。店舗側の PR 欄にも記載）、Seaside Café SOLARIS（食べログのみ・場所の記載なし）、DDSK サイゴン キッチン（食べログのみ・店内もテラスも可、席数に制限・店内はバギー／バッグ必須。犬用メニューあり `dog_menu=true`）、ベルギービール ベル・オーブ ららぽーと豊洲（食べログのみ・テラス席）、ロイヤルガーデンカフェ&タバーン 豊洲・ビストロ 石川亭 豊洲フォレシア店（いずれも食べログのみ・テラスのみ）。
  - **ルール a で直した店**: なし（結果の `claimed_status` と条件文はそのまま入れた）。
  - 構造化した営業時間の注意: 出典間で時間が食い違う・曜日の指定も定休日もない・日付告知などの店は、結果が空にした曜日を空のまま入れている（例: 浅草 更科天狐の火・水、Ariake Miraie の水〜日、cacom・POSH・タールムビアンコは営業時間なし）。
  - **掲載しなかった店**: 食べログの犬の記載が備考欄だけでユーザー編集が可能な状態の MONZ CAFE 門前仲町店とイエロ 蔵前店（YELLO）は見送り。同じ理由で、QA 後にルーコ・CAFE NEM・Esquisse Coffee・NeNRiN の4店も見送った（いったん掲載したが削除。食べログに「最近の編集者」が表示されユーザーが編集できる状態で、犬の記載が備考欄だけ。id …1361・…1367・…1370・…1373 は振り直さず欠番）。`candidate_weak`（PERFECT BEER KITCHEN 蔵前・カミナリカフェ 浅草・スターバックス コーヒー 木場イトーヨーカドー店・グランマーズジョルジュパークサイドアヴェニュー・エッグスンシングス ららぽーと豊洲店の5店）と `excluded`（既存と同一・閉店・犬不可など）も掲載しない。結果の原本はスクラッチパッド上の result-1〜3.json。
- **バッチK（「うちの子」用の3列・2026-10-24）**: `cafes.csv` の右端に `dog_size_max_indoor`（店内の大きさ上限 small/medium/large）・`dog_size_max_terrace`（テラスの上限）・`dog_indoor_style`（店内の過ごし方 floor/carrier/hold を `|` 区切り）を追加し、`export_cafes.py` が `dog_amenities` の `size_max_indoor`・`size_max_terrace`・`indoor_style` として出力・検証する（列仕様は `tools/README.md`、契約は `specs/001-dog-cafe-map/contracts/cafes-json-schema.md`）。**Web 調査なし**。既存の文章（dog_size_limit・dog_note・description・出典の条件文）から、2者（A・B）が互いの結果を見ずに独立して読み取り、**一致した値だけを採用**（不一致・明記なしは空のまま。閉店30店は空）。対象は表示中565店のうち、QA 後に値が残った233店。採用件数（QA 後の最終）: 店内の大きさ上限 large 84 / medium 10 / small 15（計109）、テラスの上限 large 97 / medium 9 / small 1（計107）、過ごし方 floor 27 / carrier 12 / floor|carrier 10 / carrier|hold 2 / floor|hold 3 / hold 1 / floor|carrier|hold 1（計56）。**A・B の不一致48項目（46店）は空のまま**。QA の指摘で、次の11項目を空にした: 注記と食い違う・「要確認」「未確認」「不明」と並ぶ large（マキネスティコーヒー 緑本店の店内、VERVE COFFEE ROASTERS 六本木店・CHICHICAFE・Bleue Blanche・Cafe Madu 青山店・君のハンバーグを食べたい渋谷店のテラス）、条件ではない「推奨」や体験談だけが根拠だった過ごし方（WHAT CAFE・JUICE BAR ROCKET）、可否が true でない側のサイズ（肉とワイン bonanza の店内、pepacafe FOREST・もんじゃ ことぶきやのテラス）。`export_cafes.py` は、サイズ上限は対応する可否（`dog_indoor`／`dog_terrace`）が true の行にだけ、また `is_closed=true` の行は3列とも空であることを検証する。`dog_indoor_style` は**網羅的な一覧ではない**（含まれていれば可、含まれないことは不可を意味しない）。アプリはまだ新しいキーを読まない（未対応のキーは無視されるため後方互換）。再設計の**段階3（うちの子）**で、犬のサイズ・過ごし方との照合に使う予定。`dog_large` との整合チェックは運営が行う。
- **バッチL（店内の同伴可否・2026-10-24）**: `dog_indoor` が空だった108店を、公式・食べログ・犬連れ紹介サイトの原文で再調査して反映（運営が個別に上書きした後の件数）。`dog_indoor` は **true 9 / false 26 / 不明のまま（空）73**（閉店の MOCMO は空）。同じ出典に書かれていたものを `dog_size_max_indoor` 3店（bonanza=small、PERFECT BEER KITCHEN 四ツ谷・マキネスティコーヒー 緑本店=large）・`dog_size_max_terrace` 2店（オルオルアイナ・マキネスティコーヒー 緑本店=large。CHICHICAFE・VERVE 六本木はバッチKと同じく既存の注記「大型犬は未確認」と並ぶため入れない）入れた（計4店）。`dog_indoor_style` は出典に明記がなく0店。**null 扱いにした4店**: Trattoria Monolito（「室内テラス席」は調査者の解釈）・Besties Tokyo（「店内」の明記なし）・Cafe Madu 青山（過去の出典がテラスのみとしており食い違いが解消していない）・NEWシクロCafe（公式HPの「ペット同伴: 不可」と食べログ・公式Instagramが食い違う）。西葛西3店（あばら大根・TAIZUSHI・やきとり家すみれ）のテラス側サイズは出典が2018年のブログのため入れていない。マキネスティコーヒー 緑本店は wanico の自店の欄（店内○・テラス・屋外○・小型/中型/大型○。椅子の上・床の上・カートは未確認）に従い、`dog_note` を「店内・テラスとも同伴可、小型〜大型犬OK（wanico）」に直し、`dog_terrace=true` にした（wanico の出典行は conditional→allowed、条件「店内・テラスとも同伴可（小型・中型・大型犬）」）。同ページの別店（周辺スポット）の「床の上OK・カート不要」は採用していない。オルオルアイナは wankonowa に「テラスのみワンコ同伴可能」の明記があり `dog_indoor=false`（既存の wankonowa 行を更新）。**MOCMO sandwiches（…0744）は非表示（`is_closed=true`）**: 食べログ備考に「2026年10月30日をもって閉店」の告知（https://tabelog.com/tokyo/A1320/A132002/13245550/）。marble・AINA CAFE と同じく閉店日前の前倒し。根拠 URL を unverified で `sources.csv` に追記。sources: 新規9行・既存6行（unverified→conditional/allowed が4、wanico・オルオルアイナの wankonowa が各1）を更新。「公式にペットの記載なし」だけの出典・「ペット可」とだけある食べログ（既存の条件付き出典と食い違うため）・Besties Tokyo の公式FAQ・SeTaBi の公式文言（曖昧）は追記していない。**後続の確認対象（変更なし）**: SeTaBi Cafe（2027-03-31 営業終了予定→2027-04 に非表示）、カフェ エナジャイズ（食べログに冬季完全休業の表記・営業は日曜のみ）、西庵カフェ（営業は土日のみとの追記）、YOUR BIG FAMILY（食べログに移転の表示）。
- **バッチN（店内同伴の出典割れ9店・2026-10-25）**: 「店内同伴OK」としていたのに「テラスのみ」とも書かれていた9店を、公式・食べログ・紹介サイトの原文で再調査して反映（結果の原本は調査時の `result.json`）。`dog_indoor` を **true のまま維持した4店**: VERVE 六本木（…0187・公式ニュース 2024-06-14 が「テラス席・店内一部がペット同伴可」と明記。どの席かは未記載）、The Jones Café | Bar（…0260・公式が場所の限定なしで1予約4頭まで同伴可と明記。公式行はルール a により allowed）、サクラカフェ日暮里（…0307・公式が「ペット同伴OK」「店内席でのご利用が可能」と明記。doghuggy はテラス席のみの言及で店内不可の明記ではない）、EMPORIO cafe&dining（…1120・店舗関係者公開の食べログ備考に「ペット店内OK」。「テラス・オープンエアのみ」とする itsumo.dog は今回 HTTP 503 で確認できず、dog_note からは外し sources.csv の既存行は残置）。**空（不明）に戻した5店**（出典同士で店内の可否が割れる、または「店内」の明記がない）: カフェ海猫山猫（…0740・公式は葉山店を「同伴OK(テラス席のみ)」、武蔵野店を席の限定なしの「ペット同伴OK」と書き分けるが、「店内」の語の明記はないため運営判断で不明に）、 ROJU NAKAMEGURO（…0063・公式はテラス席での同伴のみ記載、食べログ・紹介2サイトは店内可、inunavi はテラスのみ）、Restaurant Perfumes（…0842・公式・食べログとも「ペットのご同伴はご相談ください」のみで席の指定なし。ランチはテラス・ディナーは個室とするのは専門サイト2件のみ）、pepacafe FOREST（…0742・店内可とする記事4件〔2022〜2025〕と、店内不可・屋根付きテラスのみとする wanico〔2026-03-24〕で割れる。公式 Instagram のハイライト「ペットをお連れのお客様へ」の本文は取得できなかったので、**人が見れば確定できる見込み**。`dog_indoor_style` の floor|carrier も空に）、Aoi Coffee Stand（…0840・店内可と明記するのは odekake-wanko-bu〔2025-05-27〕のみ。`dog_size_max_indoor` の large も空に）。**Aoi Coffee Stand は営業の確認が必要**: 食べログ「アオイコーヒースタンド」が「掲載保留」（休業期間未確定・移転閉店の事実確認ができない）、公式 HP・公式 SNS は見つからず、同住所（西五反田1-9-3 B1F）に食べログの別掲載「Aoi」（バー・ペット可・店舗関係者公開）があり屋号が変わった可能性がある（同一事業かは未確認。sources.csv には追記していない）。現地または電話で確認する。9店とも dog_note・description の「情報により異なる…要確認」等の調査メモと、今回の結論と矛盾する断定文を事実だけの文に直した。sources.csv は原文を確認できた出典を追記5行・更新16行（確認できなかった出典、日付が分からない紹介サイト〔kyuzitsu-inubu〕、利用者編集の食べログ、pepacafe の食べログ「ペット可（場所の指定なし）」は追記・更新しない）。**代表出典の扱い**: 同じ店の出典の確認日を一律に上げると、同順位のファイル順で紹介サイトが代表出典になってしまうため、**verified_at を 2026-10-25 に上げたのは公式（official_hp/sns）と「店舗関係者公開」の食べログの行だけ**。紹介サイト・ブログ・利用者編集の食べログは条件文の事実化だけを行い確認日は元のまま（確認日は常に実際に閲覧した日。紹介サイトの新規行は追記しない）。この結果、ROJU の代表は公式（テラス席での同伴のみ記載）、サクラ日暮里の代表は公式（allowed・店内席可）になる。公式が無い Aoi・pepacafe は元の最新行が代表のまま（Aoi は odekake の行が allowed に変わる）。条件文は、席・場所・予約・時間帯の制限がないもの（「店内OK・テラスOK」「リード・足元・ワクチンのみ」「場所の指定なし」）を allowed にし、括弧の注記（日付・利用者編集など）は外した。**pepacafe は `dog_terrace`=true**（wanico・odekake・hotpepper の既存行がテラス可）。ROJU の `dog_size_limit` は、単独の紹介サイト由来の「大型犬はテラス席のみ」を外した。
- **バッチO・Q（2026-10-27〜30）**: 休業・営業不明の9店を再確認。**SHAPLA-INDIA（…0884）と Aoi Coffee Stand（…0840）を非表示**（運営方針「食べログ掲載保留＋公式の発信が長期途絶、または同住所で別店が営業」に該当。SHAPLA は 2021-03-27 閉店の報道・口コミは 2020/04 まで、Aoi は口コミ 2019/07 まで・同じ建物 B1F でバー「Aoi」が営業）。休業中のわんすた・MILLS（「9月中旬オープン予定」の告知後も再開未確認）・SLOW TABLE・WANKOIWA・Cyan coffee と UN COEUR は非表示を維持。Vegeater は営業継続（公式IG 2025-12）。犬の大きさの試行調査（人気エリアの23店）は収穫 13%（大きさが公式・食べログに書かれていない店がほとんど）で、残りへの展開は見送り。THE LINKING（…0321）に店内の過ごし方 floor（wanico・ぐるなびのペット欄が一致）を記入。根拠の出典は unverified で追記（代表出典は変えない）。
- **鉄則**: 推測禁止／出典URL+確認日必須／provenance=`aggregated`固定／矛盾は両方記録／**エージェントはcommitしない**（運営がdiffレビューして反映＝承認）。
- 新規エリア・店の追加（wave）は随時。リリースは全網羅を待たなくてよい。

### 🔴 B. App Store 提出手続き（ユーザー=changch223 本人の作業）
- **進捗: 未確認**（本ドキュメント更新時点でリポジトリ上に記録なし。着手状況は本人に確認すること）。
1. **Apple Developer Program 加入**（$99/年・審査1-2日）
2. App Store Connect でアプリ登録（Bundle ID `com.dokowancafe.app` / 名前「Puppy With Cafe」の空き確認）
3. ストア素材（スクショ・説明文・キーワード）→ 下書き: `docs/appstore/store-listing.md`（2026-10-26 に再設計後の画面・機能へ書き直し済み）、スクリーンショットの撮影ガイド: `docs/appstore/screenshots.md`（6.9" で5枚）
4. App Privacy 申告 → **「データを収集していません」**（方針・根拠は `docs/appstore/app-privacy.md`。現在地は端末内のみで処理し送信・保存しない）
5. Xcode で Archive → アップロード → 審査提出（審査メモ: `docs/appstore/review-notes.md`、全手順: `docs/appstore/submission-checklist.md`）

**App Store 準備の現状（ブランチ `feat/appstore-readiness`）**
- アプリ側で対応済み: 誤り報告フォーム未設定時は報告ボタンを非表示（「準備中」画面に到達しない）／「このアプリについて」画面（「うちの子」タブの下部。バージョン・プライバシーポリシー・サポート・出典クレジット）／`PrivacyInfo.xcprivacy` を収集なしに是正／Instagram 埋め込みの WebView を非永続化／キャッシュに距離を保存しない／リモート取得のタイムアウト15秒＋失敗後5分は再取得しない／`MARKETING_VERSION=1.0.0`・`ITSAppUsesNonExemptEncryption=NO`／日本語のみ（`ja.lproj` 生成・`en` 廃止）。
- 公開ページ・ストア文面は `docs/`（`privacy.html` / `support.html` / `appstore/`）に作成済み。
- 審査メモ（`review-notes.md`）・提出チェックリスト（`submission-checklist.md`）は 2026-10-26 に再設計後の画面（検索バー・3タブ・うちの子）へ更新済み。
- **残りはユーザー作業**: Apple Developer 加入・App Store Connect 登録、スクリーンショット撮影、App Privacy 入力、Archive・提出。

### 🟡 C. Google フォーム作成（T071・後日。v1.0 はフォームなしで提出）
- **v1.0 はフォームなしで App Store に提出する**。問い合わせ・誤り報告の窓口は**メール（irairappo@gmail.com、2026-10-27 運営決定）**と GitHub Issues（https://github.com/changch223/puppy-with-cafe/issues）で、`docs/privacy.html` / `docs/support.html` に記載済み（メールの扱い、GitHub アカウントが必要・内容は公開される旨も明記）。アプリ内の「情報の誤りを報告」ボタンは `AppEnvironment.defaultReportFormTemplate` が `nil` の間は自動で非表示。審査メモ・ストア文面もフォームなし前提に修正済み（`docs/appstore/`）。
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
- **初期データの取り方**: 6000件規模を効率よく集める方法は継続検討（現状は 693件。調査エージェント＋cc-crew 運用で積み上げ）。

## 7. 触るときの注意（落とし穴）
- **憲章 原則I は絶対**: 「推測で犬OK」「出典/確認日なしの確定情報」を作らない。これを破るデータはエクスポート検証が拒否する設計。
- 外部依存はゼロ。最小 iOS は 17（`onChange(of:)` は2引数版など新しい形を使う。非推奨 API の警告は0に保つ）。
- Xcode プロジェクトは `FileSystemSynchronizedRootGroup` 方式。`DokoWanCafe/DokoWanCafe/` 以下にファイルを置けば自動でターゲットに入る（pbxproj 手編集ほぼ不要）。
- テストは凍結フィクスチャ（`DokoWanCafeTests/Fixtures/cafes.json`）を使う。アプリ本体の `Resources/cafes.json`（実データ）とは別物。
- 旧A案（Supabase）の `supabase/` `Services/Supabase*` `AuthService` 等は**保管**。v1では未使用（規模拡大時の移行先）。research.md R11 参照。
- コミットは `Co-Authored-By` 行付き。データ収集エージェントは**コミットしない**。

## 8. ファイル地図（どこに何があるか）
| パス | 役割 |
|---|---|
| `DokoWanCafe/` | Xcode プロジェクト（アプリ本体・テスト）。画面と主要ファイルは §2.5 |
| `docs/appstore/` | App Store 提出資料（ストア文面・スクショガイド・審査メモ・チェックリスト・App Privacy） |
| `data/master/*.csv` | **データの正本**（ここを編集） |
| `data/cafes.json` / `CHANGELOG.md` | 生成物・変更履歴 |
| `tools/export_cafes.py` / `README.md` | 変換スクリプト・列仕様 |
| `research-agent/` | データ収集ブリーフ・進捗表・ギャップ補完ハンドオーバー（`gap-handover-2026-08.md`） |
| `.claude/agents/cafe-researcher.md` | 調査エージェント定義 |
| `specs/001-*` `specs/002-*` | 仕様・設計・タスク |
| `docs/privacy.html` | プライバシーポリシー（Pages公開） |
| `supabase/` | 旧A案（保管・未使用） |
