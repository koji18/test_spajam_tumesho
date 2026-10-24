import Foundation
import Testing
@testable import Tsumesho

/// 詰みの音の高さ。連勝が続くほど、ドレミファソラシドの音階で高くする
@MainActor
struct SoundTests {
    private func semitones(_ streak: Int) -> Int {
        Int((12 * log2(Double(Sound.mateRate(streak: streak)))).rounded())
    }

    @Test func 連勝ごとにドレミの音階で上がる() {
        #expect(Sound.mateRate(streak: 0) == 1)
        #expect((1...8).map(semitones) == [0, 2, 4, 5, 7, 9, 11, 12])
    }

    @Test func 八連勝で1オクターブ上になり頭打ち() {
        #expect(abs(Sound.mateRate(streak: 8) - 2) < 0.0001)
        #expect(Sound.mateRate(streak: 30) == Sound.mateRate(streak: 8))
    }
}
