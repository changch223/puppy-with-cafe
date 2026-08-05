# Googleマップ UI/UX調査
- 調査日: 2026-08-05 / 調査者: AI（Claude subagent）

## 概要とターゲット（運営・プラットフォーム・規模感）
- 運営元はGoogle。iOS/Androidの両OSで提供され、App Store説明文では「Google Mapsは信頼を持って世界を探索・移動するためのアプリ」と位置づけられ、ライブ交通情報付きのリアルタイムGPSナビ（車・徒歩・自転車・公共交通）と、写真・レビュー・有用情報を伴う2億5,000万件以上のビジネス・場所の発見を核心機能として掲げている（[Google Maps - App Store](https://apps.apple.com/us/app/google-maps/id585027354)）。
- App Store掲載文では「5億人のユーザーが貢献するコンテンツで自信を持って探索できる」ことも訴求ポイントとして明記されており、UGC（口コミ・写真）の規模そのものを信頼の根拠として提示している（同上）。
- ターゲットは地図・移動を必要とするあらゆる一般消費者で、飲食店探し（DokoWanCafeと近い用途）はその一部門にすぎない。したがって地図・ナビ・交通・ビジネス発見が一体化した「万能型」アプリであり、犬同伴カフェのような特定ニッチに特化した設計にはなっていない点が構造的な違いとして挙げられる（推測: 汎用ゆえに特定ニーズ向けフィルタの整備は後回しになりやすい）。
- Places API/Places UI Kitという開発者向けコンポーネント群が別途提供されており、Googleの場所詳細UI（名称・住所・電話番号・ウェブサイト・営業時間・口コミ等を表示する「Place Details」コンポーネント）を自社アプリに低コードで組み込める仕組みが用意されている。レイアウトは「Compact（要点のみのプレビュー）」と「Full（全項目を表示する包括的レイアウト）」の2種が公式に定義されている（[Places UI Kit | Google Maps Platform](https://mapsplatform.google.com/maps-products/places-ui-kit/)、[What is Places UI Kit and how can you use it | Google for Developers](https://developers.google.com/maps/architecture/places-ui-kit-getting-started)）。この「Compact/Full」という2段階の情報密度設計は、Google自身が場所詳細UIの標準パターンとして体系化している点で興味深い。

## 主要フロー（起動→探す→詳細→行動、の流れ）
- 起動後は検索窓またはカテゴリ提案からの起点が基本で、キーワード検索・カテゴリボタン（レストラン、カフェ等）・地図上の直接タップのいずれからも場所探索に入れる（[Search locations on Google Maps - Google Maps Help](https://support.google.com/maps/answer/3092445?hl=en)）。
- レストラン等のカテゴリ検索では、価格・評価・営業時間・料理ジャンルなどのフィルタが検索結果画面上部に表示され、絞り込み後にリスト（またはピン付き地図）で候補を確認する流れになる（[App Store掲載文](https://apps.apple.com/us/app/google-maps/id585027354)、[Search locations on Google Maps](https://support.google.com/maps/answer/3092445?hl=en)）。
- 場所を選ぶと詳細画面（プレースページ）に遷移し、写真・評価・レビュー・営業時間・混雑状況などを確認した上で、経路案内・電話・ウェブサイト・保存などの行動に進む、という「探す→比較する→行動する」の直線的なフローが基本形になっている（[App Store掲載文](https://apps.apple.com/us/app/google-maps/id585027354)）。
- 近年はAIによる要約・提案機能が強化されており、「ユーザーの現在の状況を理解し、制約条件で選択肢を絞り込み、ナビゲーション・到着・駐車といった実際の行動に推薦をつなげる」というAI活用がUXの方向性として語られている（[[Insights]What Google Maps' AI Update Suggests About UX Design in the AI Era - Medium](https://inseok.medium.com/insights-what-google-maps-ai-update-suggests-about-ux-design-in-the-ai-era-9e7ada6d32e8)、一次情報が限定的なため要旨の推測を含む）。
- 2025年5月にはiOS版に「スクリーンショットから場所を認識して保存する」機能が追加された。ユーザーが撮った他アプリのスクリーンショット（SNSの投稿など）をGoogle Mapsが解析し、写っている場所を「You」タブ内の「Screenshots」リストへ自動保存する導線で、外部での発見から自アプリへの回遊を促す設計になっている（[Google Maps Can Now Scan Your iPhone Screenshots for Places - MacRumors](https://www.macrumors.com/2025/05/08/google-maps-scan-screenshots-for-places/)、[9to5google](https://9to5google.com/2025/05/07/google-maps-screenshots-iphone/)）。

## 地図・一覧・検索フィルタのUIパターン
- レストラン検索では価格・評価・営業時間・料理ジャンルのフィルタが提供され、Android版では「More Filters」から複数条件を選んで「Apply」で適用する操作が案内されている（[Google Maps Help: Search locations](https://support.google.com/maps/answer/3092445?hl=en)）。ヴィーガン・ハラル・グルテンフリーといった食事制限に対応したフィルタも用意されている（検索結果の要約より）。
- 2026年時点では「Near me」「Halfway（待ち合わせの中間地点）」「Near destination」「Open Now」といったアイコン形式のフィルタがテストされていると報じられており、単なる場所検索から「複数人の移動を前提にした検索」へと機能が拡張されつつある（[Google Maps testing controversial changes - Yahoo Tech](https://tech.yahoo.com/ai/gemini/articles/google-maps-testing-controversial-changes-144000750.html)、テスト機能につき将来変更されうる）。
- 一方で、Googleマップコミュニティのユーザーフィードバックでは「すべての場所を対象にした横断的な『ペット同伴可（pet friendly）』フィルタが欲しい」という要望スレッドが複数存在し（[Filter for pets allowed - Google Maps Community](https://support.google.com/maps/thread/185356262/filter-for-pets-allowed-in-google-maps?hl=en)、[Can you add a filter "pet friendly" - Google Maps Community](https://support.google.com/maps/thread/179222377/can-you-add-a-filter-pet-friendly-on-all-places-in-google-maps?hl=en)、[Hotel pets allowed filter - Google Maps Community](https://support.google.com/maps/thread/258142375/hotel-pets-allowed-filter?hl=en)、[No option for 'dog-friendly' in Features section - Google Maps Community](https://support.google.com/maps/thread/209225954/no-option-for-dog-friendly-in-features-section?hl=en)）、2026年時点でも「犬同伴可」を軸にした専用の検索フィルタは標準搭載されていないとみられる（複数スレッドの存在から強く推測されるが、Google公式の機能一覧での明示的な否定確認はできていない＝未確認）。ユーザーは代わりに「pet-friendly restaurants」のようなキーワード検索や、個別の場所詳細ページ内の「About」セクションにある「Dogs Allowed」属性を目視確認する、という回避策に頼っている（[How to Find Pet-Friendly Restaurants Using Google Maps Data - Outscraper](https://outscraper.com/how-to-find-pet-friendly-restaurants-google-maps/)）。
- 地図表示とリスト表示の明確な切替UIについては、本調査で参照した一次資料（Googleヘルプ記事）内に詳細な言及がなく、具体的なレイアウト仕様は未確認（一般的なGoogleマップの使用経験としては地図画面下部にリスト形式のカード一覧が引き出せる構成が広く知られているが、本調査の情報源からは裏付けが取れなかった）。

## 詳細画面の情報設計（何をどの順で見せるか）
- 公式のPlaces UI Kitドキュメントによれば、「Place Details」コンポーネントは名称・住所・電話番号・ウェブサイト・営業時間・口コミ（user reviews）を表示するとされ、これがGoogleが定義する場所詳細情報の標準項目セットである（[Places UI Kit | Google Maps Platform](https://mapsplatform.google.com/maps-products/places-ui-kit/)）。
- レイアウトは「Compact（プレビュー用の要点表示）」と「Full（全詳細を表示する包括的レイアウト）」の2バリアントが提供されており、地図ピンをタップした際の簡易カードと、そこから遷移するフル詳細ページという2段階の情報開示設計がAPIレベルでも公式に定義されている（[What is Places UI Kit and how can you use it | Google for Developers](https://developers.google.com/maps/architecture/places-ui-kit-getting-started)）。
- Reviews（口コミ）はスター評価・写真・テキストを伴うタブとして提供される（[How Google Maps reviews actually work - wiserreview](https://wiserreview.com/blog/google-maps-reviews/)）。
- 近年はAIによる要約がプレースページの複数階層に導入されている。(1) 場所全体の性格を100文字程度で要約する「AI-powered place summaries」、(2) 大量の口コミからテーマ・感情を集約する「AI-powered review summaries」（記事内では「知っておくべきこと」的な見出しでの提示とされる）、(3) メニュータブの先頭に表示される「AI-generated menu summaries」の3種類が確認できる（[Discover more, faster: AI-powered summaries - Google Maps Platform](https://mapsplatform.google.com/resources/blog/discover-more-faster-ai-powered-summaries-for-places-areas-and-reviews-are-now-generally-available/)、[Google Testing AI-Generated Menu Summaries - DAC](https://www.dacgroup.com/insights/local-search-news/google-testing-ai-generated-menu-summaries-in-search-and-maps/)、[AI-powered review summaries | Places API](https://developers.google.com/maps/documentation/places/web-service/review-summaries)）。大量の非構造化口コミ・写真をAI要約で圧縮し、ユーザーが読む前に「要点」を提示する設計思想がうかがえる。
- 「Popular times（人気の時間帯）」機能により、時間帯別の混雑予測に加え、現在の実際の混雑度を典型的な混雑度と比較して示す「ライブ混雑状況」も提供される（[I stopped trusting star ratings - Android Police](https://www.androidpolice.com/stopped-trusting-star-ratings-how-i-judge-place-on-google-maps/)）。詳細ページのどの位置に配置されるかについて一次資料での明確な記載は確認できなかった（未確認）。

## 写真・ビジュアルの見せ方
- 「最近アップロードされた訪問者の写真」を優先的に確認することで、プロモーション用の演出写真ではなく実際の現状を把握できる、というユーザー行動がレビュー記事で紹介されている（[I stopped trusting star ratings - Android Police](https://www.androidpolice.com/stopped-trusting-star-ratings-how-i-judge-place-on-google-maps/)）。すなわちGoogleマップの写真群にはビジネス投稿とユーザー投稿の両方が混在し、後者（ユーザー撮影）が「鮮度・信頼性の判断材料」として重視される構造になっていることが示唆される。
- 写真の並び順は「Maps上では画像サイズ・シャープネスなど画質を基準に決定される」のに対し、Google Business Profile（事業者向け管理画面）上では投稿の新しさ（recency）を基準に決定される、と使い分けが説明されている（品質基準の一次資料は本調査で直接確認できず、開発者向けドキュメント検索結果の要約に基づく＝要確認）。
- 前述のiOS向け「スクリーンショットから場所を保存」機能は、SNS等で見かけた場所の写真・投稿を起点にGoogleマップへ場所情報を取り込む導線であり、写真（外部コンテンツ含む）を「発見のきっかけ」として明確に位置づけている（[MacRumors](https://www.macrumors.com/2025/05/08/google-maps-scan-screenshots-for-places/)）。

## 信頼性・情報鮮度の見せ方（出典・確認日・口コミの扱い）
- レビュー記事では「星評価だけに頼らない」ことが推奨されており、具体的には (1) 繰り返し出てくる苦情・共通の賞賛パターンを探す、(2) 事業者がレビューに専門的に返信しているかを見る、(3) AI要約（「知っておくべきこと」的なセクション）で数百件の口コミの主要テーマを素早く把握する、(4) 最近アップロードされた訪問者写真で実態を確認する、(5) 「人気の時間帯」で混雑を予測する、(6) ストリートビューで周辺環境・入口位置を事前確認する、という複合的な判断法が紹介されている（[I stopped trusting star ratings - Android Police](https://www.androidpolice.com/stopped-trusting-star-ratings-how-i-judge-place-on-google-maps/)）。これは裏を返せば、Googleマップの星評価単体は必ずしも信頼性の担保として機能しておらず、ユーザー側が複数のシグナルを組み合わせて自衛的に判断する必要がある、という運用上の課題を示している（推測を含む）。
- サインインしていないユーザーは、周辺のおすすめ、ユーザー写真、住所、営業時間、電話番号、人気の時間帯、レストランのメニューなど多くの情報を閲覧できないという制限がテストされていると報じられている（[Google Maps tests hiding reviews and images unless you sign in - Digital Trends](https://www.digitaltrends.com/computing/google-maps-tests-hiding-reviews-and-images-unless-you-sign-in/)、テスト段階の報道であり恒久仕様かは未確認）。
- 「確認日」のような明示的な情報鮮度表示（この情報はいつ時点のものかを一目で示すUI）についての一次情報は本調査では見つからなかった（未確認）。口コミは投稿日時とともに時系列表示される一般的な口コミサイトの慣行に依拠していると推測される。犬同伴可否のような「変化しうる事実情報」を第三者が信頼して使うための明示的な鮮度・出典表示は、Googleマップの標準UIには存在しない、という点はDokoWanCafeとの重要な対比になる。

## 行動喚起（経路・予約・電話・保存/お気に入り等）
- 場所詳細画面からのCTAとして「経路」（リアルタイムGPSナビ、車・徒歩・自転車・公共交通に対応）、「電話」「ウェブサイト」に加え、「注文（デリバリー・テイクアウト）」「宿泊予約」といった外部サービス連携ボタンが用意されている（[App Store掲載文](https://apps.apple.com/us/app/google-maps/id585027354)）。
- 「場所について質問する（料理から駐車場まで）」というQ&A的な機能もCTAの一つとして案内されている（同上）。
- 保存機能は「You」タブに集約されており、検索・ナビ・閲覧した「最近の場所（recent places）」から選んで保存でき、複数の場所を一括選択してリストへ追加することも可能。既存リストへの追加・新規リスト作成のどちらにも対応し、保存した場所（リスト）は他ユーザーへ共有できる（[Find your places & lists in the You tab - Google Maps Help](https://support.google.com/maps/answer/9948049?hl=en)）。またタイムライン機能により訪問履歴へのアクセス、直近保存・近くの保存済み場所へのショートカット表示も提供される（同上）。
- App Store掲載文では「お気に入りの保存済み場所でカスタムリストを作成できる」ことが明記の特徴として挙げられ、オフライン地図対応もセットで訴求されている（[App Store掲載文](https://apps.apple.com/us/app/google-maps/id585027354)）。

## 特徴的なUXパターン・差別化ポイント
- 「Compact/Full」という2段階の情報密度をAPIレベルで公式に体系化している点が特徴的。地図タップ直後は要点のみのミニカード、詳細画面遷移後にフル情報、という段階的開示（progressive disclosure）が製品設計の原則として明文化されている（[Places UI Kit](https://mapsplatform.google.com/maps-products/places-ui-kit/)）。
- 大量の非構造化データ（数百〜数千件規模のレビュー・写真）を抱えるがゆえに、AI要約（場所要約・レビュー要約・メニュー要約）で「読む前に要点を提示する」方向にUXを進化させている点が2025〜2026年の顕著な傾向（[Discover more, faster - Google Maps Platform](https://mapsplatform.google.com/resources/blog/discover-more-faster-ai-powered-summaries-for-places-areas-and-reviews-are-now-generally-available/)）。膨大な情報量ゆえの「情報過多を要約で圧縮する」課題対応と言える。
- 汎用地図アプリであるがゆえに、特定ニッチ（ペット同伴可否など）の専用フィルタは公式には整備されておらず、コミュニティで継続的に要望が上がり続けている状態（[Google Maps Community各種スレッド](https://support.google.com/maps/thread/179222377/can-you-add-a-filter-pet-friendly-on-all-places-in-google-maps?hl=en)）。「About」セクション内の属性（Dogs Allowed等）としては情報を保持しているが、それを軸にした横断検索・フィルタ体験は用意されていない＝属性データはあるが発見導線が弱い、という非対称な状態が特徴。
- 星評価という単一指標に対するユーザー側の不信（記事タイトルが「星評価を信じるのをやめた」であること自体が象徴的）があり、複合的なシグナル（AI要約・最新写真・混雑状況・返信姿勢）を自分で組み合わせて判断する「ユーザー側の情報リテラシーに依存した信頼性担保」になっている（[Android Police](https://www.androidpolice.com/stopped-trusting-star-ratings-how-i-judge-place-on-google-maps/)）。

## Puppy With Cafe への示唆
- Googleマップには「Dogs Allowed」属性データ自体は存在するが、それを軸にした横断フィルタ・検索導線が用意されておらず、複数年にわたりコミュニティで要望が出続けている（未解決のギャップ）。Puppy With Cafeが「犬同伴可否」を検索・フィルタの第一級の軸として最初から地図UIに組み込むことは、Googleマップが埋めていない明確な需要に対する差別化になる。
- Googleマップの「Compact（地図ピンの簡易カード）→Full（詳細ページ）」という2段階の情報開示パターンは、DokoWanCafeの「地図ピン→詳細シート」の設計にも応用できる。簡易カード段階では「犬可否バッジ＋営業中バッジ」など最重要情報のみに絞り、詳細画面で出典・確認日・犬向け設備などのフル情報を出す、という優先順位付けの参考になる。
- Googleマップでは星評価という単一指標への不信が根強く、ユーザーは複数シグナル（最新写真・返信姿勢・AI要約・混雑状況）を自分で組み合わせて判断せざるを得ない状態にある。Puppy With Cafeは「allowed/conditional/not_allowed/unverified」という事実ベースの区分＋出典・確認日の明示（憲章の由来提示原則）を貫くことで、星評価型の信頼性論争を構造的に回避できる立場にある。この差別化を詳細画面のUIでも明確に前面化する価値がある（例: 「Googleの評価では分からない『犬可否の一次情報』」という訴求）。
- Googleマップの「情報鮮度」表示は口コミの投稿日時に依存するのみで、犬同伴可否のような変化しうる事実情報に特化した「確認日」表示は標準搭載されていない。Puppy With Cafeが確認日をバッジ等で常時可視化する設計は、Googleマップに対する明確な差別化ポイントとして訴求材料になる。
- Googleマップの保存機能（You タブでの複数リスト管理・共有）は、犬連れの外出計画（「今度行きたい犬カフェ」等）というユースケースに直接転用できる発想源になる。ただしDokoWanCafeはサインインなし方針のため、アカウント同期を伴わない端末ローカルの簡易リスト機能として小規模に検討する余地がある。
- AI要約による「大量レビューの圧縮提示」というGoogleの方向性は、Puppy With Cafeの規模（データ件数）では過剰投資になりうる。むしろ逆に、Googleマップが苦手とする「少数だが正確な一次情報（由来・確認日付きの犬可否事実）」を簡潔なバッジ・短文で見せる、という「量より正確性」の方向性を貫くことが、AI要約時代における差別化として有効と考えられる。

## 出典
- [Google Maps - App Store](https://apps.apple.com/us/app/google-maps/id585027354)
- [Places UI Kit | Google Maps Platform](https://mapsplatform.google.com/maps-products/places-ui-kit/)
- [What is Places UI Kit and how can you use it to build engaging solutions? | Google for Developers](https://developers.google.com/maps/architecture/places-ui-kit-getting-started)
- [Introducing Places UI Kit: A low-code way to display Google's Places content - Google Maps Platform](https://mapsplatform.google.com/resources/blog/introducing-places-ui-kit-a-low-code-way-to-display-googles-places-content-on-your-map-of-choice/)
- [[Insights]What Google Maps' AI Update Suggests About UX Design in the AI Era - Medium](https://inseok.medium.com/insights-what-google-maps-ai-update-suggests-about-ux-design-in-the-ai-era-9e7ada6d32e8)
- [I stopped trusting star ratings: Here's how I judge a place on Google Maps - Android Police](https://www.androidpolice.com/stopped-trusting-star-ratings-how-i-judge-place-on-google-maps/)
- [Search locations on Google Maps - Android - Google Maps Help](https://support.google.com/maps/answer/3092445?hl=en)
- [Find your places & lists in the You tab - Google Maps Help](https://support.google.com/maps/answer/9948049?hl=en)
- [Google Maps tests hiding reviews and images unless you sign in - Digital Trends](https://www.digitaltrends.com/computing/google-maps-tests-hiding-reviews-and-images-unless-you-sign-in/)
- [Google Maps testing controversial changes - Yahoo Tech](https://tech.yahoo.com/ai/gemini/articles/google-maps-testing-controversial-changes-144000750.html)
- [How to Find Pet-Friendly Restaurants Using Google Maps Data - Outscraper](https://outscraper.com/how-to-find-pet-friendly-restaurants-google-maps/)
- [Filter for pets allowed in Google maps - Google Maps Community](https://support.google.com/maps/thread/185356262/filter-for-pets-allowed-in-google-maps?hl=en)
- [Can you add a filter "pet friendly" on all places in Google Maps? - Google Maps Community](https://support.google.com/maps/thread/179222377/can-you-add-a-filter-pet-friendly-on-all-places-in-google-maps?hl=en)
- [Hotel pets allowed filter - Google Maps Community](https://support.google.com/maps/thread/258142375/hotel-pets-allowed-filter?hl=en)
- [No option for 'dog-friendly' in Features section - Google Maps Community](https://support.google.com/maps/thread/209225954/no-option-for-dog-friendly-in-features-section?hl=en)
- [Google Maps Can Now Scan Your iPhone Screenshots for Places - MacRumors](https://www.macrumors.com/2025/05/08/google-maps-scan-screenshots-for-places/)
- [Google Maps for iOS uses Gemini to pull places from screenshots - AppleInsider](https://appleinsider.com/articles/25/05/08/google-maps-for-ios-uses-gemini-to-pull-places-from-screenshots)
- [Google Maps can save locations found on your screenshots in a dedicated list - 9to5google](https://9to5google.com/2025/05/07/google-maps-screenshots-iphone/)
- [Discover more, faster: AI-powered summaries for places, areas, and reviews are now Generally Available - Google Maps Platform](https://mapsplatform.google.com/resources/blog/discover-more-faster-ai-powered-summaries-for-places-areas-and-reviews-are-now-generally-available/)
- [AI-powered review summaries | Places API | Google for Developers](https://developers.google.com/maps/documentation/places/web-service/review-summaries)
- [Google Testing AI-Generated Menu Summaries in Search and Maps | DAC](https://www.dacgroup.com/insights/local-search-news/google-testing-ai-generated-menu-summaries-in-search-and-maps/)
- [How Google Maps reviews actually work (2026 guide) - wiserreview](https://wiserreview.com/blog/google-maps-reviews/)
