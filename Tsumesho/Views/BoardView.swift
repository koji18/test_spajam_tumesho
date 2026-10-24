import SwiftUI

// 将棋の駒の五角形
struct KomaShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.16))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.16))
        p.closeSubpath()
        return p
    }
}

// 駒の光らせ方。攻め方はシアン、玉方はピンク、持ち駒は金色で光らせる
enum KomaTone {
    case attacker, defender, hand
}

struct KomaView: View {
    let label: String
    var promoted = false
    var upsideDown = false
    let size: CGFloat
    var tone: KomaTone = .attacker
    @Environment(\.palette) private var palette

    var body: some View {
        if palette.plain { classic } else { neon }
    }

    // 普通の見た目：クリーム色の駒に黒い文字
    private var classic: some View {
        Text(label)
            .font(Theme.koma(size * 0.5))
            .foregroundStyle(promoted ? Color(red: 0.72, green: 0.12, blue: 0.12) : Theme.pieceInk)
            .padding(.top, size * 0.12)
            .frame(width: size * 0.82, height: size * 0.92)
            .background(KomaShape().fill(Theme.piece).shadow(color: .black.opacity(0.25), radius: 1, y: 1))
            .rotationEffect(.degrees(upsideDown ? 180 : 0))
    }

    // ネオンの見た目：黒い駒の縁と文字を光らせる
    @ViewBuilder
    private var neon: some View {
        let glow: Color = switch tone {
        case .attacker: Theme.neonCyan
        case .defender: Theme.neonPink
        case .hand: Theme.goldGlow
        }
        Text(label)
            .font(Theme.koma(size * 0.5))
            .foregroundStyle(textColor(glow))
            .shadow(color: glow.opacity(0.9), radius: 3)
            .padding(.top, size * 0.12)
            .frame(width: size * 0.82, height: size * 0.92)
            .background {
                ZStack {
                    KomaShape().fill(Theme.pieceFill)
                    KomaShape().stroke(glow, lineWidth: max(1.2, size * 0.045))
                }
                .shadow(color: glow.opacity(0.85), radius: size * 0.12)
            }
            .rotationEffect(.degrees(upsideDown ? 180 : 0))
    }

    private func textColor(_ glow: Color) -> Color {
        if tone == .hand { return Theme.cream }
        if promoted { return Theme.goldGlow }
        return tone == .defender ? Theme.neonPink : .white
    }
}

// 将棋盤。9×9 の普通の盤か、玉のまわりの 5×5 を切り出した盤を表示する。
// 外枠は、切り出した辺も含めて 4 辺とも白く光らせる
struct BoardView: View {
    let game: Game
    @Environment(\.palette) private var palette
    @Environment(Session.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moving: Move?
    @State private var lastPresentedMove: Move?
    @State private var rippleStartedAt: Date?

    var body: some View {
        let files = Array(game.visibleFiles.reversed())  // 左から ９ ８ … １（5×5 では切り出した 5 筋）
        let ranks = Array(game.visibleRanks)
        // 筋と段の番号は、マスと同じ座標で位置を決めて置く。
        // 番号の行とマスの行を別々に並べると、スワイプ中などに番号だけがずれることがあるため
        GeometryReader { geo in
            let labelSize: CGFloat = 18
            let cell = (geo.size.width - labelSize) / CGFloat(files.count)
            let gridWidth = cell * CGFloat(files.count)
            let gridHeight = cell * CGFloat(ranks.count)
            ZStack(alignment: .topLeading) {
                ForEach(Array(files.enumerated()), id: \.element) { i, f in
                    // 筋の番号は半角にして Orbitron で出す（全角の数字は Orbitron になく、別のフォントになる）
                    Text(verbatim: "\(f)")
                        .font(Theme.number(files.count > 5 ? 11 : 13, weight: .medium))
                        .foregroundStyle(palette.coordinate)
                        .fixedSize()
                        .position(x: (CGFloat(i) + 0.5) * cell, y: labelSize / 2)
                }

                VStack(spacing: 0) {
                    ForEach(ranks, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(files, id: \.self) { f in
                                cellView(Square.index(file: f, rank: r), size: cell)
                            }
                        }
                    }
                }
                .frame(width: gridWidth, height: gridHeight)
                .background(palette.boardFill)
                .shadow(color: .white.opacity(0.18 * palette.glow), radius: 16)
                .overlay { stars(files: files, ranks: ranks, cell: cell) }
                .overlay(alignment: .top) { edge(horizontal: true) }
                .overlay(alignment: .bottom) { edge(horizontal: true) }
                .overlay(alignment: .leading) { edge(horizontal: false) }
                .overlay(alignment: .trailing) { edge(horizontal: false) }
                .offset(y: labelSize)

                ForEach(Array(ranks.enumerated()), id: \.element) { j, r in
                    Text(Notation.rankLabel(r))
                        .font(.system(size: files.count > 5 ? 10 : 11, weight: .bold))
                        .foregroundStyle(palette.coordinate)
                        .fixedSize()
                        .position(x: gridWidth + labelSize / 2, y: labelSize + (CGFloat(j) + 0.5) * cell)
                }

                if let move = moving, let piece = game.position.board[move.to], !reduceMotion {
                    let target = point(for: move.to, files: files, ranks: ranks, cell: cell)
                    let source = move.from.map { point(for: $0, files: files, ranks: ranks, cell: cell) }
                        ?? CGPoint(x: target.x, y: target.y + cell * 0.9)
                    LandingKoma(piece: piece, source: source, target: target, cell: cell)
                        .id(move)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .modifier(MateRippleEffect(
                origin: game.lastMove.map { point(for: $0.to, files: files, ranks: ranks, cell: cell) } ?? .zero,
                startedAt: rippleStartedAt, reduceMotion: reduceMotion))
        }
        .aspectRatio(1, contentMode: .fit)
        .modifier(ShakeEffect(animatableData: reduceMotion ? 0 : CGFloat(game.mistakes)))
        .animation(.linear(duration: 0.4), value: game.mistakes)
        .task(id: game.lastMove) {
            rippleStartedAt = nil
            guard let move = game.lastMove else {
                moving = nil
                lastPresentedMove = nil
                return
            }
            guard move != lastPresentedMove else { return }
            lastPresentedMove = move
            moving = move
            do {
                if !reduceMotion { try await Task.sleep(for: .milliseconds(180)) }
                try Task.checkCancellation()
                // 修行は静かに解く画面なので、駒を置いても振動しない
                Haptics.play(.landing, enabled: session.hapticsOn && session.mode != .zen)
                if case .solved = game.status, !reduceMotion { rippleStartedAt = Date() }
                try await Task.sleep(for: .milliseconds(180))
                moving = nil
                try await Task.sleep(for: .milliseconds(720))
                rippleStartedAt = nil
            } catch { }
        }
        .onDisappear { moving = nil; rippleStartedAt = nil }
    }

    private func point(for square: Int, files: [Int], ranks: [Int], cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(files.firstIndex(of: Square.file(square)) ?? 0) + 0.5) * cell,
                y: 18 + (CGFloat(ranks.firstIndex(of: Square.rank(square)) ?? 0) + 0.5) * cell)
    }

    // 盤の外枠の光る線
    private func edge(horizontal: Bool) -> some View {
        Rectangle()
            .fill(palette.boardEdge)
            .frame(width: horizontal ? nil : 2, height: horizontal ? 2 : nil)
            .shadow(color: .white.opacity(0.7 * palette.glow), radius: 5)
            .allowsHitTesting(false)
    }

    // 星（盤の目印の点）。三段と四段、六段と七段の間、３筋と４筋、６筋と７筋の間の交点に打つ
    private func stars(files: [Int], ranks: [Int], cell: CGFloat) -> some View {
        let xs = [7, 4].compactMap { f in files.firstIndex(of: f).flatMap { i in i + 1 < files.count ? CGFloat(i + 1) * cell : nil } }
        let ys = [3, 6].compactMap { r in ranks.firstIndex(of: r).flatMap { i in i + 1 < ranks.count ? CGFloat(i + 1) * cell : nil } }
        return ZStack(alignment: .topLeading) {
            ForEach(xs, id: \.self) { x in
                ForEach(ys, id: \.self) { y in
                    Circle().fill(palette.boardEdge.opacity(0.7)).frame(width: 4, height: 4).position(x: x, y: y)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cellView(_ i: Int, size: CGFloat) -> some View {
        let piece = game.position.board[i]
        let isSelected = game.selection == .square(i)
        let isTarget = game.targets.contains(i)
        let isLast = game.lastMove?.to == i
        let isHintSource = game.hintSources.contains(i)
        let isHintTarget = game.hintTargets.contains(i)
        let isRevealed = game.revealedAnswer.map { $0.from == i || $0.to == i } ?? false
        let isRefutation = game.refutation.map { $0.from == i || $0.to == i } ?? false

        Button {
            game.tap(square: i)
        } label: {
            ZStack {
                Rectangle().strokeBorder(palette.gridLine, lineWidth: 0.5)
                if isLast { Rectangle().fill(palette.lastMove.opacity(0.18)) }
                if isTarget {
                    RoundedRectangle(cornerRadius: 4).fill(palette.target.opacity(palette.targetFill)).padding(2)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(palette.target.opacity(0.9), lineWidth: palette.plain ? 2 : 1.5).padding(2)
                }
                if isSelected {
                    RoundedRectangle(cornerRadius: 4).fill(palette.selection.opacity(palette.selectionFill)).padding(1)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(palette.selection, lineWidth: palette.plain ? 2.5 : 2).padding(1)
                        .shadow(color: palette.selection.opacity(palette.glow), radius: 5)
                }
                if isHintSource || isHintTarget {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.hint, lineWidth: 3).padding(2)
                }
                if isRefutation {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.neonPink.opacity(0.25)).padding(2)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.neonPink, lineWidth: 3).padding(2)
                        .shadow(color: Theme.neonPink.opacity(palette.glow), radius: 5)
                }
                if isRevealed {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.ok.opacity(0.35)).padding(2)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.ok, lineWidth: 3).padding(2)
                }
                if let piece, moving?.to != i || reduceMotion {
                    KomaView(label: Notation.label(piece), promoted: piece.promoted,
                             upsideDown: piece.side == .white, size: size,
                             tone: piece.side == .white ? .defender : .attacker)
                        .scaleEffect(isSelected && !reduceMotion ? 1.13 : 1)
                        .offset(y: isSelected && !reduceMotion ? -4 : 0)
                        .animation(.spring(duration: 0.2), value: isSelected)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(i, piece))
    }

    private func accessibilityText(_ i: Int, _ piece: Piece?) -> String {
        let at = Notation.fileLabel(Square.file(i)) + Notation.rankLabel(Square.rank(i))
        guard let piece else { return at }
        return at + (piece.side == .white ? "　玉方の" : "　") + Notation.label(piece)
    }
}

private struct LandingKoma: View {
    let piece: Piece
    let source: CGPoint
    let target: CGPoint
    let cell: CGFloat

    private struct Motion {
        var progress: CGFloat = 0
        var scale: CGFloat = 1.12
        var lift: CGFloat = -8
    }

    var body: some View {
        KomaView(label: Notation.label(piece), promoted: piece.promoted,
                 upsideDown: piece.side == .white, size: cell,
                 tone: piece.side == .white ? .defender : .attacker)
            .keyframeAnimator(initialValue: Motion(), repeating: false) { content, motion in
                content
                    .scaleEffect(motion.scale)
                    .position(x: source.x + (target.x - source.x) * motion.progress,
                              y: source.y + (target.y - source.y) * motion.progress + motion.lift)
            } keyframes: { _ in
                KeyframeTrack(\.progress) { CubicKeyframe(1, duration: 0.18) }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(0, duration: 0.18)
                    SpringKeyframe(-3, duration: 0.07)
                    SpringKeyframe(0, duration: 0.11)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.9, duration: 0.18)
                    SpringKeyframe(1, duration: 0.18)
                }
            }
    }
}

private struct MateRippleEffect: ViewModifier {
    let origin: CGPoint
    let startedAt: Date?
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: startedAt == nil || reduceMotion)) { context in
            let elapsed = startedAt.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            content.layerEffect(
                ShaderLibrary.mateRipple(.float2(origin), .float(Float(elapsed))),
                maxSampleOffset: CGSize(width: 16, height: 16),
                isEnabled: startedAt != nil && elapsed < 0.9 && !reduceMotion)
        }
    }
}

/// 盤を左右に揺らす動き。animatableData が 1 増えるあいだに 3 往復する
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    /// 揺れの横ずれ。往復の真ん中ほど大きく、始めと終わりは 0
    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = 9 * sin(animatableData * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
