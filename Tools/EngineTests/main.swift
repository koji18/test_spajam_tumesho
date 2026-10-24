// ルールエンジンと問題のテスト。実行：Tools/test.sh

var failures = 0
func expect(_ ok: Bool, _ name: String) {
    print(ok ? "  ok  \(name)" : "  NG  \(name)")
    if !ok { failures += 1 }
}

let at = Square.index

print("ルール")
do {
    let p = Position(problem: "4k4/9/4P4/9/9/9/9/9/9", attackerHand: "G")
    let mates = p.mateMoves(plies: 1)
    expect(mates.map { Notation.label($0, in: p) } == ["５二金打"], "頭金の例題は５二金打だけで詰む")
    expect(Notation.tesuji(mates[0], in: p, captured: false) == "頭金", "５二金打を頭金と判定する")
    expect(p.hands[.white]! == [17, 4, 4, 4, 3, 2, 2], "玉方は残りの駒をすべて持つ")
}
do {
    // １一玉、２一桂（玉方）、２三金。１二歩打は詰みになるので反則
    let p = Position(problem: "7nk/9/7G1/9/9/9/9/9/9", attackerHand: "P")
    let drop = Move(from: nil, to: at(1, 2), kind: .pawn)
    expect(p.playing(drop).isMate, "１二歩打で玉は動けない（局面の前提）")
    expect(!p.legalMoves().contains(drop), "打ち歩詰めは指せない")
}
do {
    let p = Position(problem: "4k4/9/9/9/4P4/9/9/9/9", attackerHand: "P")
    expect(!p.legalMoves().contains { $0.from == nil && Square.file($0.to) == 5 }, "二歩は指せない")
}
do {
    let p = Position(problem: "4k4/9/9/9/9/9/9/9/9", attackerHand: "PN")
    expect(!p.legalMoves().contains { $0.from == nil && Square.rank($0.to) == 1 }, "一段目には歩も桂も打てない")
    expect(!p.legalMoves().contains { $0.from == nil && $0.kind == .knight && Square.rank($0.to) == 2 }, "二段目に桂は打てない")
}
do {
    let p = Position(problem: "k8/9/9/9/9/9/9/9/4P4", attackerHand: "")
    let up = Position(problem: "k8/4P4/9/9/9/9/9/9/9", attackerHand: "")
    let moves = up.legalMoves().filter { $0.from == at(5, 2) }
    expect(moves.count == 1 && moves[0].promote, "一段目に進む歩は必ず成る")
    expect(p.legalMoves().allSatisfy { !$0.promote }, "敵陣の外では成れない")
}
do {
    // 攻め方の手でも、玉方の駒が自玉を守っている（ピン）ときは動けない
    let p = Position(problem: "4k4/4g4/9/9/4R4/9/9/9/9", attackerHand: "")
    var w = p
    w.turn = .white
    expect(!w.legalMoves().contains { $0.from == at(5, 2) && Square.file($0.to) != 5 }, "ピンされた金は筋から外れられない")
}

// 出題する問題の条件。固定の問題にも、アプリが裏で作る問題にも同じ条件をかける
func check(_ q: Problem, _ name: String) {
    let p = q.position
    expect(p.hands[.white]!.allSatisfy { $0 >= 0 }, "\(name)：駒の数が正しい")
    expect(!p.inCheck(.white), "\(name)：最初は王手になっていない")
    let answers = p.mateMoves(plies: q.plies)
    expect(answers.count == 1, "\(name)：正解の初手は一つだけ")
    expect(answers.first.map { Notation.label($0, in: p) } == q.answer, "\(name)：正解は \(q.answer)")
    let occupied = p.board.indices.filter { p.board[$0] != nil }
    let span = q.size.span
    if span < 9 {
        let window: (Move) -> Bool = { p.isInWindow($0.to, span: span) }
        expect(occupied.allSatisfy { p.isInWindow($0, span: span) } && p.mateMoves(plies: q.plies, where: window) == answers,
               "\(name)：\(q.size.label) の範囲だけで同じ正解になる")
    }
    if q.size != .small && q.id != 1 {  // 1 問目はどの盤でも同じチュートリアル用の例題
        expect(!occupied.allSatisfy { p.isInWindow($0, span: 5) }, "\(name)：5×5 の範囲の外にも駒がある（盤の広さを使う）")
    }
    if q.plies == 3 {
        expect(!p.forcesMate(plies: 1), "\(name)：1手では詰まない（早詰めがない）")
        let next = p.playing(answers[0])
        if let reply = next.bestDefense(plies: 1) {
            expect(next.playing(reply).mateMoves(plies: 1).count == 1, "\(name)：玉方の応手のあと、最終手も一つだけ")
        } else {
            expect(false, "\(name)：玉方に応手がある")
        }
    }
}

do {
    // ３二龍と３三龍のどちらも４二へ動ける局面。説明では、どちらの龍かがわかるようにする
    let p = Position(problem: "4k4/6+R2/3s2+R2/9/9/9/9/9/9", attackerHand: "")
    let m = Move(from: at(3, 3), to: at(4, 2), kind: .rook)
    expect(Notation.describe(m, in: p) == "３三の龍を４二へ", "動かす駒の場所を説明に入れる")
    expect(Notation.describe(Move(from: nil, to: at(5, 2), kind: .gold), in: p) == "持ち駒の金を５二に打つ", "打つ手の説明")
}

print("1 問目の例題")
for size in BoardSize.allCases {
    let q = Problem.tutorial(size)
    check(q, "\(size) 1問目")
    // 1 問目の例題はわざと簡単にしてあるので、どの盤でも 5×5 用の条件で確かめる
    expect(ProblemGenerator.evaluate(q.position, size: .small, plies: 1)?.answer == q.answer, "\(size) 1問目：問題の条件を満たす")
}

print("アプリと同じ方法で作った問題")
for size in BoardSize.allCases {
    var generator = ProblemGenerator(seed: 7)
    for (i, plies) in [1, 1, 1, 3, 3, 3].enumerated() {
        let start = Date()
        guard let q = generator.next(size: size, plies: plies, maxPieces: plies == 1 ? 6 : 7) else {
            expect(false, "\(size) 生成\(i + 1)：\(plies)手詰めが作れる")
            continue
        }
        let seconds = Date().timeIntervalSince(start)
        check(q, String(format: "\(size) 生成\(i + 1) \(plies)手詰め（%.2f 秒）", seconds))
    }
}

print(failures == 0 ? "\nすべて合格" : "\n\(failures) 件の失敗")
if failures > 0 { exit(1) }

import Foundation
