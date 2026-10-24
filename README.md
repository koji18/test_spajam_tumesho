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
Tools/
  test.sh                 エンジンと問題の生成のテスト
Config/
  Base.xcconfig           全員共通のビルド設定（Bundle ID など）
  Local.xcconfig.example  人ごとの設定のひな形。Local.xcconfig にコピーして使う
project.yml               XcodeGen の設定
```

盤は常に 9×9 で持ちます。5×5 の盤では、玉を中心に 5 筋 × 一〜五段を切り出して表示し、攻め方が指せる手もその範囲の中に限ります。

## テスト

```sh
Tools/test.sh
```

ルール（打ち歩詰め・二歩・行き所のない駒・成りの強制・ピン）と、1問目の例題、アプリと同じ方法で作った問題について次のことを確かめます。

- 正解の初手が一つだけ
- 3手詰めが1手で詰んでしまわない（早詰めがない）
- 3手詰めで、玉方が応じたあとの最終手も一つだけ
- 5×5 用の問題は、駒がすべて 5×5 に入り、その範囲だけで指しても正解が同じ
- 9×9 用の問題は、5×5 の範囲の外にも駒がある（盤の広さを使っている）

Mac の Swift だけで動くので、Xcode やシミュレーターは要りません。

## 問題の作り方

`Tsumesho/Engine/Generator.swift` で、駒をランダムに置いた局面をソルバーで確かめ、上の条件を満たすものだけを出題します。

- 5×5 用：玉は一〜二段。ほかの駒は玉の左右 2 筋・五段までに置く
- 9×9 用：玉は一〜三段。飛・角・香（成った駒も）は盤のどこにでも置き、5×5 の範囲の外にも駒がある局面だけを残す

アプリは数問先まで裏で作り置きするので、スワイプしても待たされません。問題は自作か自動生成に限ります。既存の詰将棋の作品を写すと、著作権の問題があるためです。
