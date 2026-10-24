import Foundation

@main
struct PracticeTests {
    @MainActor
    static func main() throws {
        let suite = "tsumesho-practice-tests-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        let library = PracticeLibrary(store: store)
        let problem = Problem.tutorial(.small)
        precondition(library.entries.isEmpty)
        library.recordMistake(problem, mode: .timeTrial)
        library.recordMistake(problem, mode: .zen)
        precondition(library.entries.isEmpty, "修行とタイムトライアルのミスは新規保存しない")
        library.recordMistake(problem, mode: .normal)
        var samePosition = problem
        samePosition.id = 99
        library.recordMistake(samePosition, mode: .normal)
        precondition(library.entries.count == 1 && library.entries[0].mistakes == 2,
                     "同じ局面は問題番号が変わっても重複させない")
        let another = Problem(id: problem.id, size: .small, plies: 1,
                              board: "7k1/9/7P1/9/9/9/9/9/9", hand: "G", answer: "２二金打")
        library.recordMistake(another, mode: .normal)
        library.recordMistake(.tutorial(.full), mode: .normal)
        precondition(library.entries.count == 3, "同じ問題番号でも異なる局面を別々に保存する")
        let small = library.problems(size: .small)
        precondition(small.count == 2 && small[0].board == problem.board, "盤サイズとミス回数で出題する")
        let reloaded = PracticeLibrary(store: store)
        let restored = reloaded.problems(size: .small)[0]
        precondition(restored.board == problem.board && restored.hand == problem.hand && restored.plies == problem.plies)
        precondition(restored.position.board == problem.position.board, "再起動後も同じ盤面で練習できる")
        precondition(reloaded.entries.first { $0.id == PracticeLibrary.Entry.key(for: problem) }?.mistakes == 2)
        precondition(!PlayMode.zen.awardsScore && PlayMode.normal.awardsScore && PlayMode.timeTrial.awardsScore)

        let game = Game(problem: problem)
        game.start()
        game.tap(hand: .gold)
        game.tap(square: Square.index(file: 1, rank: 5))
        precondition(game.mistakeCount == 1 && game.status == .playing, "王手でないミスも数える")
        game.tap(hand: .gold)
        game.tap(square: Square.index(file: 1, rank: 5))
        precondition(game.mistakeCount == 2, "同じミスを繰り返しても検知する")
        game.tap(hand: .gold)
        game.tap(square: Square.index(file: 4, rank: 1))
        if case .failed = game.status { } else { preconditionFailure("詰まない王手は失敗になる") }
        precondition(game.mistakeCount == 3)
        game.reset()
        game.tap(hand: .gold)
        game.tap(square: Square.index(file: 3, rank: 2))
        if case .solved = game.status { } else { preconditionFailure("リセット後は同じ問題を解き直せる") }
        precondition(game.mistakeCount == 3, "正解はミス回数に加えない")
        precondition(game.position.isMate)
        print("Practice tests passed: normal-only history, persistence, identity, size filtering, scoring policy, retry")
    }
}
