// 問題を遊ぶ盤の大きさ。5×5 用と 9×9 用で作り方が違う（Generator.swift）
enum BoardSize: String, CaseIterable {
    case small  // 玉のまわりの 5×5
    case full   // 普通の 9×9
}

struct Problem: Identifiable {
    var id: Int
    let size: BoardSize
    let plies: Int
    let board: String   // SFEN の盤面部分
    let hand: String    // 攻め方の持ち駒
    let answer: String  // 正解の初手（確認用）

    var position: Position { Position(problem: board, attackerHand: hand) }

    // 画面で問題を見分けるためのキー。id は盤の大きさごとに 1 から振るので、大きさと組にする
    var key: String { "\(size.rawValue)-\(id)" }

    // 1 問目はどちらの盤でも企画書の例題（頭金）。1 問目の操作の案内はこの問題に合わせてある。
    // 2 問目からはアプリがその場で作る
    static func tutorial(_ size: BoardSize) -> Problem {
        Problem(id: 1, size: size, plies: 1, board: "4k4/9/4P4/9/9/9/9/9/9", hand: "G", answer: "５二金打")
    }

    // 盤上の駒と攻め方の持ち駒の数。少ないほど見た目がすっきりする
    var pieceCount: Int {
        let pos = position
        return pos.board.compactMap { $0 }.count + pos.hands[.black]!.reduce(0, +)
    }
}

// 5×5 の小さい盤で遊ぶときの表示範囲。玉を中心に 5 筋 × 一〜五段を切り出し、盤の端でははみ出さないようにずらす。
// 5×5 用の問題は、駒がすべてこの範囲に入り、範囲の中だけで指しても正解が変わらないことを確かめている。
extension Position {
    static let smallRanks = 1...5

    var smallFiles: ClosedRange<Int> {
        let kingFile = kingSquare(.white).map(Square.file) ?? 5
        let low = min(max(kingFile - 2, 1), 5)
        return low...(low + 4)
    }

    func isInSmallBoard(_ square: Int) -> Bool {
        smallFiles.contains(Square.file(square)) && Self.smallRanks.contains(Square.rank(square))
    }
}
