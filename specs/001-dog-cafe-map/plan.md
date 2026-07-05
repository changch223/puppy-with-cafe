# Implementation Plan: DokoWanCafe — 犬同伴OKカフェの地図検索

**Branch**: `001-dog-cafe-map` | **Date**: 2026-07-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-dog-cafe-map/spec.md`

## Summary

現在地を起点に「犬同伴OKなカフェ」を地図＋一覧＋距離で提示し、各カフェに可否ステータス（可/条件付き/不可/未確認）・出典・最終確認日を付与、出典間の矛盾を検出し、AI推測情報を区別する iOS アプリ。利用者はサインインのうえ誤りを報告・修正提案でき、v1は運営承認を経て反映する（AI自動スクリーニングは段階導入）。

技術方針: **SwiftUI 優先＋MapKit(MKMapView) を UIViewRepresentable で橋渡し**、**MVVM**、**iOS 16+**、バックエンドは**マネージドBaaS（Supabase: Postgres+PostGIS / Auth[Appleでサインイン]）**。犬同伴可否の初期データは**運営が手動整備（東京・数十件）**、外部集約は住所・座標の補助。オフラインは**直近取得データの端末キャッシュ**で閲覧可。運営コンソールは自作せず**Supabase 管理ダッシュボードを流用**。

## Technical Context

**Language/Version**: Swift 5.9+（Swift 6 対応を見据える）

**Primary Dependencies**: SwiftUI, UIKit（MapKit橋渡し用）, MapKit, CoreLocation, AuthenticationServices（Appleでサインイン）。バックエンド接続は URLSession ベースの内製ゲートウェイ（`Services/SupabaseGateway.swift`。当初案の supabase-swift SDK から変更 — 必要操作が RPC/select/insert/Auth の4つのみで、憲章V の依存最小化に基づき外部SDK依存ゼロとした）

**Storage**:
- サーバ: Supabase（PostgreSQL + PostGIS）— カフェ/出典/修正提案/矛盾
- 端末: 直近取得データのオフライン閲覧用の軽量ローカルキャッシュ（Codable スナップショットをディスク保存）／セッショントークンは Keychain

**Testing**: XCTest（コアロジックのユニットテスト中心）、主要フローの UI テスト（XCUITest）

**Target Platform**: iOS 16+（iPhone）

**Project Type**: モバイルアプリ（iOS クライアント）＋ マネージドBaaS（Supabase）。v1では自前サーバ実装なし。AI自動スクリーニングは後続で Supabase Edge Function として追加。

**Performance Goals**: 位置許可後〜周辺一覧表示 5秒以内（SC-001）／地図スクロール・ピン描画は 60fps を目標。

**Constraints**: 位置情報は「使用中のみ」／PrivacyInfo.xcprivacy（Privacy Manifest）遵守／オフライン時は直近キャッシュを鮮度明示で表示／利用者提案は運営承認まで反映しない。

**Scale/Scope**: MVPは東京。カフェ 数十〜数百件規模、個人開発（1名）。画面はおおよそ 5〜7（地図/一覧/詳細/報告/サインイン/設定・空状態）。

## Constitution Check

*GATE: Phase 0 前に通過必須。Phase 1 設計後に再評価。*

| 原則 | 判定 | 設計上の担保 |
|---|---|---|
| I. 信頼できるデータ（出典・鮮度・可否・矛盾・AI区別）🔒 | ✅ PASS | データモデルで `dog_policy`/`source`/`last_verified`/`provenance` を必須化。矛盾は `conflict` として検出、代表可否は FR-013 の決定論ルールで算出。AI由来は `provenance` で明示区別。 |
| II. 位置情報ファースト（現在地・距離） | ✅ PASS | 起動導線を現在地中心の地図＋距離つき一覧に。地図/一覧は同一データソース（Repository）を参照し乖離させない。 |
| III. プライバシー・バイ・デザイン | ✅ PASS | CoreLocation は WhenInUse。位置は端末内処理中心、サーバへは検索座標のみ送信し保存しない。Privacy Manifest を同梱。 |
| IV. データ品質を守る実用的テスト | ✅ PASS | 距離計算・フィルタ・名寄せ・矛盾解決を UI 非依存の純ロジックに分離し XCTest 必須。UI は主要フローのみ。 |
| V. SwiftUI優先・UIKit橋渡しの一貫UI | ✅ PASS | 画面は SwiftUI。地図のクラスタリング等は MKMapView を UIViewRepresentable で橋渡し（理由を明記）。過剰抽象化を避ける。 |
| VI. 日本語ファースト & ローカライズ可能性 | ✅ PASS | 文字列は String Catalog（Localizable）で一元管理、日本語第一。距離/日付はロケール表示。 |

**初期ゲート結果: PASS（違反なし）** → Phase 0 に進む。

## Project Structure

### Documentation (this feature)

```text
specs/001-dog-cafe-map/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── db-schema.md      # Supabase(Postgres) テーブル/ビュー/RLS
│   └── api-contracts.md  # クライアントが叩くデータ操作の契約
└── tasks.md             # /speckit-tasks で生成（本コマンドでは作らない）
```

### Source Code (repository root)

```text
DokoWanCafe/                      # Xcode プロジェクト（iOS アプリ）
├── DokoWanCafe/
│   ├── App/                      # App エントリ, ルーティング, DI
│   ├── Features/                 # 画面（MVVM: View + ViewModel）
│   │   ├── Map/                  #   地図（MKMapView 橋渡し + クラスタリング）
│   │   ├── CafeList/             #   一覧（距離順・フィルタ）
│   │   ├── CafeDetail/           #   詳細（可否/出典/確認日/矛盾/経路）
│   │   ├── Report/               #   誤り報告・修正提案（要サインイン）
│   │   └── Auth/                 #   Appleでサインイン
│   ├── Models/                   # Cafe, DogPolicy, Source, Conflict, Correction, UserLocation
│   ├── Services/                 # LocationService, CafeRepository, SupabaseGateway,
│   │                             #   AuthService, CacheStore（オフライン）, CorrectionService
│   ├── Core/                     # 純ロジック（テスト対象）
│   │   ├── DistanceCalculator    #   距離計算
│   │   ├── CafeDeduplicator      #   名寄せ（place_id / 名称+近接）
│   │   └── ConflictResolver      #   矛盾→代表可否（FR-013）
│   └── Resources/                # Localizable(String Catalog), Assets, PrivacyInfo.xcprivacy
├── DokoWanCafeTests/             # コアロジックのユニットテスト
└── DokoWanCafeUITests/           # 主要フローの UI テスト

supabase/                         # バックエンド定義（IaC 的にSQLを管理）
├── migrations/                   # テーブル/インデックス/RLS の SQL
└── seed/                         # 東京の種データ（手動整備）
```

**Structure Decision**: iOS 単一アプリ（MVVM）＋ Supabase 管理のバックエンド。自前サーバコードは持たず、DBスキーマ/RLS/種データを `supabase/` にSQLとして版管理する。純ロジック（距離・名寄せ・矛盾解決）を `Core/` に隔離し、憲章IVのテスト容易性を満たす。

## Complexity Tracking

> 憲章違反はないため記載事項なし。

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| （なし） | — | — |

## Phase 0 / Phase 1 成果物

- Phase 0: [research.md](./research.md) — 技術選定と根拠（バックエンド/地図/キャッシュ/認証/名寄せ/矛盾/データ取得/AI段階導入）。
- Phase 1: [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)。

## Post-Design Constitution Re-check

Phase 1 設計後の再評価: データモデル・契約・構造は原則 I〜VI を維持しており、**新たな違反・複雑性の正当化は不要（PASS）**。特に原則I（信頼性）はDBレベルで NOT NULL 制約・`provenance`・`conflict` ビューにより担保、原則III（プライバシー）は位置の非保存とPrivacy Manifestで担保。
