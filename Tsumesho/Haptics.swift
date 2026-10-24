import CoreHaptics
import UIKit

/// 振動。効果音とは独立させ、設定で無効化できる。
@MainActor
enum Haptics {
    enum Cue: Hashable {
        case landing, mate(Int), rankUp, score

        static func tier(_ streak: Int) -> Int {
            streak >= 10 ? 4 : (streak >= 5 ? 3 : (streak >= 3 ? 2 : 1))
        }

        var impacts: [(time: Double, intensity: Float, sharpness: Float)] {
            switch self {
            case .landing: [(0, 1, 1)]
            case .mate(let streak):
                switch Self.tier(streak) {
                case 4: [(0, 1, 1), (0.08, 1, 1), (0.16, 1, 1), (0.27, 1, 1),
                         (0.43, 1, 1), (0.59, 1, 1), (0.75, 1, 1), (0.91, 1, 1), (1.07, 1, 1)]
                case 3: [(0, 1, 1), (0.16, 1, 1), (0.27, 1, 1), (0.43, 1, 1),
                         (0.59, 1, 1), (0.75, 1, 1), (0.91, 1, 1)]
                case 2: [(0, 1, 1), (0.08, 1, 1), (0.16, 1, 1), (0.32, 1, 1),
                         (0.48, 1, 1), (0.64, 1, 1), (0.8, 1, 1)]
                default: [(0, 1, 1), (0.16, 1, 1), (0.3, 1, 1), (0.46, 1, 1), (0.62, 1, 1)]
                }
            case .rankUp: [(0, 1, 1), (0.1, 1, 1), (0.2, 1, 1), (0.34, 1, 1),
                           (0.5, 1, 1), (0.66, 1, 1), (0.82, 1, 1)]
            case .score: [(0, 0.8, 1)]
            }
        }

        // 最大強度の持続振動に衝撃を重ねる。連勝が増えると長さと衝撃の数を増やす。
        var sustainDuration: TimeInterval? {
            switch self {
            case .mate(let streak): 0.7 + Double(Self.tier(streak) - 1) * 0.15
            case .rankUp: 0.9
            case .landing: 0.08
            case .score: nil
            }
        }
    }

    private static var engine: CHHapticEngine?
    private static var fallbackTask: Task<Void, Never>?

    /// 連勝数に応じた強い振動を鳴らす。
    static func mate(enabled: Bool) {
        play(.mate(1), enabled: enabled)
    }

    /// 駒の着地・正解・昇段・スコア獲得の振動を鳴らす。
    static func play(_ cue: Cue, enabled: Bool) {
        guard enabled, UIApplication.shared.applicationState == .active else { return }
        fallbackTask?.cancel()
        if playPattern(cue) { return }

        // Core Haptics を使えない場合も、同じ間隔で標準の衝撃を鳴らす。
        fallbackTask = Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            var previousTime = 0.0
            for impact in cue.impacts {
                do {
                    try await Task.sleep(for: .seconds(impact.time - previousTime))
                    try Task.checkCancellation()
                } catch { return }
                guard UIApplication.shared.applicationState == .active else { return }
                generator.impactOccurred(intensity: CGFloat(impact.intensity))
                previousTime = impact.time
            }
        }
    }

    /// 画面を離れたときと、バックグラウンドへ移ったときに止める。
    static func stop() {
        fallbackTask?.cancel()
        fallbackTask = nil
        engine?.stop(completionHandler: nil)
    }

    private static func playPattern(_ cue: Cue) -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
        do {
            if engine == nil {
                let newEngine = try CHHapticEngine()
                newEngine.isAutoShutdownEnabled = true
                newEngine.playsHapticsOnly = true
                newEngine.resetHandler = {
                    Task { @MainActor in engine = nil }
                }
                engine = newEngine
            }
            guard let engine else { return false }
            try engine.start()
            var events = cue.impacts.map { impact in
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: impact.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: impact.sharpness),
                ], relativeTime: impact.time)
            }
            if let duration = cue.sustainDuration {
                events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                ], relativeTime: 0, duration: duration))
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            engine = nil
            return false
        }
    }
}
