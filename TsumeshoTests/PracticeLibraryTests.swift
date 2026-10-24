import Foundation
import Testing
@testable import Tsumesho

/// 修行用に残す、ノーマルでミスした問題。テストごとに専用の保存先を使う
@MainActor
struct PracticeLibraryTests {
    let store = UserDefaults(suiteName: "PracticeLibraryTests-\(UUID().uuidString)")!
    let problem = Problem.tutorial(.small)

    @Test func ノーマルのミスだけを残す() {
        let library = PracticeLibrary(store: store)
        library.recordMistake(problem, mode: .timeTrial)
        library.recordMistake(problem, mode: .tutorial)
        library.recordMistake(problem, mode: .zen)
        #expect(library.entries.isEmpty)
        library.recordMistake(problem, mode: .normal)
        #expect(library.entries.count == 1)
    }

    @Test func 同じ局面は番号が変わっても1つにまとめ_ミスの回数を数える() {
        let library = PracticeLibrary(store: store)
        library.recordMistake(problem, mode: .normal)
        var samePosition = problem
        samePosition.id = 99
        library.recordMistake(samePosition, mode: .normal)
        #expect(library.entries.count == 1)
        #expect(library.entries[0].mistakes == 2)
    }

    @Test func 盤のサイズごとに_ミスの多い順に出す() {
        let library = PracticeLibrary(store: store)
        let another = Problem(id: problem.id, size: .small, plies: 1,
                              board: "7k1/9/7P1/9/9/9/9/9/9", hand: "G", answer: "２二金打")
        library.recordMistake(another, mode: .normal)
        library.recordMistake(problem, mode: .normal)
        library.recordMistake(problem, mode: .normal)
        library.recordMistake(.tutorial(.full), mode: .normal)
        let small = library.problems(size: .small)
        #expect(small.map(\.board) == [problem.board, another.board])
        #expect(library.problems(size: .full).count == 1)
    }

    @Test func 次に起動したときも同じ盤面で解き直せる() throws {
        PracticeLibrary(store: store).recordMistake(problem, mode: .normal)
        let restored = try #require(PracticeLibrary(store: store).problems(size: .small).first)
        #expect(restored.board == problem.board)
        #expect(restored.hand == problem.hand)
        #expect(restored.plies == problem.plies)
        #expect(restored.position.board == problem.position.board)
    }
}
