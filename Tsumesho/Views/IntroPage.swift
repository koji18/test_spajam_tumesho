import SwiftUI

// 最初の画面。遊び方を 3 点だけ伝え、盤の大きさを選んで始める。駒の動き方は教えない。
// 盤の大きさは遊んでいる間は変えられない。変えたいときは問題画面の「トップ」からここに戻る
struct IntroPage: View {
    let onStart: () -> Void
    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("ツメショー").font(Theme.display(14)).tracking(2).foregroundStyle(palette.accent)

            VStack(alignment: .leading, spacing: 10) {
                Text("1問1分の\n詰将棋").font(.system(size: 40, weight: .heavy)).foregroundStyle(palette.text)
                Text("相手の玉を、逃げられなくしたら勝ち。\n駒の動き方は覚えなくて大丈夫です。\n問題はアプリがその場で作るので、ずっと続きます。")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.subText)
            }

            VStack(alignment: .leading, spacing: 18) {
                rule(no: "1", title: "毎回「王手」をかける",
                     text: "王手は、次に玉を取れる状態にする手。詰将棋では王手しか指せません") {
                    KomaView(label: "玉", upsideDown: true, size: 40, tone: .defender)
                }
                rule(no: "2", title: "駒をタップすると、動けるマスが光る",
                     text: "光ったマスをタップすると指せます。持ち駒は空いているマスに打てます") {
                    RoundedRectangle(cornerRadius: 4).fill(palette.target.opacity(palette.targetFill))
                        .frame(width: 34, height: 34)
                        .overlay(KomaView(label: "金", size: 30, tone: .hand))
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
            .tint(palette.plain ? Theme.woodLine : Theme.goldGlow)
            .foregroundStyle(palette.plain ? Color.white : Theme.background)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(NeonBackdrop())
    }

    private var boardSizePicker: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 8) {
            Text("盤のサイズ").font(.system(size: 13, weight: .bold)).foregroundStyle(palette.subText)
            Picker("盤のサイズ", selection: $session.boardSize) {
                ForEach(BoardSize.allCases, id: \.self) { size in
                    Text(size.label).tag(size)
                }
            }
            .pickerStyle(.segmented)
            Text("5×5・7×7 は玉のまわりだけ、9×9 は普通の盤です。遊んでいる途中でも、右上のメニューから変えられます")
                .font(.system(size: 12)).foregroundStyle(palette.subText)
        }
    }

    private func rule<Icon: View>(no: String, title: String, text: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon().frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(palette.text)
                Text(text).font(.system(size: 14)).foregroundStyle(palette.subText).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(no). \(title)。\(text)")
    }
}
