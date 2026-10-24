import Foundation
import Testing
@testable import Tsumesho

/// 成績と設定。本物の成績を書き換えないよう、テストごとに専用の保存先を使う
@MainActor
struct SessionTests {
    let store = UserDefaults(suiteName: "SessionTests-\(UUID().uuidString)")!

    @Test func 初めて起動したときの値() {
        let session = Session(store: store)
        #expect(session.rating == 1500)
        #expect(session.boardSize == .full)
        #expect(session.mode == .normal)
        #expect(session.hapticsOn)
        #expect(!session.tutorialCleared)
        #expect(session.totalScore == 0)
    }

    @Test func 正解すると連勝とレーティングとスコアが増える() {
        let session = Session(store: store)
        let gain = session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        #expect(session.streak == 1)
        #expect(session.solvedTotal == 1)
        #expect(session.rating == 1512)
        #expect(session.totalScore == gain.points)
    }

    @Test func 三手詰めはレーティングが20上がり_ヒントで減る() {
        let session = Session(store: store)
        session.recordSolve(plies: 3, size: .small, seconds: 0, hintsUsed: 0)
        #expect(session.rating == 1520)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 3)
        #expect(session.rating == 1522)  // 12 - 15 は最低の +2 になる
    }

    @Test func 間違えると連勝が0に戻りレーティングが10下がる() {
        let session = Session(store: store)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        session.recordMiss()
        #expect(session.streak == 0)
        #expect(session.bestStreak == 2)
        #expect(session.rating == 1514)
    }

    @Test func カードのスコアは数え上げるまで前の値のまま() async {
        let session = Session(store: store)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        #expect(session.displayedScore == 0)
        await session.revealScore()
        #expect(session.displayedScore == session.totalScore)
        #expect(session.scorePopup == nil)
    }

    @Test func 成績と設定は保存され_次に起動したときに読み込まれる() {
        let session = Session(store: store)
        session.recordSolve(plies: 3, size: .full, seconds: 10, hintsUsed: 0)
        session.boardSize = .medium
        session.mode = .timeTrial
        session.tutorialCleared = true
        session.recordTimeTrial(solved: 7)

        let reloaded = Session(store: store)
        #expect(reloaded.rating == session.rating)
        #expect(reloaded.totalScore == session.totalScore)
        #expect(reloaded.displayedScore == session.totalScore)
        #expect(reloaded.streak == 1)
        #expect(reloaded.boardSize == .medium)
        #expect(reloaded.mode == .timeTrial)
        #expect(reloaded.tutorialCleared)
        #expect(reloaded.timeTrialBest == 7)
    }

    @Test func タイムトライアルの最高記録は下がらない() {
        let session = Session(store: store)
        session.recordTimeTrial(solved: 7)
        session.recordTimeTrial(solved: 3)
        #expect(session.timeTrialBest == 7)
    }

    @Test func 段位のバッジ() {
        #expect(Session(store: store).rankBadge == "初")
    }
}
