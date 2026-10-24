import Foundation
import Testing
@testable import Tsumesho

/// 1 問の遊びの流れ（駒を選ぶ、指す、正解・不正解、ヒント、3 手詰めの応手）
@MainActor
struct GameTests {
    /// 5×5 の 1 問目の例題（３一玉・３三歩、持ち駒の金。正解は３二金打）
    let tutorial = Problem.tutorial(.small)
    let answerSquare = Square.index(file: 3, rank: 2)

    /// 手 m を、画面と同じようにタップで指す
    func play(_ m: Move, in game: Game) {
        if let from = m.from {
            game.tap(square: from)
        } else {
            game.tap(hand: m.kind)
        }
        game.tap(square: m.to)
        if game.pendingPromotion != nil {
            game.choosePromotion(m.promote)
        }
    }

    @Test func 持ち駒を選ぶと打てるマスが光る() {
        let game = Game(problem: tutorial)
        game.tap(hand: .gold)
        #expect(game.selection == .hand(.gold))
        #expect(game.targets.contains(answerSquare))
        // 5×5 の範囲の外は光らせない
        #expect(game.targets.allSatisfy { Square.file($0) <= 5 && Square.rank($0) <= 5 })
    }

    @Test func 正解を指すと詰みになり_頭金と判定する() {
        let game = Game(problem: tutorial)
        play(Move(from: nil, to: answerSquare, kind: .gold), in: game)
        #expect(game.status == .solved(tesuji: "頭金"))
    }

    @Test func 王手でない手は指せず_盤はそのまま() {
        let game = Game(problem: tutorial)
        let start = game.position.sfenBoard
        play(Move(from: nil, to: Square.index(file: 1, rank: 5), kind: .gold), in: game)
        #expect(game.status == .playing)
        #expect(game.message.hasPrefix("王手になっていません"))
        #expect(game.position.sfenBoard == start)
        #expect(game.mistakes == 1)  // 盤を揺らす
    }

    @Test func 間違えると盤を戻し_正解の手を見せる() {
        let game = Game(problem: tutorial)
        let start = game.position.sfenBoard
        // ２一金打は王手だが、玉に取られる
        play(Move(from: nil, to: Square.index(file: 2, rank: 1), kind: .gold), in: game)
        #expect(game.status == .failed(answer: "持ち駒の金を３二に打つ"))
        #expect(game.revealedAnswer == Move(from: nil, to: answerSquare, kind: .gold))
        #expect(game.position.sfenBoard == start)
        #expect(game.mistakes == 1)  // 盤を揺らす

        game.reset()
        #expect(game.status == .playing)
        #expect(game.revealedAnswer == nil)
    }

    @Test func ヒントは2段まで_2段目で正解の行き先が光る() {
        let game = Game(problem: tutorial)
        game.showHint()
        #expect(game.hintHandKinds.contains(.gold))
        #expect(game.hintTargets.isEmpty)
        game.showHint()
        game.showHint()
        #expect(game.hintLevel == 2)
        #expect(game.hintTargets == [answerSquare])
        #expect(game.hintsUsed == 2)
    }

    @Test func 三手詰めは玉方が自動で応じ_最終手で詰む() async throws {
        var generator = ProblemGenerator(seed: 7)
        let generated = generator.next(size: .small, plies: 3, maxPieces: 7)
        let problem = try #require(generated)
        let game = Game(problem: problem)
        let inWindow: (Move) -> Bool = { game.position.isInWindow($0.to, span: 5) }

        let first = try #require(game.position.mateMoves(plies: 3, where: inWindow).first)
        play(first, in: game)
        #expect(game.status == .thinking)
        #expect(game.currentPly == 3)

        // 玉方の応手を待つ（0.7 秒）
        for _ in 0..<30 where game.status == .thinking {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(game.status == .playing)

        let last = try #require(game.position.mateMoves(plies: 1, where: inWindow).first)
        play(last, in: game)
        guard case .solved = game.status else {
            Issue.record("最終手で詰んでいない: \(game.status)")
            return
        }
    }
}
