/// 問題を遊ぶ盤の大きさ。大きさごとに作り方が違う（Generator.swift）
enum BoardSize: String, CaseIterable, Codable {
    case small   // 玉のまわりの 5×5
    case medium  // 玉のまわりの 7×7
    case full    // 普通の 9×9

    /// 盤の一辺のマス数
    var span: Int {
        switch self {
        case .small: 5
        case .medium: 7
        case .full: 9
        }
    }

    var label: String { "\(span)×\(span)" }
    /// Orbitron で出すとき用。Orbitron には「×」がなく、別のフォントで出てずれるので小文字の x にする
    var displayLabel: String { "\(span)x\(span)" }
}

struct Problem: Identifiable, Codable {
    var id: Int
    let size: BoardSize
    let plies: Int
    let board: String   // SFEN の盤面部分
    let hand: String    // 攻め方の持ち駒
    let answer: String  // 正解の初手（確認用）
    // 入門チュートリアルの問題だけが持つ、この問題で学ぶことの説明（Tutorial.swift）
    var lesson: String? = nil

    /// 問題の最初の局面。5×5・7×7 では、見えている範囲だけを盤にする
    var position: Position {
        var pos = Position(problem: board, attackerHand: hand)
        pos.span = size.span
        return pos
    }

    /// 画面で問題を見分けるためのキー。id は盤の大きさごとに 1 から振るので、大きさと組にする
    var key: String { "\(size.rawValue)-\(id)" }

    /// 1 問目はどの盤でも企画書の例題（頭金）。1 問目の操作の案内はこの問題に合わせてある。
    /// 玉が表示範囲の真ん中に来るように、盤のサイズごとに筋をずらす。2 問目からはアプリがその場で作る
    static func tutorial(_ size: BoardSize) -> Problem {
        switch size {
        case .small:
            Problem(id: 1, size: size, plies: 1, board: "6k2/9/6P2/9/9/9/9/9/9", hand: "G", answer: "３二金打")
        case .medium:
            Problem(id: 1, size: size, plies: 1, board: "5k3/9/5P3/9/9/9/9/9/9", hand: "G", answer: "４二金打")
        case .full:
            Problem(id: 1, size: size, plies: 1, board: "4k4/9/4P4/9/9/9/9/9/9", hand: "G", answer: "５二金打")
        }
    }

    /// 盤上の駒と攻め方の持ち駒の数。少ないほど見た目がすっきりする
    var pieceCount: Int {
        let pos = position
        return pos.board.compactMap { $0 }.count + pos.hands[.black]!.reduce(0, +)
    }
}

/// 9×9 より小さい盤で遊ぶときの表示範囲。いつも右上の隅（1〜span 筋 × 一〜span 段）を切り出す。
/// 問題ごとに切り出す位置を変えると、筋の番号が問題ごとに変わってしまうため。
/// 小さい盤では、この範囲が盤そのもの（Position.span）。範囲の外へは、攻め方も玉方も動けない。
extension Position {
    /// 表示する筋の範囲。9×9 より小さい盤では右上の隅の 1〜span 筋
    func windowFiles(span: Int) -> ClosedRange<Int> {
        1...min(span, 9)
    }

    /// 表示する段の範囲。いつも一段目から span 段目まで
    static func windowRanks(span: Int) -> ClosedRange<Int> { 1...span }

    /// square が表示範囲に入っているか
    func isInWindow(_ square: Int, span: Int) -> Bool {
        windowFiles(span: span).contains(Square.file(square)) && Self.windowRanks(span: span).contains(Square.rank(square))
    }
}
