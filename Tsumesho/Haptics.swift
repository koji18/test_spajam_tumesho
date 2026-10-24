import CoreHaptics
import UIKit

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
