# 🐶☕ Puppy With Cafe

**愛犬と一緒に入れるカフェを、現在地から地図で探せる iOS アプリ**（コードネーム: DokoWanCafe）

<p>
<img src="docs/screenshots/app_icon.png" width="96" alt="App Icon" />
</p>

| 地図と検索で発見 | 答えを先に（店の詳細） | うちの子の設定 |
|---|---|---|
| <img src="docs/screenshots/home.png" width="240" alt="ホーム: 地図・検索バー・条件チップ・一覧シート" /> | <img src="docs/screenshots/detail.png" width="240" alt="店の詳細: 答えのカードと根拠の1行" /> | <img src="docs/screenshots/onboarding.png" width="240" alt="うちの子の設定（初回の2問）" /> |

> 🤝 **開発を引き継ぐ人（別PC・別AIセッション）へ**: まず [`HANDOFF.md`](HANDOFF.md) を読んでください。現状・環境セットアップ・次の作業がまとまっています。

## なぜ作ったか

犬同伴OKの情報は 公式HP・Instagram・食べログ・ブログに**散乱**していて、どれが最新で正しいのか分からない。生成AIに聞くと「実際は犬OKなのに不可」と**誤答**されることさえある。

だからこのアプリは、**すべての犬同伴情報に「出典・確認日・由来」を付け、推測で「犬OK」と表示しない**ことを憲章（[constitution](.specify/memory/constitution.md)）で定めている。

## 特徴

- 📍 **地図＋3段の一覧シート**で犬OKカフェを発見。検索バーから店名・駅・エリアでも探せる。ピンは**形と色**（店内OK＝緑の丸・テラス＝青緑の角丸四角・条件を確認＝橙のしずく・未確認＝灰色の菱形）で見分けられる
- 🕐 **「いつ行く？」**で日時を選ぶと、その時刻に開いているお店だけを表示
- 🐶 **「うちの子」**の大きさ・店内での過ごし方を設定すると、入れると明記されたお店に「うちの子OK」（設定は端末内のみ）
- ✅ 詳細は**答えを先に**: 「店内で一緒に過ごせます」などの答えのカード＋根拠の1行（出典の種類と確認月）。可否は4値: **犬OK / 条件付き（テラスのみ等）/ 犬不可 / 未確認** — 憶測で「OK」にしない
- 📌 気になるお店は「行きたい」、行ったお店は「行った」に保存（端末内のみ）
- 🔍 全情報に**出典リンクと最終確認日**。出典間で食い違えば**矛盾をそのまま提示**
- 🤖 AI推測由来の情報は**明示ラベルで区別**
- 🕐 営業時間（営業中の判定）・犬向け設備（店内/テラス/大型犬/犬メニュー）・電話・公式リンク・経路（Apple／Google マップ）
- 🔒 プライバシー: 位置情報は**端末内でのみ**使用（どこにも送信しない）。アカウント不要・トラッキングなし

## アーキテクチャ（サーバーレス）

```
Google Sheet / data/master/*.csv（マスター）
   → tools/export_cafes.py（検証・矛盾解決・差分CHANGELOG）
   → data/cafes.json
       ├─ アプリにバンドル（オフライン対応）
       └─ GitHub Pages から配信（アプリ審査なしでデータ即時更新）
誤り報告: メール（irairappo@gmail.com）または GitHub Issues（専用フォームは準備中）→ 運営レビュー → マスター反映
```

- iOS: Swift / SwiftUI（+ MapKit は UIKit 橋渡し）/ MVVM / iOS 17+ / **外部パッケージ依存ゼロ**
- データの品質はエクスポート時の**検証ゲート**で担保（条件付き⇒条件必須・確認日必須・重複検出 等）

## 開発

```bash
# ビルド & テスト（XCTest。Core の純ロジック中心）
cd DokoWanCafe
xcodebuild test -project DokoWanCafe.xcodeproj -scheme DokoWanCafe \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# データ更新（検証→差分→JSON生成）
python3 tools/export_cafes.py --check   # 検証のみ
python3 tools/export_cafes.py           # 本出力
```

- 仕様・設計: [`specs/`](specs/)（Spec-Driven Development / [Spec Kit](https://github.com/github/spec-kit)）
- データ列仕様・運用: [`tools/README.md`](tools/README.md)
- データ変更履歴: [`data/CHANGELOG.md`](data/CHANGELOG.md)
- プライバシーポリシー: [`docs/privacy.html`](docs/privacy.html)

## データについて

- 対象エリア: **東京都内・595件**（出典1594件。店数は 2026-10-24 時点、出典数は 2026-10-25 時点。うち表示中は564件。座標は全店を住所・店舗ページのピンと照合済み。他府県への拡大は今後の課題）
- 掲載情報は収集時点のものです。**お出かけ前に店舗の公式情報をご確認ください。**
- 誤りを見つけた場合は、メール（irairappo@gmail.com）または GitHub Issues でお知らせください（専用フォームは準備中です）。

## データ収集に参加する

東京の犬同伴可カフェを増やす調査に協力できます。

- 調査エージェント向けブリーフ（そのまま渡せば作業開始できる）: [`research-agent/README.md`](research-agent/README.md)
- エリア別の進捗・優先度: [`research-agent/progress.md`](research-agent/progress.md)
- 鉄則: **推測で「犬OK」と書かない**。出典URLと確認日を必ず添える（[憲章](.specify/memory/constitution.md) 原則I）。

## 開発を引き継ぐ・別環境で再開する

[`HANDOFF.md`](HANDOFF.md) に、現状・環境セットアップ・次の作業の優先度がまとまっています。

## License

- コード: [MIT License](LICENSE)
- カフェデータ（`data/`）: 出典の権利は各出典元に帰属します。データの再配布時は出典を明示してください。
