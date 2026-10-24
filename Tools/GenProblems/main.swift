// 詰将棋の問題を自動で作り、Tsumesho/Engine/Problems.swift を書き出す。
// 実行：Tools/gen-problems.sh
//
// 玉を右上の隅に置き、攻め駒と持ち駒をランダムに配置して、ソルバーで
// 「ちょうど N 手で詰む」「正解の初手が一つだけ」「最初から王手になっていない」
// 局面だけを残す。画面に出すのは 1〜5 筋 × 一〜五段だけなので、攻め方の手もその中に限る。

import Foundation

struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }
    mutating func pick<T>(_ xs: [T]) -> T { xs[int(0...xs.count - 1)] }
}

let inView: (Move) -> Bool = { Square.file($0.to) <= 5 && Square.rank($0.to) <= 5 }

var rng = SplitMix64(state: 20261024)

let attackers: [Piece] = [
    Piece(side: .black, kind: .gold), Piece(side: .black, kind: .silver), Piece(side: .black, kind: .rook),
    Piece(side: .black, kind: .bishop), Piece(side: .black, kind: .knight), Piece(side: .black, kind: .pawn),
    Piece(side: .black, kind: .pawn, promoted: true), Piece(side: .black, kind: .rook, promoted: true),
    Piece(side: .black, kind: .bishop, promoted: true), Piece(side: .black, kind: .lance),
]
let defenders: [Kind] = [.pawn, .silver, .gold, .lance, .knight]

func randomPosition() -> Position? {
    var pos = Position()
    func place(_ p: Piece, files: ClosedRange<Int>, ranks: ClosedRange<Int>) -> Bool {
        for _ in 0..<20 {
            let i = Square.index(file: rng.int(files), rank: rng.int(ranks))
            if pos.board[i] == nil { pos.board[i] = p; return true }
        }
        return false
    }
    // 玉は 1〜4 筋・一〜二段。3 手詰めでも玉は 1 マスしか動けないので、表示範囲の外へは出ない
    guard place(Piece(side: .white, kind: .king), files: 1...4, ranks: 1...2) else { return nil }
    for _ in 0..<rng.int(0...2) {
        guard place(Piece(side: .white, kind: rng.pick(defenders)), files: 1...5, ranks: 1...3) else { return nil }
    }
    for _ in 0..<rng.int(1...3) {
        let p = rng.pick(attackers)
        let minRank = p.promoted ? 1 : (p.kind == .knight ? 3 : (p.kind == .pawn || p.kind == .lance ? 2 : 1))
        guard place(p, files: 1...5, ranks: minRank...5) else { return nil }
    }
    var hand = ""
    for _ in 0..<rng.int(0...2) {
        hand += ["G", "G", "S", "R", "B", "N", "P"][rng.int(0...6)]
    }
    // 持ち駒と玉方の残り駒を計算し直すため、SFEN を経由して作り直す
    pos = Position(problem: pos.sfenBoard, attackerHand: hand)
    if pos.hands[.white]!.contains(where: { $0 < 0 }) { return nil }
    if pos.inCheck(.white) { return nil }
    // 二歩と行き所のない駒を除く
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

struct Found {
    var plies: Int
    var pos: Position
    var answer: String
    var pieces: Int
}

func evaluate(_ pos: Position, plies: Int) -> Found? {
    let checks = pos.checkMoves(where: inView)
    if checks.count < 3 { return nil }  // 王手の候補が少なすぎると簡単すぎる
    if plies == 3 && pos.forcesMate(plies: 1) { return nil }  // 早詰め
    let shown = pos.mateMoves(plies: plies, where: inView)
    let all = pos.mateMoves(plies: plies)  // 表示範囲の外も含めて、別解がないことを確かめる
    guard shown.count == 1, all.count == 1, shown[0] == all[0] else { return nil }
    if plies == 3 {
        let next = pos.playing(shown[0])
        guard let reply = next.bestDefense(plies: 1, where: inView) else { return nil }
        if next.playing(reply).mateMoves(plies: 1, where: inView).count != 1 { return nil }  // 最終手も一つだけ
    }
    let pieces = pos.board.compactMap { $0 }.count + pos.hands[.black]!.reduce(0, +)
    return Found(plies: plies, pos: pos, answer: Notation.label(shown[0], in: pos), pieces: pieces)
}

// maxDrops：正解が「打つ手」の問題を何問まで採るか。正解が単調にならないようにする
func search(plies: Int, count: Int, maxPieces: Int, maxDrops: Int) -> [Found] {
    var out: [Found] = []
    var drops = 0
    var seen = Set<String>()
    var tries = 0
    while out.count < count && tries < 400_000 {
        tries += 1
        guard let pos = randomPosition() else { continue }
        let key = pos.sfenBoard + pos.sfenAttackerHand
        if seen.contains(key) { continue }
        seen.insert(key)
        if let f = evaluate(pos, plies: plies), f.pieces <= maxPieces {
            let isDrop = f.answer.hasSuffix("打")
            if isDrop && drops >= maxDrops { continue }
            if isDrop { drops += 1 }
            out.append(f)
            FileHandle.standardError.write("\(plies)手詰め \(out.count)/\(count)  \(key)  正解 \(f.answer)\n".data(using: .utf8)!)
        }
    }
    return out
}

// 1 問目は企画書の例題（頭金）。手作りの問題もソルバーで同じ条件を確かめる
let handmade = Position(problem: "4k4/9/4P4/9/9/9/9/9/9", attackerHand: "G")
guard let first = evaluate(handmade, plies: 1) else { fatalError("1 問目の例題が条件を満たしていません") }

let oneMove = [first] + search(plies: 1, count: 6, maxPieces: 5, maxDrops: 2).sorted { $0.pieces < $1.pieces }
let threeMove = search(plies: 3, count: 3, maxPieces: 6, maxDrops: 1).sorted { $0.pieces < $1.pieces }

var source = """
// このファイルは Tools/gen-problems.sh が生成する。手で編集しない。

struct Problem: Identifiable {
    let id: Int
    let plies: Int
    let board: String  // SFEN の盤面部分
    let hand: String   // 攻め方の持ち駒
    let answer: String // 正解の初手（確認用）

    var position: Position { Position(problem: board, attackerHand: hand) }
}

let problems: [Problem] = [

"""
for (i, f) in (oneMove + threeMove).enumerated() {
    source += "    Problem(id: \(i + 1), plies: \(f.plies), board: \"\(f.pos.sfenBoard)\", hand: \"\(f.pos.sfenAttackerHand)\", answer: \"\(f.answer)\"),\n"
}
source += "]\n"

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try! source.write(to: out, atomically: true, encoding: .utf8)
print("\(oneMove.count + threeMove.count) 問を \(out.path) に書き出しました")
