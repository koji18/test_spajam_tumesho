import SwiftUI

// 最初のページ。遊び方を 3 点だけ伝える。駒の動き方は教えない
struct IntroPage: View {
    let insets: EdgeInsets

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("ツメショー").font(Theme.mono(13)).foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 10) {
                Text("1問1分の\n詰将棋").font(.system(size: 40, weight: .heavy)).foregroundStyle(Theme.ink)
                Text("相手の玉を、逃げられなくしたら勝ち。\n駒の動き方は覚えなくて大丈夫です。")
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

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 22, weight: .bold))
                    .symbolEffect(.bounce, options: .repeating)
                Text("上にスワイプして始める").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, insets.top + 12)
        .padding(.bottom, insets.bottom + 20)
        .background(Theme.background)
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
