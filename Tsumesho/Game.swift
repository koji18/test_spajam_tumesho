import Foundation
import Observation

// 1 問ぶんの遊びの状態。盤の表示は 1〜5 筋 × 一〜五段だけなので、攻め方の手もその中に限る。
@MainActor @Observable
final class Game {
    enum Selection: Equatable {
        case square(Int)
        case hand(Kind)
    }

    enum Status: Equatable {
        case playing
        case thinking                 // 玉方が応手を考えている
        case solved(tesuji: String?)
        case failed(answer: String)
    }

    nonisolated static let files = 1...5
    nonisolated static let ranks = 1...5
    nonisolated static func isInView(_ m: Move) -> Bool {
        files.contains(Square.file(m.to)) && ranks.contains(Square.rank(m.to))
    }

    let problem: Problem
    private(set) var position: Position
    private(set) var pliesLeft: Int
    private(set) var status: Status = .playing
    private(set) var message: String
    private(set) var selection: Selection?
    private(set) var targets: Set<Int> = []
    private(set) var lastMove: Move?
    private(set) var hintLevel = 0
    var pendingPromotion: (promote: Move, stay: Move)?

    private var firstMoveCaptured = false

    init(problem: Problem) {
        self.problem = problem
        position = problem.position
        pliesLeft = problem.plies
        message = Self.prompt(for: problem)
    }

    private static func prompt(for problem: Problem) -> String {
        problem.plies == 1 ? "王手をかけて、玉を詰ませよう" : "王手を2回かけて、玉を詰ませよう"
    }

    struct HandItem: Identifiable {
        let kind: Kind
        let count: Int
        var id: Kind { kind }
    }

    var hand: [HandItem] {
        Kind.handKinds.compactMap { k in
            let n = position.hands[.black]![k.rawValue]
            return n > 0 ? HandItem(kind: k, count: n) : nil
        }
    }

    // MARK: 1 問目の案内

    // 1 問目だけ、操作に合わせて次にやることを案内する
    var guide: String? {
        guard isGuiding else { return nil }
        switch selection {
        case nil: return "まずは下の持ち駒「金」をタップしてみよう"
        case .hand: return "光ったマスに打てます。玉が逃げられなくなる場所はどこ？"
        case .square: return "盤の駒も動かせますが、今回は持ち駒の金を使ってみよう"
        }
    }

    var guideHandKind: Kind? { isGuiding && selection == nil ? .gold : nil }

    private var isGuiding: Bool { problem.id == 1 && status == .playing && lastMove == nil }

    // MARK: ヒント

    // 1 回目：王手をかけられる駒を光らせる。2 回目：正解の行き先を光らせる
    var hintSources: Set<Int> {
        guard hintLevel >= 1 else { return [] }
        return Set(position.checkMoves(where: Self.isInView).compactMap(\.from))
    }

    var hintHandKinds: Set<Kind> {
        guard hintLevel >= 1 else { return [] }
        return Set(position.checkMoves(where: Self.isInView).filter { $0.from == nil }.map(\.kind))
    }

    var hintTargets: Set<Int> {
        guard hintLevel >= 2 else { return [] }
        return Set(position.mateMoves(plies: pliesLeft, where: Self.isInView).map(\.to))
    }

    func showHint() {
        guard status == .playing else { return }
        hintLevel = min(hintLevel + 1, 2)
    }

    // MARK: 操作

    func tap(square: Int) {
        guard status == .playing else { return }
        if selection != nil, targets.contains(square) {
            let moves = candidateMoves().filter { $0.to == square }
            if moves.count == 2, let promote = moves.first(where: \.promote), let stay = moves.first(where: { !$0.promote }) {
                pendingPromotion = (promote, stay)
            } else if let m = moves.first {
                attempt(m)
            }
            return
        }
        if position.board[square]?.side == .black {
            select(selection == .square(square) ? nil : .square(square))
        } else {
            select(nil)
        }
    }

    func tap(hand kind: Kind) {
        guard status == .playing else { return }
        select(selection == .hand(kind) ? nil : .hand(kind))
    }

    func choosePromotion(_ promote: Bool) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        attempt(promote ? pending.promote : pending.stay)
    }

    func reset() {
        position = problem.position
        pliesLeft = problem.plies
        status = .playing
        message = Self.prompt(for: problem)
        selection = nil
        targets = []
        lastMove = nil
        hintLevel = 0
        firstMoveCaptured = false
    }

    private func select(_ s: Selection?) {
        selection = s
        targets = Set(candidateMoves().map(\.to))
    }

    private func candidateMoves() -> [Move] {
        guard let selection else { return [] }
        return position.legalMoves().filter { m in
            guard Self.isInView(m) else { return false }
            switch selection {
            case .square(let i): return m.from == i
            case .hand(let k): return m.from == nil && m.kind == k
            }
        }
    }

    // 指した手を判定する。王手でない手は詰将棋では指せないので、盤を戻して知らせる
    private func attempt(_ m: Move) {
        select(nil)
        guard position.givesCheck(m) else {
            message = "王手になっていません。詰将棋は毎回王手をかけます"
            return
        }
        let before = position
        let answers = before.mateMoves(plies: pliesLeft, where: Self.isInView)
        position = before.playing(m)
        lastMove = m

        guard answers.contains(m) else {
            let answer = answers.first.map { Notation.label($0, in: before) } ?? ""
            status = .failed(answer: answer)
            message = "残念、玉に逃げられます"
            return
        }
        if position.isMate {
            let tesuji = firstMoveCaptured ? "捨て駒" : Notation.tesuji(m, in: before, captured: false)
            status = .solved(tesuji: tesuji)
            message = "詰み！"
            return
        }
        // 3 手詰めの途中。玉方がいちばん粘る手で応じる
        pliesLeft -= 2
        hintLevel = 0
        status = .thinking
        message = "玉方が考えています…"
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard let reply = position.bestDefense(plies: pliesLeft, where: Self.isInView) else { return }
            let replyLabel = Notation.label(reply, in: position)
            firstMoveCaptured = reply.to == m.to
            position = position.playing(reply)
            lastMove = reply
            status = .playing
            message = "玉方は\(replyLabel)。あと1手で詰ませよう"
        }
    }
}

// 連続正解数。問題のページをまたいで共有する
@MainActor @Observable
final class Session {
    private(set) var streak = 0
    private(set) var best = 0
    private(set) var solvedCount = 0

    func record(solved: Bool) {
        if solved {
            streak += 1
            solvedCount += 1
            best = max(best, streak)
        } else {
            streak = 0
        }
    }
}
