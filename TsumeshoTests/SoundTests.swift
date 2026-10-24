import Foundation
import Testing
@testable import Tsumesho

/// 詰みの音の高さ。連勝が続くほど高くする
@MainActor
struct SoundTests {
    @Test func 連勝が1つ増えるごとに半音ずつ上がる() {
        #expect(Sound.mateRate(streak: 0) == 1)
        #expect(Sound.mateRate(streak: 1) == 1)
        #expect(abs(Sound.mateRate(streak: 2) - Float(pow(2, 1.0 / 12))) < 0.0001)
        #expect(Sound.mateRate(streak: 8) < Sound.mateRate(streak: 9))
    }

    @Test func 九連勝で頭打ちになる() {
        #expect(Sound.mateRate(streak: 9) == Sound.mateRate(streak: 30))
        #expect(abs(Sound.mateRate(streak: 9) - Float(pow(2, 8.0 / 12))) < 0.0001)
    }
}
