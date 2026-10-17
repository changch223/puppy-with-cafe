# App Store 初回提出チェックリスト（ユーザー本人の作業順）

凡例: 【本人】= 本人にしかできない作業 / 【AI】= Claude に頼める作業

現状（2026-10-17 時点・コードから確認）: Bundle ID `com.dokowancafe.app` / 表示名 Puppy With Cafe / 版数 1.0.0 (build 1) / `DEVELOPMENT_TEAM = MY8WU4892D`（要確認・変更）/ iPhone 専用・縦向き・iOS 16+ / 誤り報告フォーム URL は `nil`（未設定。未設定の間は店詳細の報告ボタンが非表示）。

## 1. Apple Developer Program に加入
- 【本人】https://developer.apple.com/programs/ から年額 US$99（≒ 15,000 円前後）で加入。個人 or 組織を選ぶ（個人の場合、App Store に表示される販売者名は本名になる。屋号表示が必要なら組織＝D-U-N-S 番号が必要）。承認まで数時間〜数日。
- 【本人】App Store Connect の「契約／税金／口座情報」: 無料アプリなら有料App契約（銀行口座・税務）は不要。ただし未承諾の契約（Apple Developer Program License Agreement の更新など）があれば承諾する。
- 【AI】どの種別（個人 / 組織）が必要かの整理。

## 2. チーム ID と署名設定を変更
- 【本人】developer.apple.com > Account > Membership details の **Team ID**（10 桁）を控える。
- 【AI】`project.pbxproj` の `DEVELOPMENT_TEAM`（Debug / Release の 2 か所）を新 Team ID に差し替え。Bundle ID を変える場合（`com.dokowancafe.app` は既に他者に取得されている可能性）は `PRODUCT_BUNDLE_IDENTIFIER` も合わせて変更。
- 【本人】Xcode > Settings > Accounts で Apple ID を追加し、Signing & Capabilities で「Automatically manage signing」が緑になることを確認。

## 3. App Store Connect にアプリを登録
- 【本人】App Store Connect > マイApp > ＋ > 新規App: プラットフォーム iOS / 名前 `Puppy With Cafe`（重複する場合は別名・`store-listing.md` 補足参照）/ 主言語 日本語 / バンドルID（Xcode で一度ビルドすると候補に出る。出ない場合は developer.apple.com > Identifiers で登録）/ SKU 任意（例 `puppywithcafe-001`）/ ユーザーアクセス 全アクセス。

## 4. Google フォームを作成
- 【本人】`google-form-setup.md` の手順 1〜3 に従ってフォーム作成、メール収集 OFF を確認、事前入力 URL を取得。
- 【AI】設問文・説明文の推敲、事前入力 URL からテンプレート文字列の組み立て。

## 5. フォーム URL をアプリと docs に反映
- 【AI】`AppConfig.swift` の `AppEnvironment.defaultReportFormTemplate` にテンプレートを設定。`docs/privacy.html` `docs/support.html` の `{{FORM_URL}}` を一括置換（`google-form-setup.md` §5）。`tools/README.md` / `CLAUDE.md` の記述を「設定済み」に更新。ビルド・テスト実行。
- 【本人】PR をレビューして `main` にマージ → GitHub Pages に公開されるのを待つ（数分）。
- 【本人】公開 URL を実ブラウザ（ログアウト状態）で確認:
  - https://changch223.github.io/puppy-with-cafe/docs/privacy.html
  - https://changch223.github.io/puppy-with-cafe/docs/support.html
  - https://changch223.github.io/puppy-with-cafe/data/cafes.json
  - 各ページから開くフォームが回答可能（ログイン不要）なこと

## 6. スクリーンショットを撮影
**必須: 6.9 インチ（iPhone 17 Pro Max など）= 1320 × 2868 px**（iPhone 専用アプリなので 6.9" の 1 サイズだけ必須。5〜10 枚、最低 1 枚。6.5" など他サイズは 6.9" から自動縮小される）。

### 手順（シミュレータ）
1. 【本人】Xcode のスキームでシミュレータ **iPhone 17 Pro Max** を選び Run。（無ければ Window > Devices and Simulators から追加）
2. 撮影前の準備（ターミナル）:
   ```bash
   xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
   xcrun simctl location booted set 35.6580,139.7016     # 渋谷付近。「現在地を使う」で周辺にカフェが出る
   xcrun simctl ui booted appearance light               # 全画面ライトで統一（ダークも撮るなら別途）
   ```
3. 撮影: ターミナルで `xcrun simctl io booted screenshot ~/Desktop/shots/01_map.png`（または シミュレータで ⌘S）。出力は実機解像度 1320×2868。
4. サイズ確認: `sips -g pixelWidth -g pixelHeight ~/Desktop/shots/*.png` → すべて 1320 × 2868 であること。
5. 終わったら `xcrun simctl status_bar booted clear`。
- 【AI】撮影用に画面状態を作るためのデバッグ設定の提案（コード変更は本人の承認後）、サイズ検証、キャプション文案。**架空・サンプルデータの店が写り込まないこと**（本番 cafes.json 配信後に撮る）。

### 撮る画面の候補（この順で 6〜8 枚）
| # | 画面 | ねらい / 状態 |
|---|---|---|
| 1 | 地図（渋谷など）に色分けピンが並ぶ | 第一印象。「犬と行けるカフェを地図で探す」。凡例が見える状態 |
| 2 | ピンをタップして出る下部シート（店名・距離・営業中） | 一目で判断できる |
| 3 | 店の詳細: 犬同伴可否＋**出典と確認日** | 最大の差別化（推測しない・出典つき）。ここは必ず撮る |
| 4 | 店の詳細: 犬向け設備・営業時間・リンク | 情報の充実度 |
| 5 | 絞り込みメニュー（店内OK／テラスOK／大型犬OK／犬メニュー） | 探しやすさ |
| 6 | リスト表示（距離順） | 並び替え |
| 7 | 地域選択（駅名・住所検索＋主要エリア） | 位置情報なしでも使える |
| 8 | お気に入り一覧 | 任意 |

- 店の詳細は営業時間・設備・出典がそろっている店を選ぶ（情報が空の店を避ける）。
- 画像に実在店の外観写真・Instagram 埋め込みが写る場合は、権利面で避けるかテキスト主体の状態で撮る。
- 画面上に文字キャプションを載せる加工は任意（やる場合は誇張しない）。

## 7. App Store Connect に素材を入力
- 【本人】「iOS App > 1.0 提出準備中」で `store-listing.md` の各項目をコピペ: サブタイトル / プロモーションテキスト / 説明文 / キーワード / サポート URL / プライバシー URL / 著作権 / カテゴリ（主: フード/ドリンク、副: ナビゲーション）/ スクリーンショット（6.9" にドラッグ）/ アプリアイコン（ビルドから自動。1024px・アルファなし）。
- 【本人】「App 情報」で プライバシーポリシー URL を入力。価格は無料、配信国は日本。
- 【AI】文字数・禁止語の最終チェック、英語版が必要になった場合の訳。

## 8. App Privacy と年齢区分
- 【本人】`app-privacy.md` §1 のとおり「データを収集していません」を選択して公開。§2 の回答で年齢区分 4+ を確認。§4 のコンテンツ配信権・広告 ID（使用しない）に回答。
- 【AI】`PrivacyInfo.xcprivacy`（収集データ宣言なし）と回答の整合、`ITSAppUsesNonExemptEncryption = NO` の設定を最終確認。

## 9. Archive してアップロード
- 【AI】事前に `xcodebuild test`（またはプロジェクトのテストコマンド）が緑であることを確認。ビルド番号 `CURRENT_PROJECT_VERSION` を提出ごとに増やす。
- 【本人】Xcode で 実機 or **Any iOS Device (arm64)** を選び Product > Archive > Distribute App > **App Store Connect > Upload**。署名は自動管理。完了後、App Store Connect の TestFlight にビルドが現れるまで数分〜数十分（処理中メールが届く）。

## 10. TestFlight で実機確認
- 【本人】TestFlight アプリ（内部テスター＝自分の Apple ID。審査不要）でインストールし、実機で次を確認:
  - [ ] 初回起動で位置情報の許可ダイアログ（文言: 「周辺の犬同伴OKカフェを現在地から探すために…」）→ 許可で周辺カフェ、拒否でも地域選択で使える
  - [ ] 東京都外にいる場合の表示と、地域ボタンから「渋谷」を選んで表示される流れ
  - [ ] 店詳細: 出典・確認日・営業中バッジ・電話・リンク・Instagram 埋め込み（失敗時のフォールバック）
  - [ ] 経路（Apple マップ／Google マップ）
  - [ ] お気に入りの追加・解除・再起動後の保持
  - [ ] **「情報の誤りを報告」→ フォームが開き、店名・店舗ID・種類が自動入力される**
  - [ ] 機内モードで起動してもバンドルデータで動く（オフライン表示の注記）
  - [ ] クラッシュ・表示崩れなし（iPhone SE 系の小画面があれば併せて）
- 【AI】確認中に見つかった不具合の修正、再ビルド（ビルド番号 +1）。

## 11. 審査に提出
- 【本人】「App Review に関する情報」: 連絡先を入力、**サインイン情報は「サインインが必要」OFF**、「メモ」に `review-notes.md` の英語版（＋日本語）を貼る。
- 【本人】ビルドを選択（TestFlight で確認したビルド）→ 輸出コンプライアンス（設定済みなら質問なし）→ 「リリース方法」を選ぶ（初回は「手動でリリース」を推奨: 承認後に好きなタイミングで公開できる）→ **「審査へ提出」**。
- 審査は通常 24〜48 時間。リジェクトされたら理由を貼ってもらえれば 【AI】が対応案（修正・返信文）を作る。
- 公開後: 【AI】 `CLAUDE.md` / `HANDOFF.md` の更新、App Store の URL を support / README へ反映。

## 提出前の最終ゲート（全部 ON になってから提出）
- [ ] `grep -rn "FORM_URL" docs/` が何も出ない（プレースホルダ残りなし）
- [ ] `AppEnvironment.defaultReportFormTemplate` が `nil` ではない
- [ ] privacy.html / support.html / cafes.json が公開 URL で開ける
- [ ] `ITSAppUsesNonExemptEncryption = NO` が Info.plist にある
- [ ] `PrivacyInfo.xcprivacy` と App Privacy 回答が整合
- [ ] スクリーンショットが 1320×2868、サンプル（架空）データの表示なし
- [ ] 審査メモに「東京都内のみ・審査地点が対象外なら『渋谷』を選ぶ」が入っている
