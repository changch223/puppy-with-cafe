# 審査メモ（App Review Information > Notes に貼り付ける）

> 英語だけを貼る（審査担当は英語で読む。4000字の上限に近いので日本語は併記しない）。
> 下記以外の項目: サインイン情報は「Sign-in required」を **OFF**（デモアカウント不要）。連絡先（氏名・電話・メール）は申請者本人のものを入力。

## 貼り付け用（English・v1.1）

```
Thank you for reviewing Puppy With Cafe (version 1.1).

[What is new in 1.1]
- The cafe card on the map can be swiped left/right to go to the next cafe in the list; the map follows.
- When the map is zoomed out to show all of Tokyo, pins are replaced by area labels with the number of cafes; tapping a label zooms into that area.
- The search screen has "場面から探す" (find by situation), five shortcuts that set filters, e.g. "雨の日でも" (rainy day = indoor seating allowed). They keep the current search location, so outside Tokyo choose an area first.
- The chips above the map were reduced to four; the other filters are inside "絞り込み".
- Updated cafe data. No new permissions, no new data collection, no accounts, no purchases.

[Purpose and audience]
Puppy With Cafe helps dog owners in Tokyo, Japan find cafes they can visit with their dog. Problem: whether a cafe accepts dogs is scattered across shop websites, social media and blogs, and is often unclear. Value: the app shows about 800 Tokyo cafes on a map and states, for each one, whether dogs are allowed inside or on the terrace, with the source type and the date it was verified. Anything that could not be confirmed is shown as "未確認" (unconfirmed) rather than guessed. Audience: dog owners living in or visiting Tokyo. The UI is in Japanese.

[How to use: no login, no setup, no sample files]
All features are available right after launch.
- Launch the app. Allow location (optional). A one-time sheet asks the dog's size; it can be skipped with "あとで設定する".
- IMPORTANT: only Tokyo cafes are listed. If the device is outside Tokyo, tap the search bar at the top ("店名・駅・エリアで検索") and type "渋谷" (Shibuya) and choose the area "渋谷駅周辺" from the suggestions. Cafes then appear on the map and in the bottom list.
- Tab "さがす" (Search): map, search bar and four chips ("絞り込み" = more filters, "いつ行く？" = open at a chosen day/time, "うちの子OK" = explicitly allows my dog, "営業中" = open now). Tap a pin for a card; swipe the card sideways to compare nearby cafes; tap "詳しく見る" for details. The detail starts with an answer card and one line of evidence; tapping that line shows the sources.
- Tab "保存" (Saved): cafes marked "行きたい" (want to go) / "行った" (visited).
- Tab "うちの子" (My dog): optional dog size settings, data update date, pin legend, about. Both are stored on the device only.

[External services]
- Apple MapKit / CoreLocation: map display; place search (MKLocalSearch / CLGeocoder) only when the user submits a search query. The user's location is never sent anywhere.
- GitHub Pages: hosts our own static data file (https://changch223.github.io/puppy-with-cafe/data/cafes.json) and the support and privacy pages. A copy of the data is bundled, so the app also works offline.
- Instagram official embed: on some cafe detail screens, one post from the cafe's account is shown in a web view.
- Cafe websites: the device fetches the link preview (title/image) of the cafe's own page directly. Links open in the browser; directions open Apple Maps or Google Maps.
- Not used: authentication, payment, AI, analytics, advertising, tracking or crash-reporting services, and no backend server of our own. App Privacy: Data Not Collected.

[Regional differences]
The app works the same way in all regions. The only limitation is content: the cafes listed are all in Tokyo, Japan.

[Regulated industry / third-party material]
The app is not in a regulated industry. Cafe information is factual data (name, address, hours, dog policy) compiled by us from public sources, each shown with its source and a link to it. We do not copy third-party photos or articles: images appear only through Instagram's official embed or as link previews loaded from the cafe's own page. The open address data we used (Japan Digital Agency, Address Base Registry) is credited in the app.

Contact: irairappo@gmail.com
Support: https://changch223.github.io/puppy-with-cafe/docs/support.html
Privacy Policy: https://changch223.github.io/puppy-with-cafe/docs/privacy.html
```

## v1.1 で変えた所（自分用の控え）

- 先頭に「1.1 の新しい点」（カードを横にめくる・引いたときのエリア表示・場面から探す・チップ4つ・データ更新。新しい権限やデータ収集はなし）を足した。
- 「さがす」タブの説明を、チップ4つ（絞り込み／いつ行く？／うちの子OK／営業中）とカードを横にめくる操作に合わせた。
- 目的と対象・使い方・外部サービス・地域差・権利関係は、v1.0 の審査（ガイドライン 2.1 の追加情報の依頼、2026-11-13）に答えた内容をそのまま残している。画面録画は v1.0 のときに提出済みで、今回は求められていない。求められたら実機で撮り直す。

## 注意（提出前に確認）

- 審査中に GitHub Pages（cafes.json・support.html・privacy.html）が **公開状態・到達可能** であること。
- v1.0 は報告フォームなしで提出する。報告フォーム URL が未設定（`nil`）の間は店詳細の「情報の誤りを報告」ボタンが自動で非表示になり、審査メモの記載と一致する。フォームを導入する版では審査メモを更新すること（`google-form-setup.md`）。
- 審査メモ内の UI ラベル（検索バー「店名・駅・エリアで検索」・「場面から探す」・入力中の候補のエリア「渋谷駅周辺」・タブ名「さがす／保存／うちの子」・「詳しく見る」・「確認の根拠」）は、スクリーンショット撮影時にアプリの実際の表示と一致しているか確認する（2026-10-26 時点の表示に合わせてある）。
- 審査担当の端末が東京都外のとき、起動直後は「この場所は現在サービス対象外です」の画面になり、「地域を選んで探す」ボタンからも同じ検索画面に進める。メモに書いた手順（検索バー →「渋谷」と入力 → 候補の「渋谷駅周辺」）と合わせて確認する。
