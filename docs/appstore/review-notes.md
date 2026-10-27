# 審査メモ（App Review Information > Notes に貼り付ける）

> 英語と日本語を併記して貼る（審査担当は英語を読むため英語を先に）。
> 下記以外の項目: サインイン情報は「Sign-in required」を **OFF**（デモアカウント不要）。連絡先（氏名・電話・メール）は申請者本人のものを入力。

## 貼り付け用（English）

```
Thank you for reviewing Puppy With Cafe.

[What the app does]
Puppy With Cafe helps users find dog-friendly cafes on a map. It currently covers cafes in Tokyo, Japan only. The app UI is in Japanese only.

[No login / no demo account]
The app has no accounts and no sign-in. All features are available immediately after launch. No demo account is needed.

[IMPORTANT: coverage is Tokyo only]
Only cafes in Tokyo are listed. If your review location is outside Tokyo, the map shows a notice that the area is not supported. In that case, please tap the search bar at the top of the screen ("店名・駅・エリアで検索"), then choose a preset under "よく探されるエリア" such as "渋谷" (Shibuya), "中目黒" (Nakameguro) or "東京駅周辺" (Tokyo Station area). Cafes will then appear on the map and in the bottom list. (The same screen also has "現在地の周りで探す" = search around the current location.)

[Main screens]
- Tab 1 "さがす" (Search): map + search bar + filter chips ("いつ行く？" = pick a day/time and show only cafes open then; "うちの子OK" = only cafes that explicitly allow the user's dog; "営業中", "店内OK", "テラス", "大型犬OK", "犬メニュー") + a 3-step bottom list. Tapping a map pin shows a card; tapping a row or "詳しく見る" opens the cafe detail. The detail screen starts with an answer card (e.g. "店内で一緒に過ごせます" = you can stay inside together) and one line of evidence below it (source type and month of verification, e.g. "公式サイトで確認・2026年8月"); tapping that line opens the sources ("確認の根拠").
- Tab 2 "保存" (Saved): cafes the user marked "行きたい" (want to go) or "行った" (visited). Stored on the device only.
- Tab 3 "うちの子" (My dog): optional settings for the user's dog (size and how the dog stays in a shop). Stored on the device only (UserDefaults); no name or other personal data is asked. Also shows the data update date, a legend of the map pins, and "このアプリについて" (version, privacy policy, support, credits). A one-time sheet asks for these dog settings after the first launch; it can be skipped ("あとで設定する").
- "うちの子OK" is shown only when the cafe's data explicitly states that a dog of that size is allowed. When the data does not say so, the app shows "分からない"/"未確認" instead of guessing.

[Location permission]
The app asks for "When In Use" location permission only, to show nearby cafes and the distance to each cafe. The user's location is processed on the device only: it is not sent to any server and is not stored (distances are not cached either). The app works fully without location permission by choosing an area manually (see above).

[Data source]
Cafe data (cafes.json) is a static JSON file fetched from GitHub Pages (https://changch223.github.io/puppy-with-cafe/data/cafes.json). A copy is also bundled in the app, so the app works offline. The data is compiled by the operator from public web sources (official websites, official social media, Tabelog, blogs and dog-friendly guide sites) and checked against them; each cafe shows its source type and verification date, and information that could not be confirmed is shown as unconfirmed. No user-generated content is displayed.

[Third-party content]
On a cafe's detail screen, an Instagram post may be shown using Instagram's official embed (in a WebView), and link previews (title/image) are fetched directly by the device for the cafe's website, etc. No ads, no analytics, no tracking, no crash-reporting SDKs. App Privacy: "Data Not Collected".

[Error reports / contact]
The in-app error-report feature is not included (hidden) in this version, so there is no report button or form in the app. Contact and error reports are handled via the Support URL page (https://changch223.github.io/puppy-with-cafe/docs/support.html), which points to GitHub Issues. No sign-in is required in the app and the app collects no personal data.

[Encryption]
The app uses only standard HTTPS provided by the OS. ITSAppUsesNonExemptEncryption = NO.

Support: https://changch223.github.io/puppy-with-cafe/docs/support.html
Privacy Policy: https://changch223.github.io/puppy-with-cafe/docs/privacy.html
```

## 貼り付け用の日本語訳（自分用控え・Notes に併記してもよい）

```
Puppy With Cafe のご審査ありがとうございます。

【アプリ概要】
犬と一緒に入れるカフェを地図で探すアプリです。現在は東京都内のカフェのみ掲載しています。アプリの表示言語は日本語のみです。

【ログイン・デモアカウントは不要】
アカウント機能・サインインはありません。起動後すぐにすべての機能を利用できます。

【重要: 対象は東京都内のみ】
審査地点が東京都外の場合は「現在サービス対象外です」と表示されます。その場合は画面上部の検索バー（「店名・駅・エリアで検索」）をタップし、「よく探されるエリア」から「渋谷」「中目黒」「東京駅周辺」などを選んでください。地図と下の一覧にカフェが表示されます（同じ画面に「現在地の周りで探す」もあります）。

【主な画面】
・「さがす」タブ: 地図＋検索バー＋条件チップ（「いつ行く？」＝日時を選んでその時間に開いている店だけを表示、「うちの子OK」＝うちの子が入れると明記された店だけ、「営業中」「店内OK」「テラス」「大型犬OK」「犬メニュー」）＋3段の下の一覧。ピンをタップすると店のカード、行や「詳しく見る」で詳細へ。詳細は先頭に答えのカード（例:「店内で一緒に過ごせます」）、その下に根拠の1行（出典の種類と確認月。例:「公式サイトで確認・2026年8月」）。根拠の行をタップすると「確認の根拠」（参考記事）が開きます。
・「保存」タブ: 「行きたい」「行った」に登録したお店（端末内のみ）。
・「うちの子」タブ: うちの子の設定（大きさ・お店での過ごし方。任意。端末内の UserDefaults のみ。名前などの個人情報は聞きません）、データ更新日、ピンの見かた、「このアプリについて」（バージョン・プライバシーポリシー・サポート・出典クレジット）。初回起動後に一度だけ設定のシートが出ます（「あとで設定する」で閉じられます）。
・「うちの子OK」は、お店の情報に「その大きさの犬が入れる」と明記があるときだけ表示します。明記がなければ推測せず「分からない」「未確認」と表示します。

【位置情報】
「使用中のみ」の許可だけを要求し、周辺カフェの表示と各店までの距離の計算に使います。現在地は端末内で処理し、サーバーへ送信せず保存もしません（距離もキャッシュしません）。位置情報を許可しなくても、地域を手動で選べば全機能を使えます。

【データの取得元】
カフェ情報（cafes.json）は GitHub Pages の静的 JSON から取得します。アプリにも同じデータを同梱しており、オフラインでも動作します。データは運営が公開情報（公式サイト・公式SNS・食べログ・ブログ・犬連れ向けの紹介サイトなど）から整備し、出典と突き合わせて確認したもので、各店舗に出典の種類と確認日を表示します。確認できない情報は「未確認」と表示します。ユーザー投稿コンテンツは表示しません。

【サードパーティのコンテンツ】
店舗詳細で、Instagram 公式の埋め込み（WebView）による投稿表示や、店舗サイト等のリンクプレビュー（端末が直接取得）を行う場合があります。広告・解析・トラッキング・クラッシュ収集 SDK は使用していません。App Privacy は「データを収集しません」です。

【誤り報告・お問い合わせ】
誤り報告機能は今回の版ではアプリ内に表示されません（ボタン・フォームなし）。問い合わせ先はサポートページ（https://changch223.github.io/puppy-with-cafe/docs/support.html）で、GitHub Issues を案内しています。アプリ内ではサインイン不要で、個人情報は収集しません。

【暗号化】
OS 標準の HTTPS のみ使用。ITSAppUsesNonExemptEncryption = NO。
```

## 注意（提出前に確認）

- 審査中に GitHub Pages（cafes.json・support.html・privacy.html）が **公開状態・到達可能** であること。
- v1.0 は報告フォームなしで提出する。報告フォーム URL が未設定（`nil`）の間は店詳細の「情報の誤りを報告」ボタンが自動で非表示になり、審査メモの記載と一致する。フォームを導入する版では審査メモを更新すること（`google-form-setup.md`）。
- 審査メモ内の UI ラベル（検索バー「店名・駅・エリアで検索」・「よく探されるエリア」・タブ名「さがす／保存／うちの子」・「詳しく見る」・「確認の根拠」）は、スクリーンショット撮影時にアプリの実際の表示と一致しているか確認する（2026-10-26 時点の表示に合わせてある）。
- 審査担当の端末が東京都外のとき、起動直後は「この場所は現在サービス対象外です」の画面になり、「地域を選んで探す」ボタンからも同じ検索画面に進める。メモに書いた手順（検索バー → よく探されるエリア）と合わせて確認する。
