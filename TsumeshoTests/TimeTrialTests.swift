import Foundation
import Testing
@testable import Tsumesho

/// タイムトライアル（60 秒から始め、正解で足し、間違いで減らす）
@MainActor
struct TimeTrialTests {
    @Test func 始めると残り60秒() {
        let trial = TimeTrial()
        trial.begin()
        #expect(trial.isRunning)
        #expect(abs(trial.remaining() - 60) < 0.5)
    }

    @Test func 正解すると一手詰めは5秒_三手詰めは12秒増える() {
        let trial = TimeTrial()
        trial.begin()
        trial.recordSolve(plies: 1, hintsUsed: 0)
        #expect(abs(trial.remaining() - 65) < 0.5)
        trial.recordSolve(plies: 3, hintsUsed: 0)
        #expect(abs(trial.remaining() - 77) < 0.5)
        #expect(trial.solved == 2)
    }

    @Test func ヒントを使うと増える時間は半分() {
        let trial = TimeTrial()
        trial.begin()
        trial.recordSolve(plies: 3, hintsUsed: 1)
        #expect(abs(trial.remaining() - 66) < 0.5)
    }

    @Test func 間違えると5秒減る() {
        let trial = TimeTrial()
        trial.begin()
        trial.recordMiss()
        #expect(abs(trial.remaining() - 55) < 0.5)
    }

    @Test func 始めていないときは記録しない() {
        let trial = TimeTrial()
        trial.recordSolve(plies: 1, hintsUsed: 0)
        trial.recordMiss()
        #expect(!trial.isRunning)
        #expect(trial.solved == 0)
    }

    @Test func 時間切れで止まり_やり直すと元に戻る() {
        let trial = TimeTrial()
        trial.begin()
        trial.recordSolve(plies: 1, hintsUsed: 0)
        trial.finish()
        #expect(!trial.isRunning)
        trial.begin()
        #expect(trial.isRunning)
        #expect(trial.solved == 0)
    }

    @Test func 残り時間の表示() {
        #expect(TimeTrial.format(84) == "01:24")
        #expect(TimeTrial.format(0.2) == "00:01")
        #expect(TimeTrial.format(0) == "00:00")
    }
}
