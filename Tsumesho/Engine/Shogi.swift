// 詰将棋用のルールエンジン。UI から切り離した値型と関数だけで書き、
// Tools/ のコマンドライン（テストと問題の生成）からもそのまま使う。
//
// 座標：筋（file）は 1〜9 で右から左、段（rank）は 1〜9 で上から下。
// 攻め方は先手（.black）、玉方は後手（.white）。攻め方は玉を持たない。

enum Side {
    case black, white
    var opponent: Side { self == .black ? .white : .black }
}

enum Kind: Int, CaseIterable {
    // 持ち駒になる 7 種を先に並べ、rawValue を持ち駒配列の添字に使う
    case pawn, lance, knight, silver, gold, bishop, rook, king

    static let handKinds: [Kind] = [.rook, .bishop, .gold, .silver, .knight, .lance, .pawn]

    var canPromote: Bool { self != .gold && self != .king }
}

struct Piece: Equatable {
    var side: Side
    var kind: Kind
    var promoted = false
}

struct Move: Hashable {
    var from: Int?  // nil は持ち駒を打つ手
    var to: Int
    var kind: Kind
    var promote = false
}

struct Position {
    var board: [Piece?] = Array(repeating: nil, count: 81)  // 添字 = (rank - 1) * 9 + (file - 1)
    var hands: [Side: [Int]] = [.black: Array(repeating: 0, count: 7), .white: Array(repeating: 0, count: 7)]
    var turn: Side = .black
}

enum Square {
    static func index(file: Int, rank: Int) -> Int { (rank - 1) * 9 + (file - 1) }
    static func file(_ i: Int) -> Int { i % 9 + 1 }
    static func rank(_ i: Int) -> Int { i / 9 + 1 }
    static func onBoard(file: Int, rank: Int) -> Bool { (1...9).contains(file) && (1...9).contains(rank) }
}

// MARK: - 駒の動き（先手から見た向き。dr = -1 が前）

private typealias Dir = (df: Int, dr: Int)
private let goldDirs: [Dir] = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (0, 1)]
private let kingDirs: [Dir] = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
private let diagDirs: [Dir] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
private let orthoDirs: [Dir] = [(0, -1), (-1, 0), (1, 0), (0, 1)]

private func steps(_ p: Piece) -> [Dir] {
    if p.promoted {
        switch p.kind {
        case .bishop: return orthoDirs
        case .rook: return diagDirs
        default: return goldDirs
        }
    }
    switch p.kind {
    case .pawn: return [(0, -1)]
    case .knight: return [(-1, -2), (1, -2)]
    case .silver: return [(-1, -1), (0, -1), (1, -1), (-1, 1), (1, 1)]
    case .gold: return goldDirs
    case .king: return kingDirs
    default: return []
    }
}

private func slides(_ p: Piece) -> [Dir] {
    switch p.kind {
    case .lance where !p.promoted: return [(0, -1)]
    case .bishop: return diagDirs
    case .rook: return orthoDirs
    default: return []
    }
}

private let totalPieces = [18, 4, 4, 4, 4, 2, 2]  // 歩 香 桂 銀 金 角 飛

extension Position {
    // 盤上の駒 from が利いているマス
    func targets(from: Int) -> [Int] {
        guard let p = board[from] else { return [] }
        let sign = p.side == .black ? 1 : -1
        let f0 = Square.file(from), r0 = Square.rank(from)
        var out: [Int] = []
        for d in steps(p) {
            let f = f0 + d.df * sign, r = r0 + d.dr * sign
            if Square.onBoard(file: f, rank: r) { out.append(Square.index(file: f, rank: r)) }
        }
        for d in slides(p) {
            var f = f0 + d.df * sign, r = r0 + d.dr * sign
            while Square.onBoard(file: f, rank: r) {
                let i = Square.index(file: f, rank: r)
                out.append(i)
                if board[i] != nil { break }
                f += d.df * sign
                r += d.dr * sign
            }
        }
        return out
    }

    func kingSquare(_ side: Side) -> Int? {
        board.firstIndex { $0?.side == side && $0?.kind == .king }
    }

    func isAttacked(_ target: Int, by side: Side) -> Bool {
        for i in 0..<81 where board[i]?.side == side {
            if targets(from: i).contains(target) { return true }
        }
        return false
    }

    func inCheck(_ side: Side) -> Bool {
        guard let k = kingSquare(side) else { return false }
        return isAttacked(k, by: side.opponent)
    }

    // MARK: 指し手の生成

    private static func inZone(_ side: Side, _ rank: Int) -> Bool { side == .black ? rank <= 3 : rank >= 7 }

    // 行き所のない駒になるマスか（歩・香は最終段、桂は最後の 2 段）
    private static func isDeadEnd(_ kind: Kind, _ side: Side, _ rank: Int) -> Bool {
        let ahead = side == .black ? rank - 1 : 9 - rank
        switch kind {
        case .pawn, .lance: return ahead < 1
        case .knight: return ahead < 2
        default: return false
        }
    }

    private func hasPawn(onFile file: Int, side: Side) -> Bool {
        (1...9).contains { r in
            let p = board[Square.index(file: file, rank: r)]
            return p?.side == side && p?.kind == .pawn && p?.promoted == false
        }
    }

    private func pseudoMoves() -> [Move] {
        var moves: [Move] = []
        for from in 0..<81 {
            guard let p = board[from], p.side == turn else { continue }
            for to in targets(from: from) {
                if board[to]?.side == turn { continue }
                let zone = Self.inZone(turn, Square.rank(from)) || Self.inZone(turn, Square.rank(to))
                if !p.promoted && p.kind.canPromote && zone {
                    moves.append(Move(from: from, to: to, kind: p.kind, promote: true))
                    if !Self.isDeadEnd(p.kind, turn, Square.rank(to)) {
                        moves.append(Move(from: from, to: to, kind: p.kind))
                    }
                } else {
                    moves.append(Move(from: from, to: to, kind: p.kind))
                }
            }
        }
        let hand = hands[turn]!
        for kind in Kind.handKinds where hand[kind.rawValue] > 0 {
            for to in 0..<81 where board[to] == nil {
                if Self.isDeadEnd(kind, turn, Square.rank(to)) { continue }
                if kind == .pawn && hasPawn(onFile: Square.file(to), side: turn) { continue }  // 二歩
                moves.append(Move(from: nil, to: to, kind: kind))
            }
        }
        return moves
    }

    func playing(_ m: Move) -> Position {
        var next = self
        if let from = m.from {
            let p = board[from]!
            if let captured = board[m.to], captured.kind != .king {
                next.hands[turn]![captured.kind.rawValue] += 1
            }
            next.board[from] = nil
            next.board[m.to] = Piece(side: turn, kind: p.kind, promoted: p.promoted || m.promote)
        } else {
            next.hands[turn]![m.kind.rawValue] -= 1
            next.board[m.to] = Piece(side: turn, kind: m.kind)
        }
        next.turn = turn.opponent
        return next
    }

    func legalMoves(checkPawnDropMate: Bool = true) -> [Move] {
        pseudoMoves().filter { m in
            let next = playing(m)
            if next.inCheck(turn) { return false }
            // 打ち歩詰め：歩を打って詰ませるのは反則
            if checkPawnDropMate && m.from == nil && m.kind == .pawn && next.inCheck(next.turn) {
                if next.legalMoves(checkPawnDropMate: false).isEmpty { return false }
            }
            return true
        }
    }

    func givesCheck(_ m: Move) -> Bool { playing(m).inCheck(turn.opponent) }

    func checkMoves(where filter: ((Move) -> Bool)? = nil) -> [Move] {
        legalMoves().filter { (filter?($0) ?? true) && givesCheck($0) }
    }

    var isMate: Bool { inCheck(turn) && legalMoves().isEmpty }

    // MARK: 詰みの探索

    // plies 手以内に詰ませられる攻め方の初手をすべて返す
    func mateMoves(plies: Int, where filter: ((Move) -> Bool)? = nil, firstOnly: Bool = false) -> [Move] {
        var found: [Move] = []
        for m in checkMoves(where: filter) {
            let next = playing(m)
            let replies = next.legalMoves()
            let mates = replies.isEmpty
                || (plies >= 3 && replies.allSatisfy { next.playing($0).forcesMate(plies: plies - 2, where: filter) })
            if mates {
                found.append(m)
                if firstOnly { break }
            }
        }
        return found
    }

    func forcesMate(plies: Int, where filter: ((Move) -> Bool)? = nil) -> Bool {
        !mateMoves(plies: plies, where: filter, firstOnly: true).isEmpty
    }

    // 玉方の応手を選ぶ。攻め方の詰ませ方がいちばん少なくなる手を選び、
    // 同じなら盤上の駒を動かす手を合駒（打つ手）より優先する。
    func bestDefense(plies: Int, where filter: ((Move) -> Bool)? = nil) -> Move? {
        legalMoves().min { a, b in
            score(a, plies, filter) < score(b, plies, filter)
        }
    }

    private func score(_ r: Move, _ plies: Int, _ filter: ((Move) -> Bool)?) -> Int {
        playing(r).mateMoves(plies: plies, where: filter).count * 2 + (r.from == nil ? 1 : 0)
    }

    // MARK: 局面の読み書き

    // SFEN の盤面部分（例 "4k4/9/4P4/9/9/9/9/9/9"）と、攻め方の持ち駒（例 "G" や "2PS"）から局面を作る。
    // 玉方は、盤上と攻め方の持ち駒にない残りの駒をすべて持つ（詰将棋のルール）。
    init(problem boardSFEN: String, attackerHand: String) {
        let letters: [Character: Kind] = ["P": .pawn, "L": .lance, "N": .knight, "S": .silver,
                                          "G": .gold, "B": .bishop, "R": .rook, "K": .king]
        for (ri, row) in boardSFEN.split(separator: "/").enumerated() {
            var file = 9
            var promoted = false
            for ch in row {
                if ch == "+" {
                    promoted = true
                } else if let n = ch.wholeNumberValue {
                    file -= n
                } else if let kind = letters[Character(ch.uppercased())] {
                    board[Square.index(file: file, rank: ri + 1)] =
                        Piece(side: ch.isUppercase ? .black : .white, kind: kind, promoted: promoted)
                    promoted = false
                    file -= 1
                }
            }
        }
        var count = 1
        for ch in attackerHand {
            if let n = ch.wholeNumberValue {
                count = n
            } else if let kind = letters[ch] {
                hands[.black]![kind.rawValue] += count
                count = 1
            }
        }
        var rest = totalPieces
        for k in 0..<7 { rest[k] -= hands[.black]![k] }
        for p in board.compactMap({ $0 }) where p.kind != .king { rest[p.kind.rawValue] -= 1 }
        hands[.white] = rest
    }

    var sfenBoard: String {
        let letters = "PLNSGBRK"
        var rows: [String] = []
        for r in 1...9 {
            var row = ""
            var empty = 0
            for f in stride(from: 9, through: 1, by: -1) {
                guard let p = board[Square.index(file: f, rank: r)] else { empty += 1; continue }
                if empty > 0 { row += String(empty); empty = 0 }
                let ch = letters[letters.index(letters.startIndex, offsetBy: p.kind.rawValue)]
                row += (p.promoted ? "+" : "") + (p.side == .black ? String(ch) : ch.lowercased())
            }
            if empty > 0 { row += String(empty) }
            rows.append(row)
        }
        return rows.joined(separator: "/")
    }

    var sfenAttackerHand: String {
        let letters: [Kind: String] = [.rook: "R", .bishop: "B", .gold: "G", .silver: "S",
                                       .knight: "N", .lance: "L", .pawn: "P"]
        return Kind.handKinds.map { k in
            let n = hands[.black]![k.rawValue]
            return n == 0 ? "" : (n > 1 ? String(n) : "") + letters[k]!
        }.joined()
    }
}

// MARK: - 表示用の名前

enum Notation {
    private static let names: [Kind: String] = [.pawn: "歩", .lance: "香", .knight: "桂", .silver: "銀",
                                                .gold: "金", .bishop: "角", .rook: "飛", .king: "玉"]
    private static let promotedNames: [Kind: String] = [.pawn: "と", .lance: "杏", .knight: "圭",
                                                        .silver: "全", .bishop: "馬", .rook: "龍"]
    private static let ranks = Array("一二三四五六七八九")
    private static let files = Array("１２３４５６７８９")

    static func label(_ p: Piece) -> String { p.promoted ? promotedNames[p.kind]! : names[p.kind]! }
    static func label(_ k: Kind) -> String { names[k]! }
    static func rankLabel(_ r: Int) -> String { String(ranks[r - 1]) }
    static func fileLabel(_ f: Int) -> String { String(files[f - 1]) }

    // 例「５二金打」「２三銀成」
    static func label(_ m: Move, in pos: Position) -> String {
        let at = fileLabel(Square.file(m.to)) + rankLabel(Square.rank(m.to))
        guard let from = m.from, let p = pos.board[from] else { return at + names[m.kind]! + "打" }
        let couldPromote = p.kind.canPromote && !p.promoted
            && (p.side == .black ? min(Square.rank(from), Square.rank(m.to)) <= 3 : max(Square.rank(from), Square.rank(m.to)) >= 7)
        return at + label(p) + (m.promote ? "成" : couldPromote ? "不成" : "")
    }

    // 初心者向けの説明。例「３三の龍を４二へ」「２三の角を３二へ動かして成る」「持ち駒の金を５二に打つ」。
    // 「４二龍」だけだと、同じ場所へ動ける駒が 2 枚あるときにどちらかわからないため
    static func describe(_ m: Move, in pos: Position) -> String {
        let at = fileLabel(Square.file(m.to)) + rankLabel(Square.rank(m.to))
        guard let from = m.from, let p = pos.board[from] else { return "持ち駒の\(names[m.kind]!)を\(at)に打つ" }
        let origin = fileLabel(Square.file(from)) + rankLabel(Square.rank(from))
        return "\(origin)の\(label(p))を\(at)へ" + (m.promote ? "動かして成る" : "")
    }

    // 手筋の名前。判定できるものだけ返す
    static func tesuji(_ m: Move, in pos: Position, captured: Bool) -> String? {
        if captured { return "捨て駒" }
        guard let k = pos.kingSquare(.white), Square.rank(k) < 9 else { return nil }
        let head = Square.index(file: Square.file(k), rank: Square.rank(k) + 1)
        let isGold = m.kind == .gold && (m.from.flatMap { pos.board[$0]?.promoted } ?? false) == false
        if isGold && m.to == head && pos.playing(m).isMate { return "頭金" }
        return nil
    }
}
