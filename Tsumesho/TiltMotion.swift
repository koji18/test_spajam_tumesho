import CoreMotion
import Foundation
import Observation

// アプリ全体で一つのセンサーを共有する。最初の持ち方を基準にし、
// 微細な手ぶれは平滑化して、見た目に使う値を -1...1 に収める。
@MainActor @Observable
final class TiltMotion {
    private(set) var horizontal = 0.0
    private(set) var vertical = 0.0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?
    @ObservationIgnored private var activeRun: UUID?

    // 呼び出し元の SwiftUI task のキャンセルに合わせてセンサーも止める。
    func run() async {
        guard manager.isDeviceMotionAvailable, !Task.isCancelled else { return }
        let runID = UUID()
        activeRun = runID
        reference = nil
        horizontal = 0
        vertical = 0
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        defer {
            // 古い task の終了で、新しく再開したセンサーを止めない。
            if activeRun == runID {
                manager.stopDeviceMotionUpdates()
                activeRun = nil
                reference = nil
                horizontal = 0
                vertical = 0
            }
        }

        while !Task.isCancelled && activeRun == runID {
            sample()
            do { try await Task.sleep(for: .milliseconds(33)) } catch { break }
        }
    }

    private func sample() {
        guard let attitude = manager.deviceMotion?.attitude.copy() as? CMAttitude else { return }
        guard let reference else {
            self.reference = attitude
            return
        }
        attitude.multiply(byInverseOf: reference)
        // 基準から約20度傾けたところで最大。大きく振っても動きすぎない。
        let x = max(-1, min(1, attitude.roll / 0.35))
        let y = max(-1, min(1, attitude.pitch / 0.35))
        guard x.isFinite, y.isFinite else { return }
        horizontal += (x - horizontal) * 0.14
        vertical += (y - vertical) * 0.14
    }
}
