import Foundation
import Observation

// 1 問ぶんの遊びの状態。9×9 より小さい盤で遊ぶときは、攻め方の手も表示範囲の中に限る。
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

    let problem: Problem
    // 表示範囲。3 手詰めでは途中で玉が動くので、最初の局面で一度だけ決める
    let windowFiles: ClosedRange<Int>
    private(set) var position: Position
    private(set) var pliesLeft: Int
    private(set) var status: Status = .playing
    private(set) var message: String
    private(set) var selection: Selection?
    private(set) var targets: Set<Int> = []
    private(set) var lastMove: Move?
    private(set) var hintLevel = 0
    // ヒントで光らせるマスと持ち駒。盤のマスごとに計算し直すと重いので、ヒントを押したときに一度だけ計算する
    private(set) var hintSources: Set<Int> = []
    private(set) var hintHandKinds: Set<Kind> = []
    private(set) var hintTargets: Set<Int> = []
    // 間違えたときに盤で見せる正解の手
    private(set) var revealedAnswer: Move?
    var pendingPromotion: (promote: Move, stay: Move)?

    private var firstMoveCaptured = false
    // 解くのにかかった時間。ページが表示されたときから数える
    private var startedAt: Date?
    private(set) var solvedSeconds = 0

    init(problem: Problem) {
        let start = problem.position
        self.problem = problem
        position = start
        windowFiles = start.windowFiles(span: problem.size.span)
        pliesLeft = problem.plies
        message = Self.prompt(for: problem)
    }

    // 何をすればいいかの一文は 1 問目だけ出す。2 問目からは見出しの「〇手詰め」でわかる
    private static func prompt(for problem: Problem) -> String {
        problem.id == 1 ? "王手をかけて、玉を詰ませよう" : ""
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

    // MARK: 盤の大きさ

    var visibleFiles: ClosedRange<Int> { windowFiles }
    var visibleRanks: ClosedRange<Int> { Position.windowRanks(span: problem.size.span) }

    // 今が何手目か（1 手詰めは 1/1、3 手詰めは 1/3 から 3/3）
    var currentPly: Int { problem.plies - pliesLeft + 1 }

    // 攻め方が指せる手を、見えているマスへの手に限る
    private var filter: ((Move) -> Bool)? {
        guard problem.size.span < 9 else { return nil }
        let files = windowFiles
        let ranks = visibleRanks
        return { files.contains(Square.file($0.to)) && ranks.contains(Square.rank($0.to)) }
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

    // 1 回目：王手をかけられる駒を光らせる。2 回目：正解の駒と行き先だけを光らせる
    func showHint() {
        guard status == .playing, hintLevel < 2 else { return }
        hintLevel += 1
        refreshHints()
    }

    private func refreshHints() {
        switch hintLevel {
        case 1:
            let checks = position.checkMoves(where: filter)
            hintSources = Set(checks.compactMap(\.from))
            hintHandKinds = Set(checks.filter { $0.from == nil }.map(\.kind))
            hintTargets = []
        case 2:
            let answers = position.mateMoves(plies: pliesLeft, where: filter)
            hintSources = Set(answers.compactMap(\.from))
            hintHandKinds = Set(answers.filter { $0.from == nil }.map(\.kind))
            hintTargets = Set(answers.map(\.to))
        default:
            hintSources = []
            hintHandKinds = []
            hintTargets = []
        }
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
        refreshHints()
        revealedAnswer = nil
        firstMoveCaptured = false
    }

    private func select(_ s: Selection?) {
        selection = s
        targets = Set(candidateMoves().map(\.to))
    }

    private func candidateMoves() -> [Move] {
        guard let selection else { return [] }
        return position.legalMoves().filter { m in
            guard filter?(m) ?? true else { return false }
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
        let answers = before.mateMoves(plies: pliesLeft, where: filter)
        hintLevel = 0
        refreshHints()

        // 間違えたら指す前の盤に戻し、正解の駒と行き先を盤で見せる
        guard answers.contains(m) else {
            revealedAnswer = answers.first
            let answer = answers.first.map { Notation.describe($0, in: before) } ?? ""
            status = .failed(answer: answer)
            message = "残念、その手だと玉に逃げられます"
            return
        }
        position = before.playing(m)
        lastMove = m
        if position.isMate {
            let tesuji = firstMoveCaptured ? "捨て駒" : Notation.tesuji(m, in: before, captured: false)
            status = .solved(tesuji: tesuji)
            message = "詰み！"
            return
        }
        // 3 手詰めの途中。玉方がいちばん粘る手で応じる
        pliesLeft -= 2
        status = .thinking
        message = "玉方が考えています…"
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard let reply = position.bestDefense(plies: pliesLeft, where: filter) else { return }
            let replyLabel = Notation.label(reply, in: position)
            firstMoveCaptured = reply.to == m.to
            position = position.playing(reply)
            lastMove = reply
            status = .playing
            message = "玉方は\(replyLabel)。あと1手で詰ませよう"
        }
    }
}

// 連続正解数と盤の大きさの設定。問題のページをまたいで共有する
@MainActor @Observable
final class Session {
    // 盤の大きさ（true で 5×5）。次に起動したときも同じ大きさで始める
    var smallBoard = UserDefaults.standard.bool(forKey: "smallBoard") {
        didSet { UserDefaults.standard.set(smallBoard, forKey: "smallBoard") }
    }
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
