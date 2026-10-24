import CoreHaptics
import Foundation
import Observation
import UIKit

enum PlayMode: String {
    case normal
    case timeTrial

    var title: String { self == .normal ? "NORMAL" : "TIME TRIAL" }
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
    }

    // 正解なら 1 手詰めで +12、3 手詰めで +20。ヒントを 1 段使うごとに 5 減らす（最低 +2）。
    // 間違えたら -10。0 より下にはしない
    func record(solved: Bool, plies: Int, hintsUsed: Int) {
        if solved {
            streak += 1
            solvedTotal += 1
            bestStreak = max(bestStreak, streak)
            rating += max(2, (plies == 1 ? 12 : 20) - hintsUsed * 5)
        } else {
            streak = 0
            rating = max(0, rating - 10)
        }
    }

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
