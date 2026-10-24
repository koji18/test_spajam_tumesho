# ツメショー

1問1分の詰将棋を、ショート動画のように縦スワイプで次々に解く iOS アプリです。
駒をタップすると動けるマスが光るので、将棋のルールを知らなくても遊べます。

- 1手詰め 7問、3手詰め 3問（3手詰めでは玉方がアプリ側で自動的に応じます）
- 最初のページで遊び方を説明し、1問目は操作を順に案内します
- ヒントは2段階：1回目で王手をかけられる駒、2回目で正解の行き先が光ります

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
   - 「Bundle ID がすでに使われています」と出たら、同じファイルに `PRODUCT_BUNDLE_IDENTIFIER = com.自分の名前.tsumesho` のように自分用の ID を書く
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
  Engine/Problems.swift   問題（Tools/gen-problems.sh が生成。手で編集しない）
  Game.swift              1問ぶんの遊びの状態と、連続正解数
  Theme.swift             色とフォント
  TsumeshoApp.swift       縦スワイプのフィード
  Views/                  画面（遊び方・問題・盤）
Tools/
  test.sh                 エンジンと全問題のテスト
  gen-problems.sh         問題の自動生成
Config/
  Base.xcconfig           全員共通のビルド設定（Bundle ID など）
  Local.xcconfig.example  人ごとの設定のひな形。Local.xcconfig にコピーして使う
project.yml               XcodeGen の設定
```

盤は 9×9 で持ち、画面には 1〜5 筋 × 一〜五段だけを表示します。攻め方が指せる手も、この範囲の中に限っています。

## テスト

```sh
Tools/test.sh
```

ルール（打ち歩詰め・二歩・行き所のない駒・成りの強制・ピン）と、全問題について次のことを確かめます。

- 正解の初手が一つだけで、表示範囲の外にも別解がない
- 3手詰めが1手で詰んでしまわない（早詰めがない）
- 3手詰めで、玉方が応じたあとの最終手も一つだけ

Mac の Swift だけで動くので、Xcode やシミュレーターは要りません。

## 問題を作り直す

```sh
Tools/gen-problems.sh
```

玉を右上の隅に置き、攻め駒と持ち駒をランダムに配置して、テストと同じ条件を満たす局面だけを残します。1問目だけは手作りの例題（頭金）です。乱数の種は `Tools/GenProblems/main.swift` にあり、同じ種なら同じ問題ができます。生成のあとは `Tools/test.sh` で確かめてください。

問題は自作か自動生成に限ります。既存の詰将棋の作品を写すと、著作権の問題があるためです。
