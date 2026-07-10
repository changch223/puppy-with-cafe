# 🤝 引き継ぎドキュメント — Puppy With Cafe

> **別PC・別AIセッションへの引き継ぎ用**。このファイルとリポジトリを渡せば作業を継続できる。
> 最終更新: 2026-07-10 / 状態: **MVP実装完了・データ配信本稼働・データ収集フェーズ**

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
- ✅ データ基盤（サーバーレス構成B）: `data/master/*.csv` → `tools/export_cafes.py`（検証・矛盾解決・差分CHANGELOG）→ `data/cafes.json`
- ✅ **データ配信 本稼働**: GitHub Pages で `cafes.json` を配信。アプリが起動時に取得（アプリ審査なしで更新反映）
- ✅ テスト **49件全緑**（`Core/` の純ロジック中心）
- ✅ 公開物: リポジトリ(public)・README・プライバシーポリシー

### 環境・URL
- リポジトリ: https://github.com/changch223/puppy-with-cafe （public / GitHubアカウント: changch223）
- データ配信: https://changch223.github.io/puppy-with-cafe/data/cafes.json
- プライバシーポリシー: https://changch223.github.io/puppy-with-cafe/docs/privacy.html
- Bundle ID: `com.dokowancafe.app` / 表示名: Puppy With Cafe / 最小iOS: 16
- 現在の実データ: 天王洲アイル **5件**（`data/master/cafes.csv`）

## 3. 別PCでの環境セットアップ（新PCで最初にやること）

```bash
# 1) クローン
git clone https://github.com/changch223/puppy-with-cafe.git
cd puppy-with-cafe

# 2) 必要ツール
#    - Xcode 26+（iOS 16+ シミュレータ）
#    - Python 3（標準ライブラリのみ。追加パッケージ不要）
#    - gh CLI（push用。`gh auth login` で changch223 アカウントにログイン）

# 3) ビルド & テスト（49件緑を確認）
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

### 🔴 A. データ収集（最重要・ここが今のボトルネック）
- **担当**: 調査エージェント `.claude/agents/cafe-researcher.md`（Claude Code なら「cafe-researcher で代官山を調査して」）。他AIツールなら `research-agent/README.md` のブリーフをそのまま渡す。
- **手順**: `research-agent/README.md` に全部書いてある（絶対ルール・CSV列仕様・出典の探し方・報告様式）。
- **進捗表**: `research-agent/progress.md`（優先★★★: 代官山・自由が丘・二子玉川・吉祥寺）。
- **鉄則**: 推測禁止／出典URL+確認日必須／provenance=`aggregated`固定／矛盾は両方記録／**エージェントはcommitしない**（運営がdiffレビューして反映＝承認）。
- リリースは全網羅を待たなくてよい（50〜100件で先行公開可。「東京・順次拡大」は仕様済み）。

### 🔴 B. App Store 提出手続き（ユーザー=changch223 本人の作業）
1. **Apple Developer Program 加入**（$99/年・審査1-2日）
2. App Store Connect でアプリ登録（Bundle ID `com.dokowancafe.app` / 名前「Puppy With Cafe」の空き確認）
3. ストア素材（スクショ・説明文・キーワード）※AIが下書き可
4. App Privacy 申告（位置情報=機能目的のみ・追跡なし・リンクなし）※回答案はAIが用意可
5. Xcode で Archive → アップロード → 審査提出

### 🟡 C. Google フォーム作成（T071・ユーザー作業）
- 誤り報告の受付。`tools/README.md` 手順2 に沿ってフォーム作成 → プリフィルURLを `AppConfig.defaultReportFormTemplate` に設定。
- リリース前でなくてもよいが、あると報告ループが完成する。

### 🟡 D. 座標スポットチェック（T118・軽作業）
- WHAT CAFE / breadworks / Le Calin の3件は座標が街区基準の概算。Google Maps でピン→座標を `data/master/cafes.csv` に反映 → `python3 tools/export_cafes.py`。
- （T.Y.HARBOR・RIDE は OSM 実測で確定済み）

### ⚪ E. v2候補（リリース後）
お気に入り・店名検索・営業中/設備フィルタ・写真・AIスクリーニング（設計済: `supabase/functions/ai-screen/`）・エリア拡大。

## 5. データ更新の作業フロー（誰がやっても同じ）

```bash
# 1) data/master/cafes.csv / sources.csv を編集（列仕様: tools/README.md）
# 2) 検証（エラーなく通るまで直す）
python3 tools/export_cafes.py --check
# 3) 本出力（cafes.json 生成＋アプリへコピー＋差分をCHANGELOGに記録）
python3 tools/export_cafes.py
# 4) レビュー & 反映
git add -A && git commit -m "data: <エリア> N件追加" && git push
#   → push すると GitHub Pages が更新され、全ユーザーのアプリに反映（審査不要）
```
- **これがこのプロジェクトの心臓**。CSV → 検証 → JSON → push、それだけ。

## 6. 未決事項（判断が要る・保留中）
- **T056**: 外部データAPI（住所/座標の補助集約）の採否 — 規約/コスト/法務の判断。MVPのブロッカーではない（手動で成立）。
- **初期データの取り方**: 6000件規模を効率よく集める方法は継続検討（現状は調査エージェントで積み上げ）。

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
| `research-agent/` | データ収集ブリーフ・進捗表 |
| `.claude/agents/cafe-researcher.md` | 調査エージェント定義 |
| `specs/001-*` `specs/002-*` | 仕様・設計・タスク |
| `docs/privacy.html` | プライバシーポリシー（Pages公開） |
| `supabase/` | 旧A案（保管・未使用） |
