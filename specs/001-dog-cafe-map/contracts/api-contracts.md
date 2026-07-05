# Contract: Client ↔ Backend Operations

iOS クライアントが Supabase に対して行う操作の契約（入出力の形）。トランスポートは Supabase SDK（PostgREST / RPC / Auth）。UIは MVVM の Service 層からのみ呼ぶ。

## 1. 周辺カフェ検索（FR-001/002/004/005）
- **Operation**: RPC `nearby_cafes(lat, lng, radius_m, only_dog_ok)`
- **Input**: `lat: Double`, `lng: Double`, `radius_m: Int`（既定 例:3000）, `only_dog_ok: Bool`
- **Output**: `[{ cafe: Cafe, distance_m: Double }]`（距離昇順）
- **Client責務**: 距離の表示整形（m/km, ロケール）、可否フィルタUI、地図/一覧で同一結果を共有（乖離させない, FR-003）。
- **Errors**: 通信不可 → キャッシュ表示（FR-029）＋鮮度提示。0件 → 空状態＋範囲拡大導線（FR-020）。

## 2. カフェ詳細取得（FR-006/007/008/011/012/014）
- **Operation**: `select` cafe by id ＋ 関連 `sources` ＋ `cafe_conflicts`
- **Output**: `Cafe`（代表可否/条件/最終確認日/has_conflict）＋ `[Source]`（type/reference/claimed_status/verified_at/provenance）
- **Client責務**: 可否ステータス表示、条件付きの条件提示、出典・確認日併記、矛盾がある場合の提示、`provenance = ai_inferred` の明示区別、最終確認日が古い場合の警告（FR-010）。

## 3. 経路案内（FR-015）
- **Operation**: 外部地図アプリ起動（バックエンド不要）。`MKMapItem.openMaps` 等で当該座標を目的地に。

## 4. 認証（FR-028, R4）
- **Operation**: Sign in with Apple → Supabase Auth（OIDC 連携）
- **Trigger**: 投稿導線に入ったとき（閲覧では要求しない）。未サインインはサインインへ誘導。
- **Output**: セッション（Keychain 保存）。`auth.uid()` が以降の `corrections.submitter_id`。

## 5. 修正提案の送信（FR-023/024/028）
- **Operation**: `insert into corrections`（認証必須, RLS で `submitter_id = auth.uid()`）
- **Input**: `cafe_id`, `proposed_status?`, `proposed_condition?`, `note?`
- **Output**: 受理された `Correction`（`status = pending`）
- **不変条件**: 送信直後は表示に反映されない（運営承認まで, FR-024）。

## 6. モデレーション（運営, FR-024/026/027, R9）
- **v1**: Supabase ダッシュボード上で `corrections.status` を `applied`/`rejected` に更新（アプリ内管理画面は作らない）。`applied` 時に cafe/source を更新し由来・確認日を記録。
- **第2段階**: Edge Function で AI 一次判定（`ai_review` 記録, `status=ai_checked`）→ 運営最終承認。

## データ形（クライアント Codable の指針）
- `DogPolicyStatus`, `SourceType`, `Provenance`, `CorrectionStatus`, `SubmitterType` は enum（`data-model.md` の列挙型に一致）。
- `Cafe` はサーバ行に加え、クライアントで算出する `distanceMeters`（保存しない）と、キャッシュ由来時の `fetchedAt`/`isStale` を保持。

## 契約テスト観点（憲章IV）
- `nearby_cafes` が半径・`only_dog_ok`・距離昇順を満たす（登録データに対し表示漏れなし, SC-005）。
- 未サインインで `corrections` insert が RLS で拒否される。
- `rejected`/`pending` の提案が詳細に反映されない（SC-008）。
- `provenance=ai_inferred` がクライアントで区別表示される（SC-004）。
