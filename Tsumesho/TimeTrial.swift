import Foundation
import Observation

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
