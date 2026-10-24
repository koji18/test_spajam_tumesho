import AVFAudio
import CoreHaptics
import UIKit

// 音と触覚を同じ Core Haptics パターンで再生する。
// 非対応の機器と Simulator では AVAudioPlayer と標準の触覚へ切り替える。
@MainActor
enum NativeFeedback {
    enum Cue: Hashable {
        case landing, mate(Int), rankUp, score

        var name: String {
            switch self {
            case .landing: "piece-land"
            case .mate(let streak): "mate-\(Self.tier(streak))"
            case .rankUp: "rank-up"
            case .score: "score-arrive"
            }
        }

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
    private static var resources: [String: CHHapticAudioResourceID] = [:]
    private static var audioPlayers: [String: AVAudioPlayer] = [:]

    static func prepare() {
        // マナーモードを尊重し、ほかのアプリの音楽を止めない。
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        for name in ["piece-land", "mate-1", "mate-2", "mate-3", "mate-4", "rank-up", "score-arrive"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = 0.6
            player.prepareToPlay()
            audioPlayers[name] = player
        }
    }

    static func play(_ cue: Cue, sound: Bool, haptics: Bool) {
        guard sound || haptics, UIApplication.shared.applicationState == .active else { return }
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        if capabilities.supportsHaptics, (!sound || capabilities.supportsAudio),
           playPattern(cue, sound: sound, haptics: haptics) { return }

        if sound {
            let player = audioPlayers[cue.name]
            player?.currentTime = 0
            player?.play()
        }
        if haptics {
            switch cue {
            case .landing: UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
            case .score: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
            default: UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
            }
        }
    }

    static func stop() {
        engine?.stop(completionHandler: nil)
        audioPlayers.values.forEach { $0.stop() }
    }

    private static func playPattern(_ cue: Cue, sound: Bool, haptics: Bool) -> Bool {
        do {
            if engine == nil {
                let newEngine = try CHHapticEngine(audioSession: .sharedInstance())
                newEngine.isAutoShutdownEnabled = true
                newEngine.playsHapticsOnly = false
                newEngine.resetHandler = {
                    Task { @MainActor in
                        engine = nil
                        resources.removeAll()
                    }
                }
                engine = newEngine
            }
            guard let engine else { return false }
            try engine.start()
            var events: [CHHapticEvent] = []
            if haptics {
                events = cue.impacts.map { impact in
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
            }
            if sound {
                guard let url = Bundle.main.url(forResource: cue.name, withExtension: "wav") else { return false }
                let resource: CHHapticAudioResourceID
                if let cached = resources[cue.name] {
                    resource = cached
                } else {
                    resource = try engine.registerAudioResource(url, options: [:])
                    resources[cue.name] = resource
                }
                events.append(CHHapticEvent(audioResourceID: resource, parameters: [
                    CHHapticEventParameter(parameterID: .audioVolume, value: 0.6),
                ], relativeTime: 0))
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            engine = nil
            resources.removeAll()
            return false
        }
    }
}
