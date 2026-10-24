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
        var isFailed: Bool { if case .failed = self { return true } else { return false } }
        case playing
        case thinking                 // 玉方が応手を考えている
        case solved(tesuji: String?)
        case failed(answer: String)
    }

    let problem: Problem
    /// 表示範囲。3 手詰めでは途中で玉が動くので、最初の局面で一度だけ決める
    let windowFiles: ClosedRange<Int>
    private(set) var position: Position
    private(set) var pliesLeft: Int
    private(set) var status: Status = .playing
    private(set) var message: String
    private(set) var selection: Selection?
    private(set) var targets: Set<Int> = []
    private(set) var lastMove: Move?
    private(set) var hintLevel = 0
    /// この問題で使ったヒントの段階の最大。レーティングの上がり幅を減らすのに使う
    private(set) var hintsUsed = 0
    /// ヒントで光らせるマスと持ち駒。盤のマスごとに計算し直すと重いので、ヒントを押したときに一度だけ計算する
    private(set) var hintSources: Set<Int> = []
    private(set) var hintHandKinds: Set<Kind> = []
    private(set) var hintTargets: Set<Int> = []
    /// 間違えたときに盤で見せる正解の手。入門では、答えを見るボタンを押すまで見せない（answerOnDemand）
    private var answerMove: Move?
    private(set) var answerShown = false
    /// この問題で一度でも「答えを見る」を押したか。リセットしても残し、入門の星を 1 つにするのに使う
    private(set) var answerUsed = false
    var answerOnDemand = false
    var revealedAnswer: Move? { answerOnDemand && !answerShown ? nil : answerMove }
    /// 間違えたときに盤で見せる、玉方の防ぎ方（指す前の盤に重ねて、そのマスを光らせる）
    private(set) var refutation: Move?
    /// 間違えた回数（王手でない手を指そうとしたときも数える）。盤を揺らすきっかけに使う
    private(set) var mistakes = 0
    /// 王手になっていない手を指そうとして、その知らせを出しているところか。次に駒を選ぶか、指すか、リセットすると消える
    private(set) var notCheckNotice = false
    var pendingPromotion: (promote: Move, stay: Move)?

    private var firstMoveCaptured = false
    /// 3 手詰めの玉方の応手を待っている処理。盤面をリセットしたら取り消す
    private var replyTask: Task<Void, Never>?
    /// 解くのにかかった時間。ページが表示されたときから数える
    private var startedAt: Date?
    private(set) var solvedSeconds = 0

    /// 問題の最初の局面から遊び始める
    init(problem: Problem) {
        let start = problem.position
        self.problem = problem
        position = start
        windowFiles = start.windowFiles(span: problem.size.span)
        pliesLeft = problem.plies
        message = Self.prompt(for: problem)
    }

    /// 何をすればいいかの一文は 1 問目だけ出す。2 問目からは見出しの「〇手詰め」でわかる。
    /// 入門の問題は、説明を画面の上のカードに出すので、ここは空にしておく
    private static func prompt(for problem: Problem) -> String {
        isFirstNormalProblem(problem) ? "王手をかけて、玉を詰ませよう" : ""
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

    /// 今が何手目か（1 手詰めは 1/1、3 手詰めは 1/3 から 3/3）
    var currentPly: Int { problem.plies - pliesLeft + 1 }

    // MARK: 1 問目の案内

    /// 1 問目だけ、操作に合わせて次にやることを案内する
    var guide: String? {
        guard isGuiding else { return nil }
        switch selection {
        case nil: return "まずは下の持ち駒「金」をタップしてみよう"
        case .hand: return "光ったマスに打てます。玉が逃げられなくなる場所はどこ？"
        case .square: return "盤の駒も動かせますが、今回は持ち駒の金を使ってみよう"
        }
    }

    var guideHandKind: Kind? { isGuiding && selection == nil ? .gold : nil }

    private var isGuiding: Bool { Self.isFirstNormalProblem(problem) && status == .playing && lastMove == nil }

    /// ノーマルの 1 問目（頭金の例題）か。入門の問題も id が 1〜7 なので、番号だけでなく入門の問題でないことも確かめる。
    /// 上の一文・案内・金の点滅の枠は、この問題だけに出す
    static func isFirstNormalProblem(_ problem: Problem) -> Bool {
        problem.id == 1 && problem.lesson == nil
    }

    // MARK: ヒント

    /// 1 回目：王手をかけられる駒を光らせる。2 回目：正解の駒と行き先だけを光らせる
    /// ページが表示されたら呼ぶ。2 回目以降は何もしない
    func start() {
        if startedAt == nil { startedAt = Date() }
    }

    /// ヒントを 1 段進める。2 段まで
    func showHint() {
        guard status == .playing, hintLevel < 2 else { return }
        hintLevel += 1
        hintsUsed = max(hintsUsed, hintLevel)
        refreshHints()
    }

    /// ヒントの段階に合わせて、光らせるマスと持ち駒を計算し直す
    private func refreshHints() {
        switch hintLevel {
        case 1:
            let checks = position.checkMoves()
            hintSources = Set(checks.compactMap(\.from))
            hintHandKinds = Set(checks.filter { $0.from == nil }.map(\.kind))
            hintTargets = []
        case 2:
            let answers = position.mateMoves(plies: pliesLeft)
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

    /// 盤のマスをタップしたとき。光っているマスなら指し、自分の駒なら選び、それ以外なら選択を外す
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
        // 持ち駒の歩で、反則になるマスを押したとき。理由を出して盤を揺らし、歩は選んだままにする
        if selection == .hand(.pawn), let reason = illegalPawnDrop(at: square) {
            mistakes += 1
            message = reason
            return
        }
        if position.board[square]?.side == .black {
            select(selection == .square(square) ? nil : .square(square))
        } else {
            select(nil)
        }
    }

    /// 持ち駒の歩を square に打つと反則（二歩・打ち歩詰め）になるときの説明。反則でなければ nil
    private func illegalPawnDrop(at square: Int) -> String? {
        let drop = Move(from: nil, to: square, kind: .pawn)
        guard position.board[square] == nil else { return nil }
        let file = Square.file(square)
        let doublePawn = (1...9).contains { rank in
            let p = position.board[Square.index(file: file, rank: rank)]
            return p?.side == .black && p?.kind == .pawn && p?.promoted == false
        }
        if doublePawn {
            return "二歩は反則です（同じ筋に歩は2枚置けません）"
        }
        // 打ち歩詰め：反則の判定を外せば打てる手で、打つと詰みになる
        if position.legalMoves(checkPawnDropMate: false).contains(drop) && !position.legalMoves().contains(drop) {
            return "打ち歩詰めは反則です（歩を打って詰ませてはいけません）"
        }
        return nil
    }

    /// 持ち駒をタップしたとき。選ぶか、選んでいたら外す
    func tap(hand kind: Kind) {
        guard status == .playing else { return }
        select(selection == .hand(kind) ? nil : .hand(kind))
    }

    /// 成るか成らないかを選んだとき
    func choosePromotion(_ promote: Bool) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        attempt(promote ? pending.promote : pending.stay)
    }

    /// 答えを見る。王手でない手を指して失敗にならなかったときは、いまの局面から正解を求める
    func showAnswer() {
        if answerMove == nil { answerMove = position.mateMoves(plies: pliesLeft).first }
        answerShown = true
        answerUsed = true
    }

    /// 見せている正解の手の説明（「３二に金を打つ」など）
    var answerText: String? {
        guard answerShown, let m = answerMove else { return nil }
        return Notation.describe(m, in: position)
    }

    /// 王手になっていない手を指したあとの知らせが出ているか
    var isNotCheckNotice: Bool { status == .playing && notCheckNotice }

    /// 盤面を問題の最初に戻す
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
        answerMove = nil
        answerShown = false
        refutation = nil
        replyTask?.cancel()
        replyTask = nil
        firstMoveCaptured = false
        notCheckNotice = false
        startedAt = Date()
    }

    /// 駒か持ち駒を選び、動けるマスを計算し直す
    private func select(_ s: Selection?) {
        // 王手でなかったときの知らせは、次に駒を選んだら消す
        if notCheckNotice {
            notCheckNotice = false
            message = Self.prompt(for: problem)
        }
        selection = s
        targets = Set(candidateMoves().map(\.to))
    }

    /// 選んでいる駒か持ち駒で指せる合法手
    private func candidateMoves() -> [Move] {
        guard let selection else { return [] }
        return position.legalMoves().filter { m in
            switch selection {
            case .square(let i): return m.from == i
            case .hand(let k): return m.from == nil && m.kind == k
            }
        }
    }

    /// 指した手を判定する。王手でない手は詰将棋では指せないので、盤を戻して知らせる
    private func attempt(_ m: Move) {
        select(nil)
        guard position.givesCheck(m) else {
            mistakes += 1
            notCheckNotice = true
            message = "王手になっていません。詰将棋は毎回王手をかけます"
            return
        }
        let before = position
        let answers = before.mateMoves(plies: pliesLeft)
        hintLevel = 0
        refreshHints()

        // 間違えたら指す前の盤に戻し、正解の駒と行き先を盤で見せる
        guard answers.contains(m) else {
            mistakes += 1
            answerMove = answers.first
            answerShown = false
            let answer = answers.first.map { Notation.describe($0, in: before) } ?? ""
            status = .failed(answer: answer)
            // 玉方がどう防ぐかを見せる
            if let reply = before.refutation(of: m, plies: pliesLeft - 2) {
                refutation = reply
                message = "残念、" + Notation.explainDefense(reply, after: before.playing(m), check: m)
            } else {
                message = "残念、その手だと詰みません"
            }
            return
        }
        position = before.playing(m)
        lastMove = m
        // 正しい手を指したので、見せていた正解は片づける（3 手詰めの次の手で古い答えが残らないように）
        answerMove = nil
        answerShown = false
        if position.isMate {
            let tesuji = firstMoveCaptured ? "捨て駒" : Notation.tesuji(m, in: before, captured: false)
            solvedSeconds = Int(Date().timeIntervalSince(startedAt ?? Date()))
            status = .solved(tesuji: tesuji)
            message = "詰み！"
            return
        }
        // 3 手詰めの途中。玉方がいちばん粘る手で応じる
        pliesLeft -= 2
        status = .thinking
        message = "玉方が考えています…"
        replyTask = Task {
            // 待っているあいだに盤面をリセットされたら、応手を指さない
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            guard !Task.isCancelled, status == .thinking,
                  let reply = position.bestDefense(plies: pliesLeft) else { return }
            let replyLabel = Notation.label(reply, in: position)
            firstMoveCaptured = reply.to == m.to
            position = position.playing(reply)
            lastMove = reply
            status = .playing
            message = "玉方は\(replyLabel)。あと1手で詰ませよう"
        }
    }
}
