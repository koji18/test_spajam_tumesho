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
    Problem(id: 1, plies: 1, board: "4k4/9/4P4/9/9/9/9/9/9", hand: "G", answer: "５二金打"),
    Problem(id: 2, plies: 1, board: "7k1/9/9/8+B/4B4/9/9/9/9", hand: "G", answer: "２二金打"),
    Problem(id: 3, plies: 1, board: "7k1/8P/7+P1/7+R1/9/9/9/9/9", hand: "", answer: "２二と"),
    Problem(id: 4, plies: 1, board: "6k2/5n1R1/5g3/9/9/9/9/9/9", hand: "G", answer: "３二金打"),
    Problem(id: 5, plies: 1, board: "4p3R/7k1/7s1/9/6+R2/9/9/9/9", hand: "", answer: "３一龍"),
    Problem(id: 6, plies: 1, board: "9/6+B1k/7L1/9/6S2/9/9/9/9", hand: "B", answer: "２二馬"),
    Problem(id: 7, plies: 1, board: "4+RR1lk/9/9/9/9/9/9/9/9", hand: "G", answer: "２一飛成"),
    Problem(id: 8, plies: 3, board: "6k2/9/4N4/5+R3/7B1/9/9/9/9", hand: "G", answer: "３三龍"),
    Problem(id: 9, plies: 3, board: "4g4/7Lk/9/9/6B1N/9/9/9/9", hand: "G", answer: "１三金打"),
    Problem(id: 10, plies: 3, board: "9/8k/7pB/8L/9/9/9/9/9", hand: "SP", answer: "３一角成"),
]
