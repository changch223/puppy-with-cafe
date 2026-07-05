<!--
SYNC IMPACT REPORT
==================
Version change: (template) → 1.0.0
Bump rationale: 初回批准（プレースホルダ雛形から具体的な原則へ確定）。MAJOR=1 として制定。

Modified principles:
  - [PRINCIPLE_1] → I. 信頼できるデータ（出典・鮮度・可否ステータス）(NON-NEGOTIABLE)
  - [PRINCIPLE_2] → II. 位置情報ファーストのUX（現在地起点・距離の可視化）
  - [PRINCIPLE_3] → III. プライバシー・バイ・デザイン（位置情報の最小取得）
  - [PRINCIPLE_4] → IV. データ品質を守る実用的テスト
  - [PRINCIPLE_5] → V. SwiftUI優先・UIKit橋渡しの一貫したUI
  - (追加)        → VI. 日本語ファースト & ローカライズ可能性

Added sections:
  - 技術・プラットフォーム制約 (Technology & Platform Constraints)
  - 開発ワークフロー & 品質ゲート (Development Workflow & Quality Gates)

Removed sections: なし

Templates requiring updates:
  - .specify/templates/plan-template.md   ✅ 整合（Constitution Check は本ファイルを動的参照。変更不要）
  - .specify/templates/spec-template.md   ✅ 整合（原則名のハードコードなし。変更不要）
  - .specify/templates/tasks-template.md  ✅ 整合（原則名のハードコードなし。変更不要）

Deferred TODOs:
  - 最小対応OS(iOS 16+)、アーキテクチャ(MVVM)、テスト規律(実用的)は提案値。
    ユーザー確認後に変更があれば PATCH/MINOR で改訂すること。
-->

# DokoWanCafe Constitution

DokoWanCafe は「愛犬と一緒に入れるカフェ」を、現在地から地図で探せる iOS アプリである。
既存手段（ブログ・Google Map・SNS・食べログ・生成AI）は情報が散乱し、犬同伴可否や鮮度が
曖昧で、距離感も掴みにくい。本憲章は、この課題を解くために全ての設計・実装判断が従うべき
非交渉の原則を定める。

## Core Principles

### I. 信頼できるデータ（出典・鮮度・可否ステータス）(NON-NEGOTIABLE)

本アプリの価値は「正しく最新の犬同伴情報」にある。データ品質はいかなる機能追加よりも優先する。

- すべてのカフェ情報は **出典(source)** と **最終確認日(last-verified date)** を必須で保持する。
  出典・確認日を持たない情報は「未確認」として扱い、確定情報と同列に表示してはならない (MUST NOT)。
- 犬同伴可否は明示的なステータスで表現する: `allowed`（可） / `conditional`（条件付き:テラスのみ等） /
  `not_allowed`（不可） / `unverified`（未確認）。憶測で `allowed` にしてはならない (MUST NOT)。
- 複数出典（公式HP / SNS / Google Map / 食べログ / ブログ）を統合する際は、**矛盾を検出し**、
  ユーザーに出典と確認日を提示できること (MUST)。どれが最新・正しいかを利用者が判断できる状態を保つ。
- 生成AI・推測・自動抽出に由来する情報は、その旨をデータ上・UI上で明示し (MUST)、人手・公式確認済み情報と
  視覚的に区別する。「AIが不可と誤答する」問題を本アプリが再生産してはならない。

*根拠: 既存手段の最大のペインは「散乱・不正確・鮮度不明」。ここを守れなければ本アプリの存在意義がない。*

### II. 位置情報ファーストのUX（現在地起点・距離の可視化）

- 主要導線は **現在地を起点** とし、周辺の犬同伴OKカフェを地図と一覧で提示する (MUST)。
- 各カフェは **距離・おおよその所要** を一目で確認できること (MUST)。「距離感がわからない」ペインを直接解消する。
- 地図と一覧は同一データを反映し、状態が乖離しないこと (MUST)。
- 位置情報が取得できない場合も、手動での地域指定など **代替導線** を用意し機能不全に陥らせない (SHOULD)。

*根拠: 「行きたい場所周辺の距離感がわからない」が中核ペイン。現在地×地図×距離が体験の背骨。*

### III. プライバシー・バイ・デザイン（位置情報の最小取得）

- 位置情報は **「使用中のみ(When In Use)」を原則** とし、目的を明示して取得する (MUST)。常時取得は正当な理由なく要求しない (MUST NOT)。
- 位置情報の処理は可能な限り端末内で完結させ、外部送信・保存は必要最小限に留める (MUST)。目的外利用は禁止 (MUST NOT)。
- Apple のプライバシー要件（Privacy Manifest、権限用途の説明文言 `NS...UsageDescription`）を遵守する (MUST)。

*根拠: 位置情報は機微データ。信頼できるアプリであるためには、データ品質と同様に取り扱いの誠実さが不可欠。*

### IV. データ品質を守る実用的テスト

厳格な全面TDDは課さないが、**データの正確性・距離計算・可否判定に関わるロジックはテストで守る**。

- 距離計算、周辺検索/フィルタ、出典統合・矛盾検出、可否ステータス判定などの **コアロジックはユニットテスト必須** (MUST)。
- 上記コアロジックは UI から分離し、UI 非依存で単体テスト可能に設計する (MUST)。
- UI/画面遷移のテストは主要フロー（現在地→一覧→詳細）に限定してよい (MAY)。
- バグ修正時は再発防止の回帰テストを添える (SHOULD)。

*根拠: 本アプリの品質＝データ正確性。そこに直結するロジックだけは妥協せず自動検証する、費用対効果の高い方針。*

### V. SwiftUI優先・UIKit橋渡しの一貫したUI

- UI は **SwiftUI を第一選択** とする (MUST)。
- 地図の高度な制御（大量ピンのクラスタリング、カスタムアノテーション等）が必要な箇所に限り、
  `MKMapView` 等の UIKit を `UIViewRepresentable` で橋渡しする (MAY)。UIKit の使用は理由を明記する (MUST)。
- 依存は薄く保ち、YAGNI を守る。抽象化・ライブラリ導入は具体的な必要が生じてから行う (SHOULD)。

*根拠: 地図中心アプリでは SwiftUI 単独では届かない制御があるため併用を前提にしつつ、複雑さの無秩序な増加を防ぐ。*

### VI. 日本語ファースト & ローカライズ可能性

- ユーザー向け文字列を **コードにハードコードしない** (MUST)。`Localizable`（String Catalog 等）で一元管理する。
- 第一言語は **日本語**。将来の英語対応を妨げない構造を保つ (SHOULD)。
- 日付・距離・数値はロケールに従って表示する (SHOULD)。

*根拠: 主対象は国内の愛犬家。まず日本語体験を最良にしつつ、後の多言語展開の扉を閉じない。*

## 技術・プラットフォーム制約 (Technology & Platform Constraints)

- **プラットフォーム**: iOS（最小対応 **iOS 16+** を既定とする。確定はユーザー承認による）。
- **言語**: Swift（最新安定版）。
- **UI**: SwiftUI（第一選択）＋ 必要箇所のみ UIKit 併用（原則 II/V に従う）。
- **地図**: MapKit（`Map` / `MKMapView`）と CoreLocation。
- **アーキテクチャ**: **MVVM** を既定とする。ビジネスロジック（位置・検索・フィルタ・出典統合）は ViewModel/サービス層に集約し、
  View から分離する。過剰な抽象化は避ける（原則 V）。
- **依存管理**: Swift Package Manager (SwiftPM) を優先。
- **データモデル要件**: カフェ等のエンティティは最低限、`source`（出典。複数可）、`lastVerified`（最終確認日）、
  `dogPolicy`（`allowed`/`conditional`/`not_allowed`/`unverified`）、`provenance`（人手確認 / AI推測 等）を表現できること (MUST)。
- 外部APIやスクレイピングを用いる場合、各出典の利用規約・レート制限・鮮度を尊重する (MUST)。

## 開発ワークフロー & 品質ゲート (Development Workflow & Quality Gates)

- 本プロジェクトは **Spec-Driven Development** に従う: `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` →
  `/speckit-implement`（必要に応じ `/speckit-clarify`・`/speckit-analyze`）。
- すべての `plan.md` は着手前に **Constitution Check** を通過すること。原則違反は
  `Complexity Tracking` で正当化できない限り却下する (MUST)。
- 各機能は独立してテスト可能な単位（ユーザーストーリー）で届ける。MVP を最優先で成立させる (SHOULD)。
- コミット/変更は原則 IV のテストと、原則 I のデータ整合（出典・確認日・可否ステータス）を満たすこと (MUST)。
- 変更は小さく、各タスク完了ごとにコミットする (SHOULD)。

## Governance

- 本憲章はプロジェクトの他の慣行に優先する。原則と実装が矛盾した場合、憲章を正とし実装を是正する。
- **改訂手続き**: 変更は本ファイルへの記載・バージョン改訂・影響範囲（テンプレート/ドキュメント）の同期をもって成立する。
- **バージョニング方針（セマンティックバージョニング）**:
  - MAJOR: 原則の削除・後方非互換な再定義・ガバナンスの根本変更。
  - MINOR: 原則/セクションの追加、または指針の実質的拡張。
  - PATCH: 文言の明確化・軽微な修正（意味を変えないもの）。
- **コンプライアンス確認**: すべての `/speckit-plan` および実装レビューは本憲章への適合を検証する。
  特に原則 I（データ信頼性）と原則 III（プライバシー）への適合を必須ゲートとする (MUST)。
- 提案値（iOS 16+ / MVVM / 実用的テスト）はユーザー承認で確定。以後の変更は上記バージョニングに従う。

**Version**: 1.0.0 | **Ratified**: 2026-07-04 | **Last Amended**: 2026-07-04
