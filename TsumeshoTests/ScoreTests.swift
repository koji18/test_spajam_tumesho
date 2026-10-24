import Testing
@testable import Tsumesho

/// スコアの計算（基本点・盤のサイズの倍率・スピードボーナス・ヒントの減点・連勝の倍率）
struct ScoreTests {
    @Test func 一手詰めを5x5で即答すると基本点にスピードボーナスの最大が足される() {
        let gain = ScoreGain.make(plies: 1, size: .small, seconds: 0, hintsUsed: 0, streak: 1)
        #expect(gain.speedBonus == 50)
        #expect(gain.points == 150)
    }

    @Test func 三手詰めを9x9で20秒_5連勝目なら735点() {
        let gain = ScoreGain.make(plies: 3, size: .full, seconds: 20, hintsUsed: 0, streak: 5)
        #expect(gain.speedBonus == 75)
        #expect(gain.sizeMultiplier == 1.5)
        #expect(gain.streakMultiplier == 1.4)
        #expect(gain.points == 735)
    }

    @Test func 時間をかけるとスピードボーナスは0() {
        #expect(ScoreGain.make(plies: 1, size: .small, seconds: 15, hintsUsed: 0, streak: 1).speedBonus == 0)
        #expect(ScoreGain.make(plies: 3, size: .small, seconds: 99, hintsUsed: 0, streak: 1).speedBonus == 0)
    }

    @Test func ヒント1段ごとに25パーセント減らし_最低25パーセントは残る() {
        #expect(ScoreGain.make(plies: 1, size: .small, seconds: 0, hintsUsed: 2, streak: 1).points == 75)
        #expect(ScoreGain.make(plies: 1, size: .small, seconds: 0, hintsUsed: 4, streak: 1).points == 38)
        #expect(ScoreGain.make(plies: 1, size: .small, seconds: 0, hintsUsed: 9, streak: 1).points == 38)
    }

    @Test func 連勝の倍率は2連勝目から上がり_3倍で止まる() {
        #expect(ScoreGain.streakMultiplier(for: 1) == 1)
        #expect(ScoreGain.streakMultiplier(for: 2) == 1.1)
        #expect(ScoreGain.streakMultiplier(for: 21) == 3)
        #expect(ScoreGain.streakMultiplier(for: 50) == 3)
    }

    @Test func 倍率の表示() {
        #expect(ScoreGain.format(1.4) == "x1.4")
        #expect(ScoreGain.format(3) == "x3.0")
    }
}
