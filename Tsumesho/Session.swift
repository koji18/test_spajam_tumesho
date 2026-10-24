import Foundation
import Observation

enum PlayMode: String {
    case normal
    case timeTrial

    var title: String { self == .normal ? "NORMAL" : "TIME TRIAL" }
}

// 1 問を解いて得たスコアとその内訳
struct ScoreGain {
    let points: Int
    let speedBonus: Int
    let sizeMultiplier: Double
    let streakMultiplier: Double

    // 基本点（1 手詰め 100・3 手詰め 300）に盤のサイズの倍率をかけ、スピードボーナスを足す。
    // ヒント 1 段ごとに 25% 減らし（最低 25%）、最後に連勝の倍率をかける
    static func make(plies: Int, size: BoardSize, seconds: Int, hintsUsed: Int, streak: Int) -> ScoreGain {
        let base = Double(plies == 1 ? 100 : 300)
        let sizeMultiplier = switch size {
        case .small: 1.0
        case .medium: 1.2
        case .full: 1.5
        }
        // 1 手詰めは 15 秒、3 手詰めは 40 秒より速いほど増える。最大で基本点の半分
        let par = plies == 1 ? 15.0 : 40.0
        let speedBonus = Int(base * 0.5 * max(0, 1 - Double(seconds) / par))
        let hintFactor = max(0.25, 1 - 0.25 * Double(hintsUsed))
        let streakMultiplier = streakMultiplier(for: streak)
        let points = Int(((base * sizeMultiplier + Double(speedBonus)) * hintFactor * streakMultiplier).rounded())
        return ScoreGain(points: points, speedBonus: speedBonus, sizeMultiplier: sizeMultiplier, streakMultiplier: streakMultiplier)
    }

    // 連勝の倍率。2 連勝目から 0.1 ずつ上がり、最大 3 倍
    static func streakMultiplier(for streak: Int) -> Double {
        min(3, 1 + 0.1 * Double(max(0, streak - 1)))
    }

    static func format(_ multiplier: Double) -> String {
        String(format: "x%.1f", multiplier)
    }
}

// 一度の正解の内訳を固定し、次の問題へ移っても同じ報酬を演出する。
struct SolveReward: Identifiable {
    let id = UUID()
    let gain: ScoreGain
    let streak: Int
    let previousRank: String
    let rank: String

    var rankedUp: Bool { previousRank != rank }
    var isMilestone: Bool { streak > 0 && streak.isMultiple(of: 5) }
}

// 遊び方の設定と成績。問題のページをまたいで共有し、次に起動したときも残す
@MainActor @Observable
final class Session {
    private let store = UserDefaults.standard

    var mode: PlayMode { didSet { store.set(mode.rawValue, forKey: "mode") } }
    var boardSize: BoardSize { didSet { store.set(boardSize.rawValue, forKey: "boardSize") } }
    var hapticsOn: Bool { didSet { store.set(hapticsOn, forKey: "hapticsOn") } }
    var soundOn: Bool { didSet { store.set(soundOn, forKey: "soundOn") } }
    // 初回のチュートリアルを詰ませたか。詰ませるまでは普通の見た目で出し、詰ませたらネオンの見た目に切り替える
    var tutorialCleared: Bool { didSet { store.set(tutorialCleared, forKey: "tutorialCleared") } }

    var palette: Palette { tutorialCleared ? .neon : .classic }

    private(set) var rating: Int { didSet { store.set(rating, forKey: "rating") } }
    private(set) var streak: Int { didSet { store.set(streak, forKey: "streak") } }
    private(set) var bestStreak: Int { didSet { store.set(bestStreak, forKey: "bestStreak") } }
    private(set) var solvedTotal: Int { didSet { store.set(solvedTotal, forKey: "solvedTotal") } }
    private(set) var timeTrialBest: Int { didSet { store.set(timeTrialBest, forKey: "timeTrialBest") } }
    private(set) var totalScore: Int { didSet { store.set(totalScore, forKey: "totalScore") } }
    // カードに出しているスコア。解いた直後は前の値のままにしておき、演出が消えてから数え上げる
    private(set) var displayedScore: Int
    // 数え上げている間だけ、カードの横に「+735」と出す
    private(set) var scorePopup: Int?
    private var scoreRevealID = UUID()

    init() {
        mode = PlayMode(rawValue: store.string(forKey: "mode") ?? "") ?? .normal
        boardSize = BoardSize(rawValue: store.string(forKey: "boardSize") ?? "") ?? .full
        hapticsOn = store.object(forKey: "hapticsOn") as? Bool ?? true
        soundOn = store.object(forKey: "soundOn") as? Bool ?? true
        tutorialCleared = store.bool(forKey: "tutorialCleared")
        rating = store.object(forKey: "rating") as? Int ?? 1500
        streak = store.integer(forKey: "streak")
        bestStreak = store.integer(forKey: "bestStreak")
        solvedTotal = store.integer(forKey: "solvedTotal")
        timeTrialBest = store.integer(forKey: "timeTrialBest")
        let score = store.integer(forKey: "totalScore")
        totalScore = score
        displayedScore = score
    }

    // 正解：レーティングは 1 手詰めで +12、3 手詰めで +20。ヒントを 1 段使うごとに 5 減らす（最低 +2）。
    //       スコアは ScoreGain の計算で累計に足し、得た点を返す。
    // 間違い：レーティングは -10（0 より下にはしない）。連勝は 0 に戻る
    @discardableResult
    func recordSolve(plies: Int, size: BoardSize, seconds: Int, hintsUsed: Int) -> ScoreGain {
        streak += 1
        solvedTotal += 1
        bestStreak = max(bestStreak, streak)
        rating += max(2, (plies == 1 ? 12 : 20) - hintsUsed * 5)
        let gain = ScoreGain.make(plies: plies, size: size, seconds: seconds, hintsUsed: hintsUsed, streak: streak)
        totalScore += gain.points
        return gain
    }

    // カードのスコアを、今の表示から累計まで約 0.8 秒で数え上げる
    func revealScore() async {
        let revealID = UUID()
        scoreRevealID = revealID
        let from = displayedScore
        let to = totalScore
        guard to > from else { return }
        scorePopup = to - from
        let steps = 24
        for i in 1...steps {
            guard !Task.isCancelled, scoreRevealID == revealID else { return }
            displayedScore = from + (to - from) * i / steps
            do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
        }
        displayedScore = to
        do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
        guard scoreRevealID == revealID else { return }
        scorePopup = nil
    }

    func settleScore() {
        scoreRevealID = UUID()
        displayedScore = totalScore
        scorePopup = nil
    }

    func recordMiss() {
        streak = 0
        rating = max(0, rating - 10)
    }

    // 次に解いたときにかかる連勝の倍率
    var nextStreakMultiplier: Double { ScoreGain.streakMultiplier(for: streak + 1) }

    func recordTimeTrial(solved: Int) {
        timeTrialBest = max(timeTrialBest, solved)
    }

    // レーティングに応じた段位のバッジ
    var rankBadge: String {
        switch rating {
        case ..<1400: "級"
        case ..<1600: "初"
        case ..<1800: "二"
        case ..<2000: "三"
        case ..<2200: "四"
        default: "五"
        }
    }

    var rankName: String { rankBadge == "級" ? "級位" : "\(rankBadge)段" }
}

// タイムトライアル。持ち時間 60 秒から始め、正解すると時間が増え、間違えると減る。何問解けるかを競う
@MainActor @Observable
final class TimeTrial {
    static let startTime: TimeInterval = 60
    static let missPenalty = 5

    // タイマーの横に浮かべる「+12s」「-5s」
    struct Popup: Equatable {
        let id = UUID()
        let seconds: Int
    }

    private(set) var startedAt: Date?
    private(set) var deadline: Date?
    private(set) var solved = 0
    private(set) var finished = false
    private(set) var popup: Popup?
    // 正解で増えた秒数。詰み演出が消えてからタイマーの横に出す
    private var pendingBonus: Int?

    func begin() {
        let now = Date()
        startedAt = now
        deadline = now.addingTimeInterval(Self.startTime)
        solved = 0
        finished = false
        popup = nil
        pendingBonus = nil
    }

    func stop() {
        startedAt = nil
        deadline = nil
        finished = false
        popup = nil
        pendingBonus = nil
    }

    var isRunning: Bool { deadline != nil && !finished }

    func remaining(at now: Date = Date()) -> TimeInterval {
        guard let deadline else { return Self.startTime }
        return max(0, deadline.timeIntervalSince(now))
    }

    // 正解：1 手詰めは +5 秒、3 手詰めは +12 秒。ヒントを使った問題は半分
    func recordSolve(plies: Int, hintsUsed: Int) {
        guard isRunning, let deadline else { return }
        solved += 1
        var bonus = plies == 1 ? 5 : 12
        if hintsUsed > 0 { bonus /= 2 }
        self.deadline = deadline.addingTimeInterval(TimeInterval(bonus))
        pendingBonus = bonus
    }

    // 間違い：-5 秒。すぐタイマーの横に出す
    func recordMiss() {
        guard isRunning, let deadline else { return }
        self.deadline = deadline.addingTimeInterval(-TimeInterval(Self.missPenalty))
        Task { await show(-Self.missPenalty) }
    }

    // 詰み演出が消えたら、正解で増えた秒数を出す
    func revealBonus() async {
        guard let bonus = pendingBonus else { return }
        pendingBonus = nil
        await show(bonus)
    }

    private func show(_ seconds: Int) async {
        let p = Popup(seconds: seconds)
        popup = p
        try? await Task.sleep(for: .milliseconds(1400))
        if popup == p { popup = nil }
    }

    func finish() {
        finished = true
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
