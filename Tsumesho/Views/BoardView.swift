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

// 1〜5 筋 × 一〜五段を切り出した盤。右と上が本物の盤の端
struct BoardView: View {
    let game: Game

    private let files = Array(Game.files.reversed())  // 左から ５ ４ ３ ２ １
    private let ranks = Array(Game.ranks)

    var body: some View {
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
                .font(Theme.mono(11))
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
                    .overlay(alignment: .top) { Rectangle().fill(Theme.woodLine).frame(height: 3) }
                    .overlay(alignment: .trailing) { Rectangle().fill(Theme.woodLine).frame(width: 3) }

                    VStack(spacing: 0) {
                        ForEach(ranks, id: \.self) { r in
                            Text(Notation.rankLabel(r)).frame(width: labelSize, height: cell)
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.soft)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cellView(_ i: Int, size: CGFloat) -> some View {
        let piece = game.position.board[i]
        let isSelected = game.selection == .square(i)
        let isTarget = game.targets.contains(i)
        let isLast = game.lastMove?.to == i
        let isHintSource = game.hintSources.contains(i)
        let isHintTarget = game.hintTargets.contains(i)

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
