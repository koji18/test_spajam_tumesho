// ルールエンジンと問題のテスト。実行：Tools/test.sh

var failures = 0
func expect(_ ok: Bool, _ name: String) {
    print(ok ? "  ok  \(name)" : "  NG  \(name)")
    if !ok { failures += 1 }
}

let inView: (Move) -> Bool = { Square.file($0.to) <= 5 && Square.rank($0.to) <= 5 }
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

print("問題（\(problems.count) 問）")
for q in problems {
    let p = q.position
    let name = "Q\(q.id) \(q.plies)手詰め"
    expect(p.hands[.white]!.allSatisfy { $0 >= 0 }, "\(name)：駒の数が正しい")
    expect(!p.inCheck(.white), "\(name)：最初は王手になっていない")
    let shown = p.mateMoves(plies: q.plies, where: inView)
    let all = p.mateMoves(plies: q.plies)
    expect(shown.count == 1 && all == shown, "\(name)：正解の初手は一つだけ（表示範囲の外にも別解がない）")
    expect(shown.first.map { Notation.label($0, in: p) } == q.answer, "\(name)：正解は \(q.answer)")
    if q.plies == 3 {
        expect(!p.forcesMate(plies: 1), "\(name)：1手では詰まない（早詰めがない）")
        let next = p.playing(shown[0])
        if let reply = next.bestDefense(plies: 1, where: inView) {
            expect(next.playing(reply).mateMoves(plies: 1, where: inView).count == 1, "\(name)：玉方の応手のあと、最終手も一つだけ")
        } else {
            expect(false, "\(name)：玉方に応手がある")
        }
    }
}

print(failures == 0 ? "\nすべて合格" : "\n\(failures) 件の失敗")
if failures > 0 { exit(1) }

import Foundation
