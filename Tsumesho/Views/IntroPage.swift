import SwiftUI
import UIKit

// ホーム画面。和紙の上に木の盤を置き、詰みの実演を見せて「これを解くゲーム」だと伝える。
// タイトルは縦書き、始めるボタンは大きな駒。ネオンの見た目とは別の、ホームだけの世界観にする
struct IntroPage: View {
    let onStart: () -> Void
    @Environment(Session.self) private var session
    @State private var showsRules = false
    @State private var bob = false
    @State private var progress = 0.0
    @State private var slam = 0
    @State private var ripple = 0.0
    @State private var pageBump: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            topRow
            Spacer(minLength: 10)
            HStack(alignment: .top, spacing: 14) {
                HomeDemoBoard()
                    .rotationEffect(.degrees(-2))
                verticalTitle
            }
            caption
            Spacer(minLength: 14)
            bottomRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaperBackground())
        .environment(\.palette, .classic)
        .sheet(isPresented: $showsRules) { RulesSheet() }
        .offset(y: pageBump)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { bob = true }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.35)) { progress = rank.fraction }
        }
    }

    // MARK: 上の段（段位の札と遊び方）

    private var topRow: some View {
        HStack(alignment: .top) {
            plaque
            Spacer()
            Button { showsRules = true } label: {
                FudaTag(text: "遊び方", selected: false, fontSize: 13)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("遊び方")
        }
    }

    // 段位を書いた木札と、次の段までのゲージ、連勝の炎
    private var plaque: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(session.rankName)
                    .font(Theme.koma(26))
                    .foregroundStyle(Washi.ink)
                CountUpText(value: session.rating, prefix: "R")
                    .font(Theme.number(13))
                    .foregroundStyle(Washi.inkSoft)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 3).fill(Washi.kaya)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 3)
            )
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Washi.kayaEdge, lineWidth: 1))

            rankGauge
            streakLine
        }
    }

    // 次の段までのゲージ。端に近づくほど「あと少し」で押したくなる
    private var rankGauge: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                Capsule().fill(Washi.paperDark)
                Capsule().fill(Washi.vermilion)
                    .frame(width: 168 * max(0.04, progress))
            }
            .frame(width: 168, height: 7)
            Text(rank.text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Washi.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    // 連勝が続いている間は炎と次の倍率を出し、途切れているときは、倍率が上がることを匂わせる
    @ViewBuilder
    private var streakLine: some View {
        if session.streak > 0 {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15 + CGFloat(min(session.streak, 10))))
                    .foregroundStyle(Washi.vermilion)
                    .scaleEffect(bob ? 1.12 : 0.94, anchor: .bottom)
                Text("\(session.streak)連勝")
                    .font(Theme.koma(15))
                    .foregroundStyle(Washi.ink)
                Text("次は " + ScoreGain.format(session.nextStreakMultiplier))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Washi.paper)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 2).fill(Washi.vermilion))
            }
            .accessibilityElement(children: .combine)
        } else if session.solvedTotal > 0 {
            Text("連勝するほど、得点が最大3倍")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Washi.inkSoft)
        } else {
            Text("まずは1問、解いてみよう")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Washi.inkSoft)
        }
    }

    private var rank: (fraction: Double, text: String) {
        let bounds = [1400, 1600, 1800, 2000, 2200]
        let names = ["初段", "二段", "三段", "四段", "五段"]
        let rating = session.rating
        guard let i = bounds.firstIndex(where: { rating < $0 }) else { return (1, "最高段に到達") }
        let lower = i == 0 ? 1200 : bounds[i - 1]
        let fraction = min(1, max(0, Double(rating - lower) / Double(bounds[i] - lower)))
        return (fraction, "\(names[i])まで あと \(bounds[i] - rating)")
    }

    // MARK: 縦書きのタイトル

    private var verticalTitle: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(spacing: 2) {
                ForEach(Array("ツメショー".enumerated()), id: \.offset) { _, ch in
                    Text(String(ch))
                        .font(Theme.koma(38))
                        .foregroundStyle(Washi.ink)
                        .rotationEffect(.degrees(ch == "ー" ? 90 : 0))
                        .frame(height: ch == "ー" ? 30 : nil)
                }
            }
            VStack(spacing: 1) {
                ForEach(Array("一問一分の詰将棋".enumerated()), id: \.offset) { _, ch in
                    Text(String(ch))
                        .font(Theme.koma(11))
                        .foregroundStyle(Washi.vermilion)
                }
            }
            .padding(.top, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ツメショー。一問一分の詰将棋")
    }

    private var caption: some View {
        Text("飛を左上へ。玉の逃げ道がなくなれば「詰み」。\n盤をタップすると、実演が見られます。")
            .font(.system(size: 12))
            .foregroundStyle(Washi.inkSoft)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
    }

    // MARK: 下の段（選択と、大きな駒のボタン）

    private var bottomRow: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                tabGroup(title: "モード") {
                    tab("入門", selected: session.mode == .tutorial) { session.mode = .tutorial }
                    tab("ノーマル", selected: session.mode == .normal) { session.mode = .normal }
                    tab("タイム", selected: session.mode == .timeTrial) { session.mode = .timeTrial }
                }
                modeNote
                if session.mode != .tutorial {
                    tabGroup(title: "盤の大きさ") {
                        ForEach(BoardSize.allCases, id: \.self) { size in
                            tab(kanji(size), selected: session.boardSize == size) { session.boardSize = size }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            startPiece
        }
    }

    // 選んでいるモードの一言。入門では、いまどこまで進んだかを出す
    @ViewBuilder
    private var modeNote: some View {
        let text: String = switch session.mode {
        case .tutorial:
            session.tutorialDone ? "7段階を修了ずみ。いつでも復習できます" : "7段階で学ぶ。いま \(session.tutorialSolved) / 7 段を修了"
        case .normal:
            "自分のペースで、ずっと解ける"
        case .timeTrial:
            session.timeTrialBest > 0 ? "60秒から。最高 \(session.timeTrialBest) 問" : "60秒から。何問解ける？"
        }
        Text(text)
            .font(.system(size: 11)).foregroundStyle(Washi.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var startCaption: String {
        switch session.mode {
        case .tutorial:
            session.tutorialDone ? "入門をもう一度" : (session.tutorialSolved > 0 ? "第\(session.tutorialNext + 1)段から" : "はじめから")
        default:
            session.solvedTotal > 0 ? "つづきから" : "はじめから"
        }
    }

    private func kanji(_ size: BoardSize) -> String {
        switch size {
        case .small: "五"
        case .medium: "七"
        case .full: "九"
        }
    }

    private func tabGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(Washi.inkSoft)
            HStack(spacing: 6) { content() }
        }
    }

    // 木札のメニュー。選んでいる札は浮いて、朱の文字になる
    private func tab(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            if session.hapticsOn { UISelectionFeedbackGenerator().selectionChanged() }
            action()
        } label: {
            FudaTag(text: text, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // 大きな駒。押すと盤に押し込まれるように沈む
    private var startPiece: some View {
        Button(action: slamAndStart) {
            VStack(spacing: 8) {
                ZStack {
                    KomaShape().fill(Washi.kaya)
                    KomaShape().stroke(Washi.kayaEdge, lineWidth: 2)
                    VStack(spacing: 0) {
                        Text("指").font(Theme.koma(44)).foregroundStyle(Washi.ink)
                        Text("す").font(Theme.koma(44)).foregroundStyle(Washi.vermilion)
                    }
                    .padding(.top, 14)
                }
                .frame(width: 108, height: 124)
                .background(
                    Circle()
                        .stroke(Washi.vermilion, lineWidth: 6 * (1 - ripple) + 1)
                        .frame(width: 120, height: 120)
                        .scaleEffect(0.5 + ripple * 3)
                        .opacity(slam == 2 ? 1 - ripple : 0)
                )
                .rotationEffect(.degrees(slam == 0 ? (bob ? 1.6 : -1.6) : 0))
                .scaleEffect(slam == 1 ? 1.3 : (slam == 2 ? 0.94 : 1))
                .offset(y: slam == 1 ? -20 : (slam == 0 && bob ? -3 : 0))
                Text(startCaption)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Washi.inkSoft)
            }
        }
        .buttonStyle(PieceButtonStyle())
        .accessibilityLabel("指す。\(startCaption)")
    }

    // 駒を持ち上げて、盤に叩きつけてから始める。朱の輪が広がり、画面が揺れる
    private func slamAndStart() {
        guard slam == 0 else { return }
        Task {
            if session.hapticsOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            withAnimation(.easeOut(duration: 0.12)) { slam = 1 }
            try? await Task.sleep(for: .milliseconds(130))
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) { slam = 2 }
            withAnimation(.easeOut(duration: 0.5)) { ripple = 1 }
            if session.hapticsOn {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                try? await Task.sleep(for: .milliseconds(70))
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
            for value: CGFloat in [7, -3, 2, 0] {
                withAnimation(.easeOut(duration: 0.05)) { pageBump = value }
                try? await Task.sleep(for: .milliseconds(55))
            }
            try? await Task.sleep(for: .milliseconds(180))
            onStart()
        }
    }
}

// 数字を 0 から勢いよく数え上げる。値が変わったときも、今の表示から数え直す
private struct CountUpText: View {
    let value: Int
    var prefix = ""
    @State private var shown = 0

    var body: some View {
        Text("\(prefix)\(shown)")
            .task(id: value) {
                let from = shown
                let steps = 28
                for i in 1...steps {
                    let t = Double(i) / Double(steps)
                    let eased = 1 - (1 - t) * (1 - t) * (1 - t)
                    shown = from + Int(Double(value - from) * eased)
                    try? await Task.sleep(for: .milliseconds(24))
                }
                shown = value
            }
    }
}

// 押すと小さくなって沈み、影が縮む
private struct PieceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .offset(y: configuration.isPressed ? 4 : 0)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.15 : 0.35),
                    radius: configuration.isPressed ? 2 : 8, x: 0, y: configuration.isPressed ? 2 : 10)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// 和紙の地。繊維のような細い線をうっすら散らす
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Washi.paper
            Canvas { ctx, size in
                for i in 0..<220 {
                    let seed = Double(i)
                    let x = (seed * 0.6180339).truncatingRemainder(dividingBy: 1) * size.width
                    let y = (seed * 0.7548777 + 0.11).truncatingRemainder(dividingBy: 1) * size.height
                    let length = 6 + seed.truncatingRemainder(dividingBy: 7) * 3
                    let tilt = (seed.truncatingRemainder(dividingBy: 9) - 4) * 0.3
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + length, y: y + length * tilt))
                    ctx.stroke(path, with: .color(Washi.kayaSide.opacity(0.07)), lineWidth: 0.7)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// 遊び方。ホームから開くシート
private struct RulesSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("相手の玉を、逃げられなくしたら勝ち。駒の動き方は覚えなくて大丈夫です。")
                        .font(.system(size: 15)).foregroundStyle(Washi.inkSoft)
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
                    Text("五・七は玉のまわりだけ、九は普通の盤です。大きい盤ほど高得点です。")
                        .font(.system(size: 13)).foregroundStyle(Washi.inkSoft)
                }
                .padding(24)
            }
            .background(PaperBackground())
            .navigationTitle("遊び方")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("閉じる") { dismiss() } }
        }
        .presentationDetents([.medium, .large])
    }

    private func rule<Icon: View>(no: String, title: String, text: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon().frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Washi.ink)
                Text(text).font(.system(size: 13)).foregroundStyle(Washi.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(no). \(title)。\(text)")
    }
}
