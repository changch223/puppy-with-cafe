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
Only cafes in Tokyo are listed. If your review location is outside Tokyo, the map will show no cafes nearby. In that case, please tap the map-pin icon button at the top-left of the screen to open the area picker ("検索する地域"), and choose a preset such as "渋谷" (Shibuya), "新宿" (Shinjuku) or "東京駅周辺" (Tokyo Station area). Cafes will then appear on the map and in the list. You can also tap a cafe pin and then "詳細" (Details) to see the source and verification date of the dog-policy information, or "経路" (Route) to open Apple Maps / Google Maps.

[Location permission]
The app asks for "When In Use" location permission only, to show nearby cafes and the distance to each cafe. The user's location is processed on the device only: it is not sent to any server and is not stored (distances are not cached either). The app works fully without location permission by choosing an area manually.

[Data source]
Cafe data (cafes.json) is a static JSON file fetched from GitHub Pages (https://changch223.github.io/puppy-with-cafe/data/cafes.json). A copy is also bundled in the app, so the app works offline. The data is compiled and verified by the operator from public sources (official websites / official social media); each cafe shows its source type and verification date. No user-generated content is displayed.

[Third-party content]
On a cafe's detail screen, an Instagram post may be shown using Instagram's official embed (in a WebView), and link previews (title/image) are fetched directly by the device for the cafe's website, etc. No ads, no analytics, no tracking, no crash-reporting SDKs. App Privacy: "Data Not Collected".

[Error reports / contact]
The "情報の誤りを報告" (Report an error) button on the detail screen opens a Google Form in the browser. No sign-in is required and no email address is collected.

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
審査地点が東京都外の場合、周辺にカフェは表示されません。その場合は画面左上の地図ピンのアイコンボタンから「検索する地域」を開き、「渋谷」「新宿」「東京駅周辺」などを選んでください。地図とリストにカフェが表示されます。ピンをタップして「詳細」を開くと、犬同伴可否の出典と確認日を確認できます。「経路」から Apple マップ／Google マップを開けます。

【位置情報】
「使用中のみ」の許可だけを要求し、周辺カフェの表示と各店までの距離の計算に使います。現在地は端末内で処理し、サーバーへ送信せず保存もしません（距離もキャッシュしません）。位置情報を許可しなくても、地域を手動で選べば全機能を使えます。

【データの取得元】
カフェ情報（cafes.json）は GitHub Pages の静的 JSON から取得します。アプリにも同じデータを同梱しており、オフラインでも動作します。データは運営が公開情報（公式サイト・公式SNS）から整備・確認したもので、各店舗に出典の種類と確認日を表示します。ユーザー投稿コンテンツは表示しません。

【サードパーティのコンテンツ】
店舗詳細で、Instagram 公式の埋め込み（WebView）による投稿表示や、店舗サイト等のリンクプレビュー（端末が直接取得）を行う場合があります。広告・解析・トラッキング・クラッシュ収集 SDK は使用していません。App Privacy は「データを収集しません」です。

【誤り報告・お問い合わせ】
詳細画面の「情報の誤りを報告」から Google フォームをブラウザで開きます。サインイン不要で、メールアドレスも収集しません。

【暗号化】
OS 標準の HTTPS のみ使用。ITSAppUsesNonExemptEncryption = NO。
```

## 注意（提出前に確認）

- 審査中に GitHub Pages（cafes.json・support.html・privacy.html）が **公開状態・到達可能** であること。`{{FORM_URL}}` 未差し替えのまま提出しない。
- 報告フォーム URL が未設定だと、店詳細の「情報の誤りを報告」ボタンが表示されない（審査メモの説明と食い違う）。**フォーム作成・URL 反映後にビルドして提出**する（`google-form-setup.md`）。
- 審査メモ内の UI ラベル（地域ボタン・「詳細」「経路」）は、スクリーンショット撮影時にアプリの実際の表示と一致しているか確認する。
