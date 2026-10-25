# ツメショー

1問1分の詰将棋を、ショート動画のように縦スワイプで次々に解く iOS アプリです。
駒をタップすると動けるマスが光るので、将棋のルールを知らなくても遊べます。

- 最初の画面で盤の大きさ（9×9 の普通の盤か、玉のまわりの 5×5）を選んで始めます。選び直すときは問題画面の「トップ」から戻ります
- 1問目は操作を順に案内するチュートリアル用の例題です。2問目からはアプリがその場で問題を作るので、ずっと続きます
- 1手詰めと3手詰めが出ます。3手詰めでは、玉方がアプリ側で自動的に応じます
- ヒントは2段階：1回目で王手をかけられる駒、2回目で正解の駒と行き先が光ります
- 間違えると盤が指す前に戻り、正解の駒と行き先が緑の枠で光ります

## 必要なもの

- macOS 26.6 以降の Mac
- Xcode 27 以降（App Store から）
- XcodeGen（`brew install xcodegen`）
- iOS 17 以降の iPhone（実機に入れる場合）

## セットアップ

```sh
ghq get https://github.com/koji18/test_spajam_tumesho.git
cd ~/ghq/github.com/koji18/test_spajam_tumesho

# 初回だけ：開発ツールを Xcode に切り替えて、ライセンスに同意する
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -license accept

# 初回だけ：自分用のビルド設定を作る（中身は「iPhone に入れる」で書く）
cp Config/Local.xcconfig.example Config/Local.xcconfig

# Xcode のプロジェクトを生成して開く
xcodegen generate
open Tsumesho.xcodeproj
```

`Tsumesho.xcodeproj` は git に入れていません。`project.yml` から各自が生成します。ファイルを足したり設定を変えたりしたら、`project.yml` を直して `xcodegen generate` を実行してください。Xcode の画面で変えた設定は、次に生成し直すと消えます。`git pull` のあとも `xcodegen generate` を実行してください。

### 正解演出の試作

駒の移動と着地、3・5・10連勝で変わる振動、スコアへ飛ぶ金色の粒、昇段バッジ、最後の一手から広がる Metal の波紋を追加しています。
問題画面の歯車 →「設定」→「演出を試す」で、成績を変えずに連勝・昇段・スコア獲得の演出を確認できます。
振動のオン・オフと効果音の音量を設定できます。効果音はマナーモードを尊重し、振動の確認には対応する実機の iPhone が必要です。「視差効果を減らす」がオンの場合は、移動・波紋・粒・バッジ回転を抑えます。

`missing Metal Toolchain` と出た場合は、Xcode 公式の追加コンポーネントを一度インストールしてください。

```sh
xcodebuild -downloadComponent MetalToolchain
```

Python で生成した仮の効果音と生成スクリプトは削除しています。効果音は main 由来の詰み音と選択音を使用します。

ネオンの背景と段位バッジは iPhone の傾きに反応します。アプリを開いたときの持ち方を基準に、左右・前後へ20度ほど傾けると光と反射が動きます。昇段プレビューの大きなバッジも反応します。「視差効果を減らす」がオンの場合とバックグラウンドではセンサーを停止します。

ビルド設定は2つのファイルに分けています。

- `Config/Base.xcconfig`：全員共通の値（git に入れる）
- `Config/Local.xcconfig`：Team ID など人ごとに違う値（git に入れない）。`Base.xcconfig` の値を上書きします

## iPhone に入れる

### Mac 側

1. Xcode で TARGETS の「Tsumesho」→「Signing & Capabilities」を開く
2. 「Team」で「Add Account…」から自分の Apple ID でサインインし、「（自分の名前）(Personal Team)」を選ぶ
3. 手順 2 のあと、Build Settings の「Development Team」に出る10桁の Team ID を、`Config/Local.xcconfig` の `DEVELOPMENT_TEAM` に書く
   - 「Bundle ID がすでに使われています」と出たら、同じファイルに `PRODUCT_BUNDLE_IDENTIFIER = com.yourname.tsumesho` のように自分用の ID を書く（英数字・ハイフン・ピリオドだけ。日本語は使えません）
4. `xcodegen generate` を実行し直す（手順 2 で Xcode の画面から選んだ Team は、ここで消えて `Local.xcconfig` の値に置き換わります）
5. iPhone を USB でつなぎ、Xcode の上部で iPhone を選んで ▶ で実行する

### iPhone 側（初回だけ）

1. Mac につないで「このコンピュータを信頼」→ パスコード
2. 「設定 → プライバシーとセキュリティ → デベロッパモード」をオン（再起動が入ります）
3. アプリを入れたら「設定 → 一般 → VPNとデバイス管理」で自分の Apple ID を「信頼」

無料の Apple ID で入れたアプリは **7日で起動できなくなります**。発表の前日か当日の朝に入れ直してください。

### コマンドラインから入れる場合

```sh
xcrun devicectl list devices   # iPhone の Identifier を調べる
xcodebuild -project Tsumesho.xcodeproj -scheme Tsumesho -configuration Release \
  -destination "id=<Identifier>" -derivedDataPath build -allowProvisioningUpdates build
xcrun devicectl device install app --device <Identifier> build/Build/Products/Release-iphoneos/Tsumesho.app
```

Release 版はコードがアプリに入るので、ネットにつながっていなくても動きます。

## 構成

```
Tsumesho/
  Engine/Shogi.swift      ルールエンジン（合法手の生成・詰みの探索）。UI に依存しない
  Engine/Generator.swift  問題の自動生成（5×5 用と 9×9 用）
  Engine/Problem.swift    問題の型と、1問目の例題
  Feed.swift              問題の列。裏で数問先まで作り置きする
  Game.swift              1問ぶんの遊びの状態と、連続正解数
  Theme.swift             色とフォント
  TsumeshoApp.swift       最初の画面と、縦スワイプのフィードの切り替え
  Views/                  画面（最初の画面・問題・盤）
TsumeshoTests/            アプリ側の単体テスト（Swift Testing）
Tools/
  test.sh                 エンジンと問題の生成のテスト
Config/
  Base.xcconfig           全員共通のビルド設定（Bundle ID など）
  Local.xcconfig.example  人ごとの設定のひな形。Local.xcconfig にコピーして使う
project.yml               XcodeGen の設定
```

盤の配列は常に 9×9 で持ちます。5×5・7×7 の盤では、右上の隅（1〜5 筋 × 一〜五段など）だけを盤とし、その外へは攻め方も玉方も動けません（見えている縁が盤の端）。

## テスト

```sh
Tools/test.sh
```

ルール（打ち歩詰め・二歩・行き所のない駒・成りの強制・ピン）と、1問目の例題、アプリと同じ方法で作った問題について次のことを確かめます。

- 正解の初手が一つだけ
- 3手詰めが1手で詰んでしまわない（早詰めがない）
- 3手詰めで、玉方が応じたあとの最終手も一つだけ
- 5×5・7×7 用の問題は、駒がすべてその盤に入っている。範囲の外へは攻め方も玉方も指せない
- 9×9 用の問題は、5×5 の範囲の外にも駒がある（盤の広さを使っている）

Mac の Swift だけで動くので、Xcode やシミュレーターは要りません。

### 単体テスト（アプリ側）

スコアの計算、タイムトライアルの加算と減算、レーティングと保存、1 問の遊びの流れ（駒を選ぶ・正解・不正解・ヒント・3 手詰めの応手）を `TsumeshoTests/` で確かめます。Xcode で ⌘U を押すか、次のコマンドで動かします。

```sh
xcodebuild test -project Tsumesho.xcodeproj -scheme Tsumesho \
  -destination "platform=iOS Simulator,name=<シミュレーターの名前>"
```

成績を保存するテストは、テスト専用の保存先を使うので、手元のアプリの成績は書き換えません。

## 修行モード

ホームのモードの札、またはプレイ中のメニューから「修行」を選びます。
ノーマルで間違えた問題（王手にならない手も含む）を端末に残し、入門と同じ和紙の画面で解き直せます。
タイムトライアル・入門・修行での間違いは残しません。

- 問題は盤の大きさごとに、間違えた回数が多い順（同じなら最近間違えた順）に並べ、始めたときの順番で固定します
- 盤・持ち駒・ヒント・やり直しは通常と同じです
- レーティング・スコア・連勝は変わらず、時間制限・振動・全面の詰み演出もありません。詰ませると「詰み！」の文字が控えめに動きます
- 詰ませても次へは自動で進みません。詰んだ盤を見返してから、スワイプか「次の一問」で進みます
- 最後まで行ったら「もう一巡する」でくり返せます

残した問題は、アプリを閉じても消えません。修行モードを入れる前に間違えた問題は残っていません。

## 問題の作り方

`Tsumesho/Engine/Generator.swift` で、駒をランダムに置いた局面をソルバーで確かめ、上の条件を満たすものだけを出題します。

- 5×5 用：玉は一〜二段。ほかの駒は玉の左右 2 筋・五段までに置く
- 9×9 用：玉は一〜三段。飛・角・香（成った駒も）は盤のどこにでも置き、5×5 の範囲の外にも駒がある局面だけを残す

アプリは数問先まで裏で作り置きするので、スワイプしても待たされません。問題は自作か自動生成に限ります。既存の詰将棋の作品を写すと、著作権の問題があるためです。
