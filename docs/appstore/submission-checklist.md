# App Store 初回提出チェックリスト（ユーザー本人の作業順）

凡例: 【本人】= 本人にしかできない作業 / 【AI】= Claude に頼める作業

現状（2026-10-26 時点・コードから確認。画面の再設計 段階1〜4 完了後）: Bundle ID `com.dokowancafe.app` / 表示名 Puppy With Cafe / 版数 1.0.0 (build 1) / `DEVELOPMENT_TEAM = MY8WU4892D`（要確認・変更）/ iPhone 専用・縦向き・**iOS 17+** / 誤り報告フォーム URL は `nil`（未設定。未設定の間は店詳細の報告ボタンが自動で非表示）。**v1.0 はフォームなしで提出する**（問い合わせ・誤り報告の窓口は GitHub Issues。docs/privacy.html・docs/support.html に記載済み）。

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

## 4. 問い合わせ窓口の確認（v1.0 は Google フォームなし）
- v1.0 はフォームなしで提出する。アプリ内の「情報の誤りを報告」ボタンは、`AppEnvironment.defaultReportFormTemplate` が `nil` の間は自動で非表示になる（コード変更は不要）。
- 問い合わせ・誤り報告の窓口は GitHub Issues（https://github.com/changch223/puppy-with-cafe/issues）。`docs/privacy.html` `docs/support.html` に反映済み（GitHub アカウントが必要・内容は公開される旨を明記）。
- Google フォームは後日導入する（手順は `google-form-setup.md`）。導入時にアプリと docs を更新して新版として出す。

## 5. docs を公開して確認
- 【本人】PR をレビューして `main` にマージ → GitHub Pages に公開されるのを待つ（数分）。
- 【本人】公開 URL を実ブラウザ（ログアウト状態）で確認:
  - https://changch223.github.io/puppy-with-cafe/docs/privacy.html
  - https://changch223.github.io/puppy-with-cafe/docs/support.html
  - https://changch223.github.io/puppy-with-cafe/data/cafes.json
  - 各ページの GitHub Issues リンクが開くこと

## 6. スクリーンショットを撮影
**必須: 6.9 インチ（iPhone 17 Pro Max など）= 1320 × 2868 px**（iPhone 専用アプリなので 6.9" の 1 サイズだけ必須。5〜10 枚、最低 1 枚。6.5" など他サイズは 6.9" から自動縮小される）。

撮る**5枚の場面・順番・キャプション案・シミュレータの準備コマンド・提出前チェックは [`screenshots.md`](screenshots.md)** にまとめた（再設計後の画面に合わせて 2026-10-26 に新規作成）。要点:

| # | 場面 | ねらい |
|---|---|---|
| 1 | 散歩中に今入れる店（さがすタブ・半分の一覧・「営業中」「うちの子OK」） | 第一印象。一覧の行で「入れるか・今開いているか・徒歩何分か」が分かる |
| 2 | 週末の計画（「いつ行く？」で土・昼12時） | 日時から探せる |
| 3 | うちの子が入れるか（詳細の先頭: うちの子の1行＋答えのカード） | 「入れる」と明記があるときだけ表示する、という差別化 |
| 4 | 根拠が見える（根拠の1行／根拠のシート） | **最大の差別化（推測しない・出典と確認日つき）。必ず撮る** |
| 5 | 保存タブ（行きたい） | 計画に使える |

- **架空・サンプルデータの店が写り込まないこと**（本番 cafes.json 配信後に撮る）。
- 実在店の外観写真・Instagram 埋め込みが写る場合は、権利面で避けるか写真が出ない店を選ぶ（`screenshots.md` 参照）。
- 【AI】撮影用に画面状態を作るためのデバッグ設定の提案（コード変更は本人の承認後）、サイズ検証、キャプション文案。

## 7. App Store Connect に素材を入力
- 【本人】「iOS App > 1.0 提出準備中」で `store-listing.md` の各項目をコピペ: サブタイトル / プロモーションテキスト / 説明文 / キーワード / サポート URL / プライバシー URL / 著作権 / カテゴリ（主: フード/ドリンク、副: ナビゲーション）/ スクリーンショット（`screenshots.md` の5枚を 6.9" にドラッグ）/ アプリアイコン（ビルドから自動。1024px・アルファなし）。
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
  - [ ] 初回起動で位置情報の許可ダイアログ（文言: 「周辺の犬同伴OKカフェを現在地から探すために…」）→ 許可で周辺カフェ、拒否でも検索バーから地域を選んで使える
  - [ ] 初回のデータ表示のあとに「うちの子のことを教えてください」のシートが**一度だけ**出る（「あとで設定する」で閉じられ、次の起動では出ない）。設定すると「うちの子」タブと検索バーの犬のボタン（大きさの頭文字）に反映される
  - [ ] 東京都外にいる場合の「この場所は現在サービス対象外です」と、検索バー →「よく探されるエリア」→「渋谷」で表示される流れ
  - [ ] 条件チップ: 「いつ行く？」で日時を選ぶと一覧・ピン・見出しが「土 12:00」に変わり、リセットで戻る。「うちの子OK」（未設定で押すと設定が開く）・「営業中」・「店内OK」などの絞り込み。0件のときに「条件に合うお店がありません」と「条件をクリア」が出る
  - [ ] 一覧シートの3段（見出しだけ／半分／ほぼ全画面）、ピンをタップした店のカード（経路・電話・行きたい・共有・詳しく見る）
  - [ ] 店詳細: 答えのカード（入れる・入れない・分からない）と根拠の1行、根拠をタップして開く「確認の根拠」、うちの子の1行、営業時間・電話・リンク・Instagram 埋め込み（失敗時のフォールバック）
  - [ ] 経路（Apple マップ／Google マップ）
  - [ ] 「行きたい」「行った」の追加・解除・再起動後の保持（保存タブの2つのリスト・左スワイプで外す）
  - [ ] 店詳細に「情報の誤りを報告」ボタンが**表示されない**こと（v1.0 はフォームなし。審査メモの記載どおり）
  - [ ] 機内モードで起動してもバンドルデータで動く（オフライン表示の注記。絞り込みで0件のときの案内も出る）
  - [ ] ダークモード、文字サイズ最大（設定 > アクセシビリティ > 画面表示とテキストサイズ > さらに大きな文字）で崩れない、VoiceOver で一覧の行・ピン・答えのカードが意味の通る順で読み上げられる
  - [ ] クラッシュ・表示崩れなし（iPhone SE 系の小画面があれば併せて）
- 【AI】確認中に見つかった不具合の修正、再ビルド（ビルド番号 +1）。

## 11. 審査に提出
- 【本人】「App Review に関する情報」: 連絡先を入力、**サインイン情報は「サインインが必要」OFF**、「メモ」に `review-notes.md` の英語版（＋日本語）を貼る。
- 【本人】ビルドを選択（TestFlight で確認したビルド）→ 輸出コンプライアンス（設定済みなら質問なし）→ 「リリース方法」を選ぶ（初回は「手動でリリース」を推奨: 承認後に好きなタイミングで公開できる）→ **「審査へ提出」**。
- 審査は通常 24〜48 時間。リジェクトされたら理由を貼ってもらえれば 【AI】が対応案（修正・返信文）を作る。
- 公開後: 【AI】 `CLAUDE.md` / `HANDOFF.md` の更新、App Store の URL を support / README へ反映。

## 提出前の最終ゲート（全部 ON になってから提出）
- [ ] `grep -rn "FORM_URL" docs/*.html` が何も出ない（プレースホルダ残りなし。google-form-setup.md の手順内の記載は除く）
- [ ] `AppEnvironment.defaultReportFormTemplate` が `nil` のままで、報告ボタンが非表示（v1.0 の方針）
- [ ] privacy.html / support.html / cafes.json が公開 URL で開ける
- [ ] `ITSAppUsesNonExemptEncryption = NO` が Info.plist にある
- [ ] `PrivacyInfo.xcprivacy` と App Privacy 回答が整合
- [ ] スクリーンショットが 1320×2868（`screenshots.md` の5枚）、サンプル（架空）データの表示なし
- [ ] 審査メモに「東京都内のみ・審査地点が対象外なら検索バー →『渋谷』などを選ぶ」と、3つのタブ（さがす／保存／うちの子）の説明が入っている（`review-notes.md` を 2026-10-26 の画面に合わせて更新済み）
- [ ] `xcodebuild test` が全件成功（再設計 段階4 時点の件数は `HANDOFF.md` 参照）、ビルド警告なし
