import SwiftUI

// 次のページのスコアの実際の位置を、FeedView の粒の着地点に使う。
struct ScoreTargetKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct ScoreFlight: Identifiable {
    let id = UUID()
    let startedAt = Date()
}

struct ScoreFlightView: View {
    let flight: ScoreFlight
    let origin: CGPoint
    let target: CGPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let t = max(0, context.date.timeIntervalSince(flight.startedAt))
            Canvas { ctx, _ in
                guard !reduceMotion else {
                    let fade = max(0, 1 - abs(t - 0.45) / 0.3)
                    let rect = CGRect(x: target.x - 48, y: target.y - 28, width: 96, height: 56)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 18), with: .color(Theme.goldGlow.opacity(fade * 0.3)))
                    return
                }
                ctx.blendMode = .plusLighter
                for i in 0..<28 {
                    let delay = Double(i % 7) * 0.035
                    let p = min(1, max(0, (t - delay) / 0.62))
                    guard t > delay, p < 1 else { continue }
                    let curved = 1 - pow(1 - p, 2)
                    let spread = CGFloat(i % 7 - 3) * 22
                    let x = origin.x + (target.x - origin.x) * curved + sin(p * .pi) * spread
                    let y = origin.y + (target.y - origin.y) * curved - sin(p * .pi) * CGFloat(70 + i % 4 * 18)
                    let radius = CGFloat(2 + i % 3) * (1 - p * 0.45)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    var glow = ctx
                    glow.addFilter(.blur(radius: 4))
                    glow.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(Theme.goldGlow.opacity(0.65)))
                    ctx.fill(Path(ellipseIn: rect), with: .color(i.isMultiple(of: 4) ? Theme.cream : Theme.goldGlow))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct RankUpView: View {
    let reward: SolveReward
    @State private var startedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 1 : max(0, context.date.timeIntervalSince(startedAt))
            ZStack {
                Color.black.opacity(0.88)
                Circle()
                    .stroke(Theme.goldGlow.opacity(max(0, 0.8 - t * 0.65)), lineWidth: 3)
                    .frame(width: 180, height: 180)
                    .scaleEffect(reduceMotion ? 1 : 0.6 + t * 1.4)
                VStack(spacing: 22) {
                    Text("昇段")
                        .font(.system(size: 28, weight: .heavy))
                        .tracking(8)
                        .foregroundStyle(Theme.goldGlow)
                    HolographicBadge(title: t < 0.28 ? reward.previousRank : reward.rank,
                                     size: 146, celebrating: true)
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : min(1, t / 0.56) * 360), axis: (x: 0, y: 1, z: 0))
                        .scaleEffect(reduceMotion ? 1 : MateEffectView.spring(max(0, t - 0.28), from: 0.75, to: 1))
                    Text("\(rankName(reward.previousRank)) → \(rankName(reward.rank))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("昇段。\(rankName(reward.rank))になりました")
        .accessibilityAddTraits(.isModal)
    }

    private func rankName(_ badge: String) -> String { Session.Rank.name(ofBadge: badge) }
}

// 成績を変えずに、すべての連勝音と昇段を確認できる。
struct FeedbackPreviewView: View {
    @Environment(Session.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reward: SolveReward?
    @State private var displayedScore = 1200
    @State private var flight: ScoreFlight?
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        List {
            Section("連勝ごとの振動・詰み演出") {
                ForEach([1, 3, 5, 10], id: \.self) { streak in
                    Button(streak == 1 ? "通常の正解" : "\(streak)連勝") { preview(streak: streak, rankUp: false) }
                }
            }
            Section {
                Button("昇段とスコア獲得") { preview(streak: 5, rankUp: true) }
            } footer: {
                Text("この画面のプレビューでは成績は変わりません。音と振動は設定に従います。")
            }
            Section("獲得先のスコア") {
                Text(verbatim: "\(displayedScore)")
                    .font(Theme.number(30, weight: .black))
                    .foregroundStyle(Theme.goldGlow)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .anchorPreference(key: ScoreTargetKey.self, value: .bounds) { ["preview": $0] }
            }
        }
        .navigationTitle("演出を試す")
        .overlayPreferenceValue(ScoreTargetKey.self) { anchors in
            GeometryReader { geo in
                if let flight, let anchor = anchors["preview"] {
                    let rect = geo[anchor]
                    ScoreFlightView(flight: flight, origin: CGPoint(x: geo.size.width / 2, y: 120),
                                    target: CGPoint(x: rect.maxX - 45, y: rect.midY))
                }
            }
            .allowsHitTesting(false)
        }
        .fullScreenCover(item: $reward) { item in
            ZStack {
                MateEffectView(plies: 3, seconds: 8, tesuji: "捨て駒", seed: item.streak, reward: item) {
                    reward = nil
                }
                if item.rankedUp { RankUpView(reward: item) }
            }
        }
        .onDisappear {
            previewTask?.cancel()
            Haptics.stop()
            Sound.stop()
        }
    }

    private func preview(streak: Int, rankUp: Bool) {
        previewTask?.cancel()
        let gain = ScoreGain.make(plies: 3, size: .full, seconds: 8, hintsUsed: 0, streak: streak)
        let item = SolveReward(gain: gain, streak: streak, previousRank: "初", rank: rankUp ? "二" : "初")
        reward = item
        Haptics.play(rankUp ? .rankUp : .mate(streak), enabled: session.hapticsOn)
        if !rankUp { Sound.playMate(volume: session.soundVolume, streak: streak) }
        previewTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(rankUp ? 1.8 : 1.6))
                reward = nil
                try await Task.sleep(for: .milliseconds(500))
                flight = ScoreFlight()
                try await Task.sleep(for: .milliseconds(450))
                Haptics.play(.score, enabled: session.hapticsOn)
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.6)) { displayedScore += gain.points }
                try await Task.sleep(for: .milliseconds(600))
                flight = nil
            } catch { }
        }
    }
}
