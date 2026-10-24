import SwiftUI

// 詰んだときの演出。問題の列の上のレイヤーに出す（FeedView）。
// 動きはすべて表示されてからの経過時間 t（秒）で決める：
//   0.00〜  白い閃光が消えていき、画面が揺れる
//   0.00〜  光の筋が中央から広がり、ゆっくり回る。金の輪が 2 重に広がる
//   0.00〜  金色の駒の形の紙吹雪と粒が飛び散り、星がきらめく
//   0.00〜  「詰」が大きく傾いた状態から弾んで収まる
// タップするとすぐ次の問題へ進む
struct MateEffectView: View {
    let plies: Int
    let seconds: Int
    let tesuji: String?
    let seed: Int  // 光の筋・しぶき・紙吹雪の形を問題ごとに変える
    let onNext: () -> Void

    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 光の筋としぶきの中心。「詰」の文字の位置に合わせる
    static let centerRatio: CGFloat = 0.42

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            // 動きを減らす設定のときは、動き終わったあとの姿だけを見せる
            let t = reduceMotion ? 1.5 : timeline.date.timeIntervalSince(start)
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Color.black.opacity(0.85)

                    MateRays(seed: seed, t: t)
                    GoldSplash(seed: seed)
                        .scaleEffect(min(1, 0.4 + t * 3), anchor: UnitPoint(x: 0.5, y: Self.centerRatio))
                        .opacity(min(1, t * 5))
                    Burst(seed: seed, t: t)

                    VStack(spacing: 4) {
                        Text("詰")
                            .font(Theme.brush(min(size.width * 0.56, 230)))
                            .foregroundStyle(Theme.goldGradient)
                            .shadow(color: Theme.goldGlow, radius: 26)
                            .shadow(color: .black.opacity(0.9), radius: 2, x: 3, y: 5)
                            .scaleEffect(Self.spring(t, from: 2.4, to: 1))
                            .rotationEffect(.degrees(Self.spring(t, from: -22, to: -4)))
                        Text("正解")
                            .font(Theme.brush(50))
                            .foregroundStyle(Theme.cream)
                            .shadow(color: Theme.goldGlow.opacity(0.8), radius: 10)
                            .opacity(min(1, max(0, (t - 0.15) * 4)))
                        Text("\(plies)手詰 / \(timeText)")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.cream.opacity(0.9))
                            .opacity(min(1, max(0, (t - 0.25) * 4)))
                        if let tesuji {
                            Text("手筋「\(tesuji)」")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.cream.opacity(0.85))
                                .padding(.top, 6)
                                .opacity(min(1, max(0, (t - 0.35) * 4)))
                        }
                    }
                    .position(x: size.width / 2, y: size.height * Self.centerRatio + 70)

                    VStack {
                        Spacer()
                        Text("次の問題へ ↑")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.cream)
                            .padding(.horizontal, 36).padding(.vertical, 14)
                            .background(Capsule().fill(.black.opacity(0.55)))
                            .overlay(Capsule().stroke(Theme.goldGlow, lineWidth: 2))
                            .shadow(color: Theme.goldGlow, radius: 10)
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 48)
                    .opacity(min(1, max(0, (t - 0.4) * 4)))

                    // 最初の閃光
                    Color.white.opacity(max(0, 0.75 - t * 3.5))
                }
                .offset(Self.shake(t))
                .frame(width: size.width, height: size.height)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onNext)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("詰み。正解。\(plies)手詰め、\(seconds)秒" + (tesuji.map { "。手筋は\($0)" } ?? ""))
        .accessibilityHint("タップすると次の問題へ進みます")
        .accessibilityAddTraits(.isButton)
    }

    private var timeText: String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }

    // from から to へ、行き過ぎて戻りながら収まる動き
    static func spring(_ t: Double, from: Double, to: Double) -> Double {
        to + (from - to) * exp(-7 * t) * cos(13 * t)
    }

    // 最初の 0.4 秒だけ画面を揺らす
    static func shake(_ t: Double) -> CGSize {
        guard t < 0.4 else { return .zero }
        let amount = 9 * (1 - t / 0.4)
        return CGSize(width: sin(t * 95) * amount, height: cos(t * 71) * amount)
    }
}

// 中央から放射状に伸びる光の筋。5 色を重ねて明るく光らせ、ゆっくり回す
private struct MateRays: View {
    let seed: Int
    let t: Double

    private static let colors = [Theme.neonMagenta, Theme.neonCyan, Theme.goldGlow, Theme.neonGreen, Theme.cream]

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(state: UInt64(seed) &* 7919 &+ 17)
            let center = CGPoint(x: size.width / 2, y: size.height * MateEffectView.centerRatio)
            let reach = hypot(size.width, size.height) * 0.7
            let grow = min(1, 0.1 + t * 3.5)           // 中央から伸びていく
            let spin = t * 0.08                        // ゆっくり回る
            ctx.blendMode = .plusLighter
            var glow = ctx
            glow.addFilter(.blur(radius: 9))
            for i in 0..<64 {
                let angle = Double(rng.int(0...359)) * .pi / 180 + spin
                let start = reach * Double(rng.int(6...26)) / 100
                let end = reach * Double(rng.int(45...110)) / 100 * grow
                let halfWidth = Double(rng.int(1...10))
                let color = Self.colors[i % Self.colors.count]
                let path = wedge(center: center, angle: angle, start: start * grow, end: end, halfWidth: halfWidth)
                glow.fill(path, with: .color(color.opacity(0.85)))
                ctx.fill(path, with: .color(color.opacity(0.75)))
            }
        }
        .allowsHitTesting(false)
    }

    // 根元が太く、先がとがった光の筋
    private func wedge(center: CGPoint, angle: Double, start: Double, end: Double, halfWidth: Double) -> Path {
        let dir = CGPoint(x: cos(angle), y: sin(angle))
        let perp = CGPoint(x: -dir.y, y: dir.x)
        let base = CGPoint(x: center.x + dir.x * start, y: center.y + dir.y * start)
        var p = Path()
        p.move(to: CGPoint(x: base.x + perp.x * halfWidth, y: base.y + perp.y * halfWidth))
        p.addLine(to: CGPoint(x: center.x + dir.x * end, y: center.y + dir.y * end))
        p.addLine(to: CGPoint(x: base.x - perp.x * halfWidth, y: base.y - perp.y * halfWidth))
        p.closeSubpath()
        return p
    }
}

// 「詰」の後ろの墨だまりと、金の筆のはらい・しぶき
private struct GoldSplash: View {
    let seed: Int

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(state: UInt64(seed) &* 104_729 &+ 3)
            let center = CGPoint(x: size.width / 2, y: size.height * MateEffectView.centerRatio)
            let unit = min(size.width, size.height)
            let ink = Color(red: 0.02, green: 0.02, blue: 0.03)
            let gold = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Theme.cream, Theme.goldGlow, Color(red: 0.62, green: 0.42, blue: 0.1)]),
                startPoint: CGPoint(x: center.x, y: center.y - unit * 0.4),
                endPoint: CGPoint(x: center.x, y: center.y + unit * 0.4))
            func dot(_ distance: Double, _ radius: Double, _ shading: GraphicsContext.Shading) {
                let a = Double(rng.int(0...359)) * .pi / 180
                let c = CGPoint(x: center.x + cos(a) * distance, y: center.y + sin(a) * distance)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)), with: shading)
            }
            // 墨だまり
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - unit * 0.32, y: center.y - unit * 0.28,
                                            width: unit * 0.64, height: unit * 0.56)), with: .color(ink))
            for _ in 0..<14 { dot(unit * Double(rng.int(16...34)) / 100, unit * Double(rng.int(4...10)) / 100, .color(ink)) }
            // 金の筆のはらい。中央のまわりに弧を描く
            for _ in 0..<5 {
                let a0 = Double(rng.int(0...359)) * .pi / 180
                let sweep = Double(rng.int(40...90)) * .pi / 180
                let r = unit * Double(rng.int(26...40)) / 100
                var stroke = Path()
                stroke.addArc(center: center, radius: r, startAngle: .radians(a0), endAngle: .radians(a0 + sweep), clockwise: false)
                ctx.stroke(stroke, with: gold, style: StrokeStyle(lineWidth: Double(rng.int(4...12)), lineCap: .round))
            }
            // 金と墨のしぶき
            for _ in 0..<36 { dot(unit * Double(rng.int(28...58)) / 100, Double(rng.int(2...7)), gold) }
            for _ in 0..<30 { dot(unit * Double(rng.int(30...55)) / 100, Double(rng.int(2...6)), .color(ink)) }
        }
        .allowsHitTesting(false)
    }
}

// 広がる金の輪、飛び散る駒の形の紙吹雪と粒、きらめく星
private struct Burst: View {
    let seed: Int
    let t: Double

    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(state: UInt64(seed) &* 31337 &+ 11)
            let center = CGPoint(x: size.width / 2, y: size.height * MateEffectView.centerRatio)
            let reach = hypot(size.width, size.height) * 0.55
            ctx.blendMode = .plusLighter

            // 金の輪（2 重）
            for k in 0..<2 {
                let local = t - Double(k) * 0.12
                guard local > 0, local < 0.9 else { continue }
                let p = local / 0.9
                let radius = reach * (1 - pow(1 - p, 3))
                ctx.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(Theme.goldGlow.opacity(1 - p)), lineWidth: 10 * (1 - p) + 1)
            }

            // 紙吹雪と粒。外へ飛び出して減速し、少し落ちながら消える
            let fade = max(0, 1 - t / 2.4)
            for i in 0..<80 {
                let angle = Double(rng.int(0...359)) * .pi / 180
                let speed = reach * Double(rng.int(35...100)) / 100
                let spin = Double(rng.int(-8...8))
                let pieceSize = Double(rng.int(6...16))
                let distance = speed * (1 - exp(-3.2 * t))
                let fall = 60 * t * t
                let pos = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance + fall)
                let color = i % 5 == 0 ? Theme.neonMagenta : (i % 7 == 0 ? Theme.neonCyan : Theme.goldGlow)
                if i % 3 == 0 {
                    var piece = ctx
                    piece.translateBy(x: pos.x, y: pos.y)
                    piece.rotate(by: .radians(spin * t + angle))
                    piece.fill(KomaShape().path(in: CGRect(x: -pieceSize / 2, y: -pieceSize * 0.55, width: pieceSize, height: pieceSize * 1.1)),
                               with: .color(color.opacity(fade)))
                } else {
                    let r = pieceSize / 4
                    ctx.fill(Path(ellipseIn: CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(fade)))
                }
            }

            // きらめく星
            for i in 0..<14 {
                let x = Double(rng.int(5...95)) / 100 * size.width
                let y = Double(rng.int(5...85)) / 100 * size.height
                let twinkle = max(0, sin(t * 9 + Double(i) * 1.7))
                let r = Double(rng.int(6...14)) * twinkle
                var star = Path()
                star.move(to: CGPoint(x: x, y: y - r))
                star.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x, y: y))
                star.addQuadCurve(to: CGPoint(x: x, y: y + r), control: CGPoint(x: x, y: y))
                star.addQuadCurve(to: CGPoint(x: x - r, y: y), control: CGPoint(x: x, y: y))
                star.addQuadCurve(to: CGPoint(x: x, y: y - r), control: CGPoint(x: x, y: y))
                ctx.fill(star, with: .color(Theme.cream.opacity(0.9)))
            }
        }
        .allowsHitTesting(false)
    }
}
