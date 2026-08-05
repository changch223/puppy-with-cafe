# UI/UX調査（日本の類似アプリ）

## 目的

日本の類似アプリ（グルメ発見系・ペット特化系）のUI/UXベストプラクティスを調査し、犬同伴OKカフェ発見アプリ「Puppy With Cafe」に対する具体的なブラッシュアップ提案を作成する。

## 実施日

2026-08-05

## 進め方（多エージェントworkflow）

1. **スカウト（1エージェント）** — 調査対象10本（グルメ発見系5・ペット特化系5）を選定。
2. **アプリ別調査（10並列）** — 各アプリを個別のsubagentが調査し、`apps/*.md` として中間アウトプットを作成（概要/地図UX/一覧UX/詳細情報設計/写真/信頼性表示/行動喚起 等の統一フォーマット）。
3. **architect（統合）** — 10本の調査結果を横断比較し、`benchmark.md`（ベストプラクティス10箇条＋Puppy With Cafeの現状ポジション評価）と `improvement-proposals.md`（P0/P1/P2の優先度付き改善提案）に統合。
4. **保存** — 成果物一式を本ディレクトリに保存。プレゼン用に `proposal.html`（自己完結・ライト/ダーク対応）を作成。

## ファイル一覧

- [`benchmark.md`](benchmark.md) — 調査対象一覧・横断比較表・ベストプラクティス10箇条・Puppy With Cafeの現状ポジション評価（強み/弱み）。
- [`improvement-proposals.md`](improvement-proposals.md) — 改善提案本文（P0 4件・P1 4件・P2 4件）と未決点（オーケストレーター判断待ち）。
- [`proposal.html`](proposal.html) — 上記提案をまとめたプレゼン用HTML（外部依存なし・単独ファイルで閲覧可能・ライト/ダーク両テーマ対応）。
- `apps/` — アプリ別調査（中間アウトプット、各1エージェントが担当）
  - [`apps/tabelog.md`](apps/tabelog.md) — 食べログ。地図⇄一覧シームレス切替、点数中心設計。
  - [`apps/retty.md`](apps/retty.md) — Retty。実名口コミ型、シーン軸フィルタとTOP USER制度。
  - [`apps/hotpepper-gourmet.md`](apps/hotpepper-gourmet.md) — ホットペッパーグルメ。予約特化、地図上の空席可視化。
  - [`apps/google-maps.md`](apps/google-maps.md) — Googleマップ。Compact/Full2段階開示、pet-friendlyフィルタ非搭載。
  - [`apps/sauna-ikitai.md`](apps/sauna-ikitai.md) — サウナイキタイ。細分化フィルタと客観データ優先の詳細設計。
  - [`apps/odekake-wanko-bu.md`](apps/odekake-wanko-bu.md) — おでかけわんこ部。MAP検索主導線、店内OK/大型犬可/テラス席の絞込。
  - [`apps/wanpass.md`](apps/wanpass.md) — Wan!Pass。犬プロフィール連動フィルタ、証明書審査、QRチェックイン。
  - [`apps/itsumo-dog.md`](apps/itsumo-dog.md) — itsumo dog。こだわり条件多数、犬同伴バッジと利用マナーの分離提示。
  - [`apps/bringfido.md`](apps/bringfido.md) — BringFido。全施設電話一次確認とペット保証、骨マーク評価。
  - [`apps/dog-park-jp.md`](apps/dog-park-jp.md) — ドッグパークJP。地図/一覧2ボタン切替、スマートロック解錠。

## 調査対象一覧

グルメ発見系（成熟した地図・一覧・信頼性設計の参照元）: 食べログ／Retty／ホットペッパーグルメ／Googleマップ／サウナイキタイ

ペット・犬特化系（直接の競合・隣接サービス）: おでかけわんこ部／Wan!Pass（ワンパス）／itsumo dog（旧ドッグカフェ.jp）／BringFido／ドッグパークJP
