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

struct KomaView: View {
    let label: String
    var promoted = false
    var upsideDown = false
    let size: CGFloat

    var body: some View {
        Text(label)
            .font(Theme.koma(size * 0.5))
            .foregroundStyle(promoted ? Color(red: 0.72, green: 0.12, blue: 0.12) : Theme.pieceInk)
            .padding(.top, size * 0.12)
            .frame(width: size * 0.82, height: size * 0.92)
            .background(KomaShape().fill(Theme.piece).shadow(color: .black.opacity(0.25), radius: 1, y: 1))
            .rotationEffect(.degrees(upsideDown ? 180 : 0))
    }
}

// 将棋盤。9×9 の普通の盤か、玉のまわりの 5×5 を切り出した盤を表示する。
// 本物の盤の端は太い線、切り出した辺は細い線で描く
struct BoardView: View {
    let game: Game

    var body: some View {
        let files = Array(game.visibleFiles.reversed())  // 左から ９ ８ … １（5×5 では切り出した 5 筋）
        let ranks = Array(game.visibleRanks)
        GeometryReader { geo in
            let labelSize: CGFloat = 18
            let cell = (geo.size.width - labelSize) / CGFloat(files.count)
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    ForEach(files, id: \.self) { f in
                        Text(Notation.fileLabel(f)).frame(width: cell)
                    }
                    Spacer().frame(width: labelSize)
                }
                .font(Theme.mono(files.count > 5 ? 10 : 11))
                .foregroundStyle(Theme.soft)

                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(ranks, id: \.self) { r in
                            HStack(spacing: 0) {
                                ForEach(files, id: \.self) { f in
                                    cellView(Square.index(file: f, rank: r), size: cell)
                                }
                            }
                        }
                    }
                    .background(Theme.wood)
                    .overlay { stars(files: files, ranks: ranks, cell: cell) }
                    .overlay(alignment: .top) { edge(isReal: ranks.first == 1, horizontal: true) }
                    .overlay(alignment: .bottom) { edge(isReal: ranks.last == 9, horizontal: true) }
                    .overlay(alignment: .leading) { edge(isReal: files.first == 9, horizontal: false) }
                    .overlay(alignment: .trailing) { edge(isReal: files.last == 1, horizontal: false) }

                    VStack(spacing: 0) {
                        ForEach(ranks, id: \.self) { r in
                            Text(Notation.rankLabel(r)).frame(width: labelSize, height: cell)
                        }
                    }
                    .font(.system(size: files.count > 5 ? 10 : 11, weight: .bold))
                    .foregroundStyle(Theme.soft)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.25), value: game.smallBoard)
    }

    private func edge(isReal: Bool, horizontal: Bool) -> some View {
        let width: CGFloat = isReal ? 3 : 1
        return Rectangle()
            .fill(Theme.woodLine.opacity(isReal ? 1 : 0.5))
            .frame(width: horizontal ? nil : width, height: horizontal ? width : nil)
            .allowsHitTesting(false)
    }

    // 星（盤の目印の点）。三段と四段、六段と七段の間、３筋と４筋、６筋と７筋の間の交点に打つ
    private func stars(files: [Int], ranks: [Int], cell: CGFloat) -> some View {
        let xs = [7, 4].compactMap { f in files.firstIndex(of: f).flatMap { i in i + 1 < files.count ? CGFloat(i + 1) * cell : nil } }
        let ys = [3, 6].compactMap { r in ranks.firstIndex(of: r).flatMap { i in i + 1 < ranks.count ? CGFloat(i + 1) * cell : nil } }
        return ZStack(alignment: .topLeading) {
            ForEach(xs, id: \.self) { x in
                ForEach(ys, id: \.self) { y in
                    Circle().fill(Theme.woodLine).frame(width: 5, height: 5).position(x: x, y: y)
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

        Button {
            game.tap(square: i)
        } label: {
            ZStack {
                Rectangle().strokeBorder(Theme.woodLine.opacity(0.7), lineWidth: 0.5)
                if isLast { Rectangle().fill(Theme.hint.opacity(0.22)) }
                if isTarget { RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.55)).padding(3) }
                if isSelected { RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.85)).padding(2) }
                if isHintSource || isHintTarget {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.hint, lineWidth: 3).padding(2)
                }
                if isRevealed {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.ok.opacity(0.35)).padding(2)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.ok, lineWidth: 3).padding(2)
                }
                if let piece {
                    KomaView(label: Notation.label(piece), promoted: piece.promoted,
                             upsideDown: piece.side == .white, size: size)
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
