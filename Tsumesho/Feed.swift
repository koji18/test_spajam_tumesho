import Foundation
import Observation

// 出題する問題の列。盤の大きさごとに別の列を持つ。
// 1 問目はチュートリアル用の例題で、2 問目からは裏で作った問題を足し続ける。
// 今見ている問題より先に数問を作り置きしておくので、スワイプしても待たされない。
@MainActor @Observable
final class ProblemFeed {
    private(set) var lists: [BoardSize: [Problem]] = [.small: [.tutorial(.small)], .full: [.tutorial(.full)]]

    private static let lookahead = 3
    private var wantedCount: [BoardSize: Int] = [:]
    private var generating: Set<BoardSize> = []
    private let worker = GeneratorWorker()

    func problems(_ size: BoardSize) -> [Problem] { lists[size] ?? [] }

    // size の列の index 番目の問題が表示されそうになったら呼ぶ
    func didShow(index: Int, size: BoardSize) {
        wantedCount[size] = max(wantedCount[size] ?? 0, index + 1 + Self.lookahead)
        fill(size)
    }

    private func fill(_ size: BoardSize) {
        let count = problems(size).count
        guard !generating.contains(size), count < wantedCount[size] ?? 0 else { return }
        generating.insert(size)
        // 作った問題の通し番号。最初の 3 問は 1 手詰めで慣れてもらい、そのあとは 1 手詰めと 3 手詰めを 1:2 で混ぜる。
        // 正解が持ち駒を打つ手の問題は 2 問に 1 問までにして、金打ばかりにならないようにする
        let n = count - 1
        let plies = n < 3 || n % 3 == 0 ? 1 : 3
        let allowDrop = n % 2 == 0
        Task {
            if var problem = await worker.make(size: size, plies: plies, allowDrop: allowDrop) {
                problem.id = problems(size).count + 1
                lists[size, default: []].append(problem)
            }
            generating.remove(size)
            fill(size)
        }
    }
}

// 問題づくりは時間がかかるので、メインスレッドの外で動かす
actor GeneratorWorker {
    private var generator = ProblemGenerator(seed: UInt64.random(in: 1...UInt64.max))

    func make(size: BoardSize, plies: Int, allowDrop: Bool) -> Problem? {
        let maxPieces = (size == .small ? 5 : 6) + (plies == 3 ? 1 : 0)
        return generator.next(size: size, plies: plies, maxPieces: maxPieces, allowDrop: allowDrop)
    }
}
