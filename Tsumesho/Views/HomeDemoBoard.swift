import SwiftUI
import UIKit

// ホーム画面の真ん中に置く、詰みの実演。5×5 の盤で、飛車が左上に滑り込んで玉が詰む。
// 玉(右上)は、横の逃げ道を飛車に、下の逃げ道を金に押さえられている。タップするともう一度流す
struct HomeDemoBoard: View {
    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette

    @State private var moved = false
    @State private var mate = false
    @State private var burst = 0.0
    @State private var shake: CGFloat = 0
    @State private var pulse = false
    @State private var token = 0

    private let span = 5

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let cell = side / CGFloat(span)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(palette.boardFill)
                grid(cell: cell)
                target(cell: cell)
                pieces(cell: cell)
                burstLayer(side: side)
            }
            .frame(width: side, height: side)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.boardEdge, lineWidth: 2))
            .shadow(color: palette.plain ? .clear : Theme.neonCyan.opacity(mate ? 0.9 : 0.45), radius: mate ? 26 : 14)
            .offset(x: shake)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        .task(id: token) { await loop() }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("詰みの実演。飛車を左上に動かすと、玉が逃げられなくなります。タップでもう一度見られます")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: 盤

    private func grid(cell: CGFloat) -> some View {
        Path { p in
            for i in 1..<span {
                let v = cell * CGFloat(i)
                p.move(to: CGPoint(x: v, y: 0))
                p.addLine(to: CGPoint(x: v, y: cell * CGFloat(span)))
                p.move(to: CGPoint(x: 0, y: v))
                p.addLine(to: CGPoint(x: cell * CGFloat(span), y: v))
            }
        }
        .stroke(palette.gridLine, lineWidth: 1)
    }

    // 指す先のマス。詰みの前だけ、脈打つように光らせる
    @ViewBuilder
    private func target(cell: CGFloat) -> some View {
        if !moved {
            let alpha: Double = pulse ? 0.5 : 0.18
            RoundedRectangle(cornerRadius: 4)
                .fill(palette.target.opacity(alpha))
                .frame(width: cell * 0.92, height: cell * 0.92)
                .position(center(0, 0, cell))
        }
    }

    private func pieces(cell: CGFloat) -> some View {
        let size = cell * 0.98
        let rookRow = moved ? 0 : 2
        return ZStack {
            KomaView(label: "玉", upsideDown: true, size: size, tone: .defender)
                .scaleEffect(mate ? 0.82 : 1)
                .opacity(mate ? 0.65 : 1)
                .position(center(4, 0, cell))
            KomaView(label: "金", size: size, tone: .attacker)
                .position(center(3, 2, cell))
            KomaView(label: "飛", size: size, tone: .attacker)
                .position(center(0, rookRow, cell))
        }
    }

    // 詰んだ瞬間の光の輪と、毛筆の「詰」
    @ViewBuilder
    private func burstLayer(side: CGFloat) -> some View {
        if mate {
            ZStack {
                Circle()
                    .stroke(Theme.goldGlow, lineWidth: 6 * (1 - burst) + 1)
                    .frame(width: side * 0.4, height: side * 0.4)
                    .scaleEffect(0.3 + burst * 3.2)
                    .opacity(1 - burst)
                Circle()
                    .stroke(Theme.neonPink, lineWidth: 4 * (1 - burst) + 1)
                    .frame(width: side * 0.4, height: side * 0.4)
                    .scaleEffect(0.2 + burst * 2.4)
                    .opacity(1 - burst)
                Text("詰")
                    .font(Theme.brush(side * 0.62))
                    .foregroundStyle(Theme.goldGradient)
                    .shadow(color: Theme.goldGlow.opacity(0.9), radius: 14)
                    .scaleEffect(0.5 + burst * 0.5)
                    .rotationEffect(.degrees(-8 * (1 - burst)))
                    .opacity(min(1, burst * 6))
            }
            .allowsHitTesting(false)
        }
    }

    private func center(_ col: Int, _ row: Int, _ cell: CGFloat) -> CGPoint {
        CGPoint(x: cell * (CGFloat(col) + 0.5), y: cell * (CGFloat(row) + 0.5))
    }

    // MARK: 動き

    private func replay() {
        if session.hapticsOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        token += 1
    }

    // 待つ → 飛車が滑る → 詰み → 余韻、をくり返す。タップで token が変わると最初からやり直す
    private func loop() async {
        let userTriggered = token > 0
        var first = true
        while !Task.isCancelled {
            moved = false
            mate = false
            burst = 0
            try? await Task.sleep(for: .milliseconds(1500))
            if Task.isCancelled { return }
            withAnimation(.easeIn(duration: 0.3)) { moved = true }
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            mate = true
            withAnimation(.easeOut(duration: 1.0)) { burst = 1 }
            if session.hapticsOn && (userTriggered || !first) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            await rattle()
            first = false
            try? await Task.sleep(for: .milliseconds(2000))
        }
    }

    private func rattle() async {
        for value: CGFloat in [7, -6, 4, -3, 0] {
            withAnimation(.linear(duration: 0.04)) { shake = value }
            try? await Task.sleep(for: .milliseconds(45))
        }
    }
}
