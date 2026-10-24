import SwiftUI
import UIKit

// ホーム画面で使う、紙と木と朱墨の色。ネオンの見た目とは別に、ホームだけの世界観にする
enum Washi {
    static let paper = Color(red: 0.937, green: 0.902, blue: 0.824)      // 和紙
    static let paperDark = Color(red: 0.86, green: 0.81, blue: 0.70)
    static let ink = Color(red: 0.106, green: 0.09, blue: 0.075)          // 墨
    static let inkSoft = Color(red: 0.36, green: 0.31, blue: 0.25)
    static let vermilion = Color(red: 0.78, green: 0.2, blue: 0.12)       // 朱
    static let kaya = Color(red: 0.89, green: 0.73, blue: 0.43)           // 盤の木
    static let kayaEdge = Color(red: 0.62, green: 0.43, blue: 0.19)
    static let kayaSide = Color(red: 0.47, green: 0.31, blue: 0.13)
}

// ホーム画面の真ん中に置く、詰みの実演。木の盤の上で、飛車が左上に滑り込んで玉が詰み、
// 朱の落款「詰」が押される。玉(右上)は、横の逃げ道を飛車に、下の逃げ道を金に押さえられている。
// タップするともう一度流す
struct HomeDemoBoard: View {
    @Environment(Session.self) private var session

    @State private var moved = false
    @State private var mate = false
    @State private var stampScale: CGFloat = 2.4
    @State private var stampOpacity = 0.0
    @State private var mateStart: Date?
    @State private var verdict = false
    @State private var bump: CGFloat = 0
    @State private var pulse = false
    @State private var token = 0

    private let span = 5

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let margin = side * 0.055
            let cell = (side - margin * 2) / CGFloat(span)
            ZStack {
                boardBody(side: side)
                grid(cell: cell, margin: margin)
                target(cell: cell, margin: margin)
                pieces(cell: cell, margin: margin)
                stamp(side: side)
                verdictText(side: side)
            }
            .frame(width: side, height: side)
            .overlay { MateBurst(start: mateStart, side: side) }
            .offset(y: bump)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        .task(id: token) { await loop() }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("詰みの実演。飛車を左上に動かすと、玉が逃げられなくなります。タップでもう一度見られます")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: 盤

    // 厚みのある木の盤。下に濃い木を少しずらして重ね、木目の線を薄く引く
    private func boardBody(side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Washi.kayaSide)
                .offset(y: 9)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 12)
            RoundedRectangle(cornerRadius: 5).fill(Washi.kaya)
            Canvas { ctx, size in
                for i in 0..<46 {
                    let seed = Double(i)
                    let y = (seed * 0.6180339).truncatingRemainder(dividingBy: 1) * size.height
                    let wobble = 2 + seed.truncatingRemainder(dividingBy: 4)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addCurve(to: CGPoint(x: size.width, y: y + wobble),
                                  control1: CGPoint(x: size.width * 0.3, y: y - wobble),
                                  control2: CGPoint(x: size.width * 0.7, y: y + wobble * 2))
                    let alpha = 0.05 + 0.08 * (seed.truncatingRemainder(dividingBy: 3) / 2)
                    ctx.stroke(path, with: .color(Washi.kayaSide.opacity(alpha)), lineWidth: 0.6 + seed.truncatingRemainder(dividingBy: 3) * 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            RoundedRectangle(cornerRadius: 5).stroke(Washi.kayaEdge.opacity(0.7), lineWidth: 1)
        }
        .frame(width: side, height: side)
    }

    private func grid(cell: CGFloat, margin: CGFloat) -> some View {
        let length = cell * CGFloat(span)
        return Path { p in
            for i in 0...span {
                let v = cell * CGFloat(i)
                p.move(to: CGPoint(x: margin + v, y: margin))
                p.addLine(to: CGPoint(x: margin + v, y: margin + length))
                p.move(to: CGPoint(x: margin, y: margin + v))
                p.addLine(to: CGPoint(x: margin + length, y: margin + v))
            }
        }
        .stroke(Washi.ink.opacity(0.85), lineWidth: 1.2)
    }

    // 指す先のマス。詰みの前だけ、朱で脈打たせる
    @ViewBuilder
    private func target(cell: CGFloat, margin: CGFloat) -> some View {
        if !moved {
            let alpha: Double = pulse ? 0.4 : 0.12
            Rectangle()
                .fill(Washi.vermilion.opacity(alpha))
                .frame(width: cell, height: cell)
                .position(center(0, 0, cell, margin))
        }
    }

    private func pieces(cell: CGFloat, margin: CGFloat) -> some View {
        let size = cell * 1.02
        let rookRow = moved ? 0 : 2
        return ZStack {
            piece("玉", upsideDown: true, size: size)
                .rotationEffect(.degrees(mate ? 16 : 0))
                .offset(y: mate ? 3 : 0)
                .opacity(mate ? 0.8 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.35), value: mate)
                .position(center(4, 0, cell, margin))
            piece("金", upsideDown: false, size: size)
                .position(center(3, 2, cell, margin))
            piece("飛", upsideDown: false, size: size)
                .scaleEffect(moved && !mate ? 1.08 : 1)
                .position(center(0, rookRow, cell, margin))
        }
    }

    // 木の駒。普通の見た目の駒に、盤に落ちる影を足す
    private func piece(_ label: String, upsideDown: Bool, size: CGFloat) -> some View {
        KomaView(label: label, upsideDown: upsideDown, size: size)
            .environment(\.palette, .classic)
            .shadow(color: .black.opacity(0.4), radius: 2.5, x: 1.5, y: 4)
    }

    // 朱の落款。大きい状態から勢いよく押される
    private func stamp(side: CGFloat) -> some View {
        let size = side * 0.46
        return ZStack {
            RoundedRectangle(cornerRadius: 7).fill(Washi.vermilion)
            RoundedRectangle(cornerRadius: 4).inset(by: 6).stroke(Washi.paper.opacity(0.8), lineWidth: 2)
            Text("詰")
                .font(Theme.brush(size * 0.7))
                .foregroundStyle(Washi.paper)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-9))
        .scaleEffect(stampScale)
        .opacity(stampOpacity)
        .shadow(color: Washi.vermilion.opacity(0.35), radius: 8, y: 4)
        .allowsHitTesting(false)
    }

    // 落款の下に、毛筆の「正解」が勢いよく入る
    @ViewBuilder
    private func verdictText(side: CGFloat) -> some View {
        if verdict {
            Text("正解")
                .font(Theme.brush(side * 0.2))
                .foregroundStyle(Washi.ink)
                .rotationEffect(.degrees(-5))
                .offset(y: side * 0.34)
                .transition(.scale(scale: 2.2).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    private func center(_ col: Int, _ row: Int, _ cell: CGFloat, _ margin: CGFloat) -> CGPoint {
        CGPoint(x: margin + cell * (CGFloat(col) + 0.5), y: margin + cell * (CGFloat(row) + 0.5))
    }

    // MARK: 動き

    private func replay() {
        if session.hapticsOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        token += 1
    }

    // 待つ → 飛車が滑る → 落款がドンと押される → 余韻、をくり返す。タップで token が変わると最初からやり直す
    private func loop() async {
        let userTriggered = token > 0
        var first = true
        while !Task.isCancelled {
            moved = false
            mate = false
            mateStart = nil
            verdict = false
            stampOpacity = 0
            stampScale = 2.4
            try? await Task.sleep(for: .milliseconds(1500))
            if Task.isCancelled { return }
            withAnimation(.easeIn(duration: 0.28)) { moved = true }
            try? await Task.sleep(for: .milliseconds(320))
            if Task.isCancelled { return }
            mate = true
            mateStart = Date()
            stampOpacity = 1
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { stampScale = 1 }
            if session.hapticsOn {
                if userTriggered {
                    Haptics.mate(enabled: true)
                } else if !first {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
            Task {
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { verdict = true }
            }
            await thud()
            first = false
            try? await Task.sleep(for: .milliseconds(2500))
            if Task.isCancelled { return }
            withAnimation(.easeIn(duration: 0.3)) { stampOpacity = 0; verdict = false }
            try? await Task.sleep(for: .milliseconds(350))
        }
    }

    // 落款が押された衝撃で、盤が沈んで戻る
    private func thud() async {
        for value: CGFloat in [6, -2, 1, 0] {
            withAnimation(.easeOut(duration: 0.05)) { bump = value }
            try? await Task.sleep(for: .milliseconds(55))
        }
    }
}


// 詰んだ瞬間の爆発。紙の閃光、集中線、三重の衝撃波、金の光、紙吹雪と金箔を、経過時間だけで描く。
// 盤からはみ出して舞うので、描く範囲は盤より広く取る
private struct MateBurst: View {
    let start: Date?
    let side: CGFloat

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            let t = start.map { timeline.date.timeIntervalSince($0) } ?? -1
            Canvas { ctx, size in
                guard t >= 0 else { return }
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                bloom(&ctx, c, t)
                rays(&ctx, c, t)
                rings(&ctx, c, t)
                flash(&ctx, c, t)
                confetti(&ctx, c, t)
            }
        }
        .frame(width: side * 1.7, height: side * 2.0)
        .allowsHitTesting(false)
    }

    // 擬似乱数。同じ番号なら毎回同じ値になる
    private func rnd(_ i: Int, _ k: Double) -> Double {
        let v = sin(Double(i) * 12.9898 + k * 78.233) * 43758.5453
        return v - floor(v)
    }

    // 金色のやわらかい光
    private func bloom(_ ctx: inout GraphicsContext, _ c: CGPoint, _ t: Double) {
        let a = max(0, 0.5 - t * 0.5)
        guard a > 0 else { return }
        let r = side * 0.85
        let gradient = Gradient(colors: [Washi.kaya.opacity(a), Washi.vermilion.opacity(a * 0.35), .clear])
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(gradient, center: c, startRadius: 0, endRadius: r))
    }

    // 漫画のような墨の集中線
    private func rays(_ ctx: inout GraphicsContext, _ c: CGPoint, _ t: Double) {
        let life = 0.55
        guard t < life else { return }
        let p = t / life
        let inner = side * (0.16 + 0.18 * p)
        for i in 0..<30 {
            let angle = Double(i) / 30 * 2 * .pi + rnd(i, 1) * 0.12
            let length = side * (0.2 + 0.32 * rnd(i, 2)) * (0.5 + p)
            let spread = 0.035 + rnd(i, 3) * 0.03
            var path = Path()
            path.move(to: CGPoint(x: c.x + cos(angle - spread) * inner, y: c.y + sin(angle - spread) * inner))
            path.addLine(to: CGPoint(x: c.x + cos(angle) * (inner + length), y: c.y + sin(angle) * (inner + length)))
            path.addLine(to: CGPoint(x: c.x + cos(angle + spread) * inner, y: c.y + sin(angle + spread) * inner))
            path.closeSubpath()
            ctx.fill(path, with: .color(Washi.ink.opacity((1 - p) * 0.85)))
        }
    }

    // 朱・墨・金の衝撃波を少しずつずらして広げる
    private func rings(_ ctx: inout GraphicsContext, _ c: CGPoint, _ t: Double) {
        let colors: [Color] = [Washi.vermilion, Washi.ink, Washi.kaya]
        for (i, color) in colors.enumerated() {
            let local = t - Double(i) * 0.09
            guard local > 0, local < 0.8 else { continue }
            let p = local / 0.8
            let r = side * (0.12 + 0.95 * p)
            let width = 10 * (1 - p) + 1
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .color(color.opacity(1 - p)), lineWidth: width)
        }
    }

    // 最初の一瞬だけ、盤が白く飛ぶ
    private func flash(_ ctx: inout GraphicsContext, _ c: CGPoint, _ t: Double) {
        let a = 0.85 - t * 6
        guard a > 0 else { return }
        let rect = CGRect(x: c.x - side / 2, y: c.y - side / 2, width: side, height: side)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Color.white.opacity(a)))
    }

    // 紙吹雪と金箔。中心から跳ね上がり、ひらひら回りながら落ちる
    private func confetti(_ ctx: inout GraphicsContext, _ c: CGPoint, _ t: Double) {
        guard t < 3.1 else { return }
        let fade = t > 2.3 ? max(0, 1 - (t - 2.3) / 0.8) : 1
        let palette: [Color] = [Washi.vermilion, Washi.kaya, Color.white, Washi.vermilion, Washi.ink, Washi.kaya]
        for i in 0..<84 {
            let angle = -Double.pi * (0.06 + 0.88 * rnd(i, 4))
            let speed = side * (0.7 + 1.5 * rnd(i, 5))
            let sway = sin(t * (3 + rnd(i, 6) * 3) + Double(i)) * side * 0.03
            let x = c.x + cos(angle) * speed * t + sway
            let y = c.y - side * 0.05 + sin(angle) * speed * t + 0.5 * side * 1.7 * t * t
            let w = 5 + 7 * rnd(i, 7)
            let h = w * (0.4 + 0.5 * rnd(i, 8))
            let spin = (rnd(i, 9) - 0.5) * 14 * t
            let flutter = abs(cos(t * (4 + rnd(i, 10) * 4) + Double(i)))
            var layer = ctx
            layer.translateBy(x: x, y: y)
            layer.rotate(by: .radians(spin))
            let rect = CGRect(x: -w / 2, y: -h * flutter / 2, width: w, height: max(1, h * flutter))
            let color = palette[i % palette.count]
            if i % 7 == 0 {
                layer.fill(Path(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4)), with: .color(Washi.kaya.opacity(fade)))
            } else {
                layer.fill(Path(rect), with: .color(color.opacity(fade)))
            }
        }
    }
}
