// 詰将棋の問題をランダムに作る。アプリは 2 問目からこれで作った問題を出し続ける。
// Tools/test.sh でも、同じ処理で作った問題が条件を満たすかを確かめている。
//
// 攻め駒・玉方の駒・持ち駒をランダムに置き、ソルバーで
// 「ちょうど N 手で詰む」「正解の初手が一つだけ」「最初から王手になっていない」
// 局面だけを残す。盤の大きさで作り方を変える。
//   5×5 用：駒を玉のまわりに置き、5×5 の盤（範囲の外は壁）で解く
//   7×7 用：飛・角・香・龍・馬は 7×7 の範囲のどこからでも利かせ、7×7 の盤（範囲の外は壁）で解いて、
//           5×5 の範囲の外にも駒がある局面だけを残す
//   9×9 用：飛・角・香・龍・馬は盤のどこからでも利かせ、5×5 の範囲の外にも駒がある局面だけを残す

struct SplitMix64 {
    var state: UInt64

    /// 次の 64 ビットの乱数を返す（SplitMix64）
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// range の中の整数を一つ選ぶ
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    /// 配列から要素を一つ選ぶ
    mutating func pick<T>(_ xs: [T]) -> T { xs[int(0...xs.count - 1)] }
}

struct ProblemGenerator {
    private var rng: SplitMix64
    private var seen = Set<String>()

    /// 乱数の種を決めて作る。同じ種なら同じ順に問題ができる
    init(seed: UInt64) {
        rng = SplitMix64(state: seed)
    }

    private static let attackers: [Piece] = [
        Piece(side: .black, kind: .gold), Piece(side: .black, kind: .silver), Piece(side: .black, kind: .rook),
        Piece(side: .black, kind: .bishop), Piece(side: .black, kind: .knight), Piece(side: .black, kind: .pawn),
        Piece(side: .black, kind: .pawn, promoted: true), Piece(side: .black, kind: .rook, promoted: true),
        Piece(side: .black, kind: .bishop, promoted: true), Piece(side: .black, kind: .lance),
    ]
    private static let defenders: [Kind] = [.pawn, .silver, .gold, .lance, .knight]
    private static let handLetters = ["G", "G", "S", "R", "B", "N", "P"]

    /// 条件を満たす問題が見つかるまで局面を作る。maxTries 回で見つからなければ nil。
    /// allowDrop が false なら、正解が持ち駒を打つ手の問題は採らない（正解が金打ばかりにならないように）
    mutating func next(size: BoardSize, plies: Int, maxPieces: Int, allowDrop: Bool = true,
                       maxTries: Int = 200_000) -> Problem? {
        for _ in 0..<maxTries {
            guard let pos = randomPosition(size) else { continue }
            guard seen.insert(pos.sfenBoard + " " + pos.sfenAttackerHand).inserted else { continue }
            guard let problem = Self.evaluate(pos, size: size, plies: plies), problem.pieceCount <= maxPieces else { continue }
            if !allowDrop && problem.answer.hasSuffix("打") { continue }
            return problem
        }
        return nil
    }

    /// 問題の条件を満たしていれば Problem を返す（id は 0。使う側で振る）
    static func evaluate(_ pos: Position, size: BoardSize, plies: Int) -> Problem? {
        /// 盤より小さい範囲で遊ぶときは、駒がすべて範囲に入っていて、範囲の外へはどちらの駒も動けない
        let occupied = pos.board.indices.filter { pos.board[$0] != nil }
        if !occupied.allSatisfy({ pos.isInWindow($0, span: size.span) }) { return nil }
        var pos = pos
        pos.span = size.span
        if pos.inCheck(.white) { return nil }
        if pos.checkMoves().count < 3 { return nil }  // 王手の候補が少なすぎると簡単すぎる
        if plies == 3 && pos.forcesMate(plies: 1) { return nil }  // 早詰め
        let answers = pos.mateMoves(plies: plies)
        guard answers.count == 1 else { return nil }  // 正解の初手は一つだけ
        // 5×5 に収まる問題は 5×5 用に任せ、7×7・9×9 では盤の広さを使う問題だけを残す
        if size != .small && occupied.allSatisfy({ pos.isInWindow($0, span: 5) }) { return nil }
        if plies == 3 && !hasUniqueLastMove(pos, answers[0]) { return nil }
        return Problem(id: 0, size: size, plies: plies, board: pos.sfenBoard, hand: pos.sfenAttackerHand,
                       answer: Notation.label(answers[0], in: pos))
    }

    /// 3 手詰めで、玉方がいちばん粘る応手をしたあと、詰ませる最終手も一つだけか
    private static func hasUniqueLastMove(_ pos: Position, _ first: Move) -> Bool {
        let next = pos.playing(first)
        guard let reply = next.bestDefense(plies: 1) else { return false }
        return next.playing(reply).mateMoves(plies: 1).count == 1
    }

    /// 盤の大きさに合わせて駒をランダムに置いた局面を作る。置けなかったり反則の配置になったりしたら nil
    private mutating func randomPosition(_ size: BoardSize) -> Position? {
        var pos = Position()
        /// 空いているマスに駒を置く。20 回試して置けなければ false
        func place(_ p: Piece, files: ClosedRange<Int>, ranks: ClosedRange<Int>) -> Bool {
            for _ in 0..<20 {
                let i = Square.index(file: rng.int(files), rank: rng.int(ranks))
                if pos.board[i] == nil { pos.board[i] = p; return true }
            }
            return false
        }
        /// 行き所のない駒にならない、いちばん上の段
        func minRank(_ p: Piece) -> Int {
            if p.promoted { return 1 }
            switch p.kind {
            case .knight: return 3
            case .pawn, .lance: return 2
            default: return 1
            }
        }
        let isLongRange: (Piece) -> Bool = { [.rook, .bishop, .lance].contains($0.kind) }

        /// 玉は 5×5・7×7 では一〜二段、9×9 では一〜三段。
        /// 玉方の駒は玉の左右 2 筋の、5×5・7×7 では三段まで、9×9 では玉の 1 段下まで。
        /// 攻め方の駒は玉の左右 2 筋の、5×5 では五段まで、7×7 では六段まで、9×9 では玉の 3 段下まで。
        /// ただし 7×7・9×9 では、飛・角・香（成った駒も）を表示範囲のどこにでも置く
        /// 5×5・7×7 では、玉を表示範囲の右上の隅に置く。左端の筋（盤の端）には置かない
        let kingFile = size == .full ? rng.int(1...9) : rng.int(1...(size.span - 1))
        let kingRank = size == .full ? rng.int(1...3) : rng.int(1...2)
        guard place(Piece(side: .white, kind: .king), files: kingFile...kingFile, ranks: kingRank...kingRank) else { return nil }
        let window = pos.windowFiles(span: size.span)
        let near = max(window.lowerBound, kingFile - 2)...min(window.upperBound, kingFile + 2)
        let defenderLowest = size == .full ? kingRank + 1 : 3
        let attackerLowest = switch size {
        case .small: 5
        case .medium: 6
        case .full: kingRank + 3
        }
        for _ in 0..<rng.int(0...2) {
            guard place(Piece(side: .white, kind: rng.pick(Self.defenders)), files: near, ranks: 1...defenderLowest) else { return nil }
        }
        for _ in 0..<rng.int(1...3) {
            let p = rng.pick(Self.attackers)
            let placed = size != .small && isLongRange(p)
                ? place(p, files: window, ranks: minRank(p)...size.span)
                : place(p, files: near, ranks: minRank(p)...attackerLowest)
            guard placed else { return nil }
        }
        var hand = ""
        for _ in 0..<rng.int(0...2) {
            hand += rng.pick(Self.handLetters)
        }
        // 持ち駒と玉方の残り駒を計算し直すため、SFEN を経由して作り直す
        pos = Position(problem: pos.sfenBoard, attackerHand: hand)
        if pos.hands[.white]!.contains(where: { $0 < 0 }) { return nil }
        // 二歩を除く
        for f in 1...9 {
            for side in [Side.black, .white] {
                let pawns = (1...9).filter { r in
                    let p = pos.board[Square.index(file: f, rank: r)]
                    return p?.side == side && p?.kind == .pawn && p?.promoted == false
                }
                if pawns.count > 1 { return nil }
            }
        }
        return pos
    }
}
