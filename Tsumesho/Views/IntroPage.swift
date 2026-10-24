import SwiftUI

// 最初の画面。遊び方を 3 点だけ伝え、盤の大きさを選んで始める。駒の動き方は教えない。
// 盤の大きさは遊んでいる間は変えられない。変えたいときは問題画面の「トップ」からここに戻る
struct IntroPage: View {
    let onStart: () -> Void
    @Environment(Session.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("ツメショー").font(Theme.mono(13)).foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 10) {
                Text("1問1分の\n詰将棋").font(.system(size: 40, weight: .heavy)).foregroundStyle(Theme.ink)
                Text("相手の玉を、逃げられなくしたら勝ち。\n駒の動き方は覚えなくて大丈夫です。\n問題はアプリがその場で作るので、ずっと続きます。")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.soft)
            }

            VStack(alignment: .leading, spacing: 18) {
                rule(no: "1", title: "毎回「王手」をかける",
                     text: "王手は、次に玉を取れる状態にする手。詰将棋では王手しか指せません") {
                    KomaView(label: "玉", upsideDown: true, size: 40)
                }
                rule(no: "2", title: "駒をタップすると、動けるマスが光る",
                     text: "光ったマスをタップすると指せます。持ち駒は空いているマスに打てます") {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.55))
                        .frame(width: 34, height: 34)
                        .overlay(KomaView(label: "金", size: 30))
                }
                rule(no: "3", title: "迷ったら「ヒント」",
                     text: "1回目で王手をかけられる駒、2回目で正解の場所が光ります") {
                    Image(systemName: "lightbulb.fill").font(.system(size: 26)).foregroundStyle(Theme.hint)
                }
            }

            boardSizePicker

            Spacer(minLength: 0)

            Button(action: onStart) {
                Text("はじめる")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(Theme.background)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(Theme.background.ignoresSafeArea())
    }

    private var boardSizePicker: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 8) {
            Text("盤の大きさ").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.soft)
            Picker("盤の大きさ", selection: $session.smallBoard) {
                Text("9×9（普通の盤）").tag(false)
                Text("5×5（玉のまわりだけ）").tag(true)
            }
            .pickerStyle(.segmented)
            Text("5×5 と 9×9 では、出る問題が違います。遊び始めたあとに変えたいときは、問題画面の「トップ」からこの画面に戻ってください").font(.system(size: 12)).foregroundStyle(Theme.soft)
        }
    }

    private func rule<Icon: View>(no: String, title: String, text: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon().frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                Text(text).font(.system(size: 14)).foregroundStyle(Theme.soft).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(no). \(title)。\(text)")
    }
}
