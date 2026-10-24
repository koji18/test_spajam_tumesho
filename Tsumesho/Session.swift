import CoreHaptics
import Foundation
import Observation
import UIKit

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

// 遊び方の設定と成績。問題のページをまたいで共有し、次に起動したときも残す
@MainActor @Observable
final class Session {
    private let store = UserDefaults.standard

    var mode: PlayMode { didSet { store.set(mode.rawValue, forKey: "mode") } }
    var boardSize: BoardSize { didSet { store.set(boardSize.rawValue, forKey: "boardSize") } }
    var hapticsOn: Bool { didSet { store.set(hapticsOn, forKey: "hapticsOn") } }
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

    init() {
        mode = PlayMode(rawValue: store.string(forKey: "mode") ?? "") ?? .normal
        boardSize = BoardSize(rawValue: store.string(forKey: "boardSize") ?? "") ?? .full
        hapticsOn = store.object(forKey: "hapticsOn") as? Bool ?? true
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
        let from = displayedScore
        let to = totalScore
        guard to > from else { return }
        scorePopup = to - from
        let steps = 24
        for i in 1...steps {
            displayedScore = from + (to - from) * i / steps
            try? await Task.sleep(for: .milliseconds(33))
        }
        displayedScore = totalScore
        try? await Task.sleep(for: .milliseconds(600))
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

// タイムトライアル。持ち時間 3 分で何問解けるかを競う
@MainActor @Observable
final class TimeTrial {
    static let duration: TimeInterval = 180

    private(set) var startedAt: Date?
    private(set) var solved = 0
    private(set) var finished = false

    func begin() {
        startedAt = Date()
        solved = 0
        finished = false
    }

    func stop() {
        startedAt = nil
        finished = false
    }

    var isRunning: Bool { startedAt != nil && !finished }

    func remaining(at now: Date = Date()) -> TimeInterval {
        guard let startedAt else { return Self.duration }
        return max(0, Self.duration - now.timeIntervalSince(startedAt))
    }

    func recordSolve() {
        if isRunning { solved += 1 }
    }

    func finish() {
        finished = true
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// 振動。設定でオフにできる
@MainActor
enum Haptics {
    private static var engine: CHHapticEngine?

    // 詰んだ瞬間：いちばん強い振動を約 0.6 秒続け、その上に強い「ドン」を 4 回重ねる。
    // Core Haptics が使えない機種では、標準の振動を続けて鳴らす
    static func mate(enabled: Bool) {
        guard enabled else { return }
        if playMatePattern() { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
            try? await Task.sleep(for: .milliseconds(160))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private static func playMatePattern() -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
        do {
            if engine == nil {
                let e = try CHHapticEngine()
                e.isAutoShutdownEnabled = true
                e.resetHandler = { Task { @MainActor in engine = nil } }
                engine = e
            }
            guard let engine else { return false }
            try engine.start()
            let strong = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1),
            ]
            var events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                ], relativeTime: 0, duration: 0.6),
            ]
            for time in [0, 0.12, 0.28, 0.45] {
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: strong, relativeTime: time))
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }
}
