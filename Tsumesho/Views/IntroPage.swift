import SwiftUI
import UIKit

// ホーム画面。真ん中の盤が詰みを実演して「これを解くゲーム」だと一目で伝え、
// そのまま大きなボタンで始められる。モードと盤の大きさは下で選び、遊び方は別シートに置く
struct IntroPage: View {
    let onStart: () -> Void
    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette
    @State private var showsRules = false
    @State private var glow = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 8)
            title
            Spacer(minLength: 12)
            HomeDemoBoard()
                .frame(maxWidth: 330)
            caption
            Spacer(minLength: 14)
            options
            Spacer(minLength: 14)
            startButton
            Button("遊び方") { showsRules = true }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.subText)
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                NeonBackdrop()
                if !palette.plain { Sparkles() }
            }
        }
        .sheet(isPresented: $showsRules) { RulesSheet() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    // MARK: 上の成績

    private var topBar: some View {
        HStack(spacing: 8) {
            chip(icon: "crown.fill", text: "\(session.rankName)  \(session.rating)", tint: Theme.goldGlow)
            Spacer()
            if session.streak > 0 {
                chip(icon: "flame.fill", text: "\(session.streak) 連勝", tint: Theme.hint)
            }
            if session.totalScore > 0 {
                chip(icon: "star.fill", text: "\(session.totalScore)", tint: Theme.neonCyan)
            }
        }
    }

    private func chip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
            Text(text).font(Theme.number(14)).foregroundStyle(palette.text)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(palette.panel))
        .overlay(Capsule().stroke(palette.panelStroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: タイトル

    private var title: some View {
        VStack(spacing: 6) {
            Text("ツメショー")
                .font(.system(size: 46, weight: .heavy))
                .foregroundStyle(palette.plain ? AnyShapeStyle(palette.text) : AnyShapeStyle(Theme.goldGradient))
                .shadow(color: palette.plain ? .clear : Theme.goldGlow.opacity(glow ? 0.7 : 0.3), radius: glow ? 18 : 8)
            Text("この玉、詰ませられる？")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.subText)
        }
    }

    private var caption: some View {
        Text("飛車を左上へ。玉の逃げ道が消えたら「詰み」！\nタップでもう一度")
            .font(.system(size: 12))
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.subText)
            .padding(.top, 10)
    }

    // MARK: モードと盤の大きさ

    private var options: some View {
        @Bindable var session = session
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                modePill(.normal, title: "ノーマル", sub: "のんびり")
                modePill(.timeTrial, title: "タイムトライアル",
                         sub: session.timeTrialBest > 0 ? "最高 \(session.timeTrialBest) 問" : "60秒勝負")
            }
            Picker("盤のサイズ", selection: $session.boardSize) {
                ForEach(BoardSize.allCases, id: \.self) { size in
                    Text(size.label).tag(size)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func modePill(_ mode: PlayMode, title: String, sub: String) -> some View {
        let selected = session.mode == mode
        return Button {
            if session.hapticsOn { UISelectionFeedbackGenerator().selectionChanged() }
            withAnimation(.easeOut(duration: 0.15)) { session.mode = mode }
        } label: {
            HStack(spacing: 8) {
                ModeIcon(mode: mode, size: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(palette.text)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(sub).font(.system(size: 11)).foregroundStyle(palette.subText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(palette.panel))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? palette.accent : palette.panelStroke, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)。\(sub)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: 開始ボタン

    private var startButton: some View {
        Button {
            if session.hapticsOn { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            onStart()
        } label: {
            HStack(spacing: 10) {
                Text(session.solvedTotal > 0 ? "つづける" : "はじめる")
                    .font(.system(size: 22, weight: .heavy))
                Image(systemName: "play.fill").font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(palette.plain ? Color.white : Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(palette.plain ? AnyShapeStyle(Theme.woodLine) : AnyShapeStyle(Theme.goldGradient))
            )
            .shadow(color: palette.plain ? .clear : Theme.goldGlow.opacity(glow ? 0.85 : 0.35), radius: glow ? 22 : 8)
            .scaleEffect(glow ? 1.015 : 1)
        }
        .buttonStyle(.plain)
    }
}

// 背景のまたたく光の粒
private struct Sparkles: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<36 {
                    let seed = Double(i)
                    let x = (seed * 0.6180339).truncatingRemainder(dividingBy: 1) * size.width
                    let y = (seed * 0.3819660 + 0.17).truncatingRemainder(dividingBy: 1) * size.height
                    let twinkle = 0.5 + 0.5 * sin(t * (0.8 + seed.truncatingRemainder(dividingBy: 5) * 0.25) + seed)
                    let r = 1 + 1.6 * twinkle
                    let color: Color = i % 3 == 0 ? Theme.neonPink : (i % 3 == 1 ? Theme.neonCyan : Theme.goldGlow)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(0.15 + 0.55 * twinkle)))
                }
            }
        }
        .allowsHitTesting(false)
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
                        .font(.system(size: 15)).foregroundStyle(palette.subText)
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
                    Text("5×5・7×7 は玉のまわりだけ、9×9 は普通の盤です。大きい盤ほど高得点です。")
                        .font(.system(size: 13)).foregroundStyle(palette.subText)
                }
                .padding(24)
            }
            .background(NeonBackdrop())
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
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(palette.text)
                Text(text).font(.system(size: 13)).foregroundStyle(palette.subText).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(no). \(title)。\(text)")
    }
}
