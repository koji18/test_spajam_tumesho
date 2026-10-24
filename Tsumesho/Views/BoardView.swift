import SwiftUI

/// 将棋の駒の五角形
struct KomaShape: Shape {
    /// r に収まる駒の五角形
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

/// 駒の光らせ方。攻め方はシアン、玉方はピンク、持ち駒は金色で光らせる
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

    /// 普通の見た目：クリーム色の駒に黒い文字
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

    /// ネオンの見た目での駒の文字の色
    private func textColor(_ glow: Color) -> Color {
        if tone == .hand { return Theme.cream }
        if promoted { return Theme.goldGlow }
        return tone == .defender ? Theme.neonPink : .white
    }
}

/// 将棋盤。9×9 の普通の盤か、玉のまわりの 5×5 を切り出した盤を表示する。
/// 外枠は、切り出した辺も含めて 4 辺とも白く光らせる
struct BoardView: View {
    let game: Game
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 動かした駒の分身。指した瞬間に元のマスに置き、行き先まで滑らせる。着くまで行き先の本物は隠す
    struct Flight: Equatable {
        let id = UUID()
        let move: Move
        let piece: Piece
        var arrived = false
    }
    @State private var flight: Flight?
    /// 持ち駒を打ったマス。打った駒を少し大きく出してから縮めて収める
    @State private var droppedSquare: Int?

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

                if let flight, let from = flight.move.from,
                   let start = center(of: from, files: files, ranks: ranks, cell: cell, labelSize: labelSize),
                   let end = center(of: flight.move.to, files: files, ranks: ranks, cell: cell, labelSize: labelSize) {
                    koma(flight.piece, size: cell)
                        .frame(width: cell, height: cell)
                        .position(flight.arrived ? end : start)
                        .allowsHitTesting(false)
                }

                ForEach(Array(ranks.enumerated()), id: \.element) { j, r in
                    Text(Notation.rankLabel(r))
                        .font(.system(size: files.count > 5 ? 10 : 11, weight: .bold))
                        .foregroundStyle(palette.coordinate)
                        .fixedSize()
                        .position(x: gridWidth + labelSize / 2, y: labelSize + (CGFloat(j) + 0.5) * cell)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio(1, contentMode: .fit)
        // 間違えたら盤を左右に揺らす
        .modifier(ShakeEffect(animatableData: reduceMotion ? 0 : CGFloat(game.mistakes)))
        .animation(.linear(duration: 0.4), value: game.mistakes)
        .onChange(of: game.lastMove) { _, move in
            if let move { animate(move) }
        }
    }

    /// 指した手を動きで見せる。盤の上の駒は滑らせ、打った駒は大きく出してから収める
    private func animate(_ move: Move) {
        guard !reduceMotion, let piece = game.position.board[move.to] else { return }
        if move.from != nil {
            let f = Flight(move: move, piece: piece)
            flight = f
            Task {
                // 分身を元のマスに一度描いてから動かす
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(.easeOut(duration: 0.22)) { flight?.arrived = true }
                try? await Task.sleep(for: .milliseconds(240))
                if flight?.id == f.id { flight = nil }
            }
        } else {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { droppedSquare = move.to }
            Task {
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(.spring(duration: 0.35, bounce: 0.5)) { droppedSquare = nil }
            }
        }
    }

    /// マスの中心の座標。表示範囲の外のマスなら nil
    private func center(of square: Int, files: [Int], ranks: [Int], cell: CGFloat, labelSize: CGFloat) -> CGPoint? {
        guard let i = files.firstIndex(of: Square.file(square)),
              let j = ranks.firstIndex(of: Square.rank(square)) else { return nil }
        return CGPoint(x: (CGFloat(i) + 0.5) * cell, y: labelSize + (CGFloat(j) + 0.5) * cell)
    }

    /// 盤の上の駒。玉方は逆さにしてピンク、攻め方はシアンで光らせる
    private func koma(_ piece: Piece, size: CGFloat) -> some View {
        KomaView(label: Notation.label(piece), promoted: piece.promoted,
                 upsideDown: piece.side == .white, size: size,
                 tone: piece.side == .white ? .defender : .attacker)
    }

    /// 盤の外枠の光る線
    private func edge(horizontal: Bool) -> some View {
        Rectangle()
            .fill(palette.boardEdge)
            .frame(width: horizontal ? nil : 2, height: horizontal ? 2 : nil)
            .shadow(color: .white.opacity(0.7 * palette.glow), radius: 5)
            .allowsHitTesting(false)
    }

    /// 星（盤の目印の点）。三段と四段、六段と七段の間、３筋と４筋、６筋と７筋の間の交点に打つ
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

    /// 盤の 1 マス。駒と、動けるマス・選択・ヒント・正解の光を重ねる
    @ViewBuilder
    private func cellView(_ i: Int, size: CGFloat) -> some View {
        let piece = game.position.board[i]
        let isSelected = game.selection == .square(i)
        let isTarget = game.targets.contains(i)
        let isLast = game.lastMove?.to == i
        let isHintSource = game.hintSources.contains(i)
        let isHintTarget = game.hintTargets.contains(i)
        let isRevealed = game.revealedAnswer.map { $0.from == i || $0.to == i } ?? false

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
                if isRevealed {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.ok.opacity(0.35)).padding(2)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.ok, lineWidth: 3).padding(2)
                }
                // 動いている途中の駒は、分身が着くまで隠す
                if let piece, flight?.move.to != i {
                    koma(piece, size: size)
                        .scaleEffect(droppedSquare == i ? 1.45 : 1)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(i, piece))
    }

    /// マスの読み上げ。例「５一　玉方の玉」
    private func accessibilityText(_ i: Int, _ piece: Piece?) -> String {
        let at = Notation.fileLabel(Square.file(i)) + Notation.rankLabel(Square.rank(i))
        guard let piece else { return at }
        return at + (piece.side == .white ? "　玉方の" : "　") + Notation.label(piece)
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
