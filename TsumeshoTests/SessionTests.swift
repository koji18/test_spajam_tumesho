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
        #expect(session.mode == .tutorial)  // はじめて起動した人は入門から始める
        #expect(session.hapticsOn)
        #expect(!session.tutorialCleared)
        #expect(session.totalScore == 0)
        #expect(session.soundVolume == 0.8)
    }

    @Test func 記録をすべて消すと_はじめて起動したときに戻る() {
        let session = Session(store: store)
        session.recordSolve(plies: 3, size: .small, seconds: 0, hintsUsed: 0)
        session.recordTimeTrial(solved: 5)
        session.recordTutorial(stage: 0, stars: 3)
        session.practice.recordMistake(.tutorial(.small), mode: .normal)
        session.tutorialCleared = true
        session.mode = .timeTrial
        session.musicVolume = 0
        session.resetAll()
        // 次に起動したときも、消したままになっている
        let restarted = Session(store: store)
        for s in [session, restarted] {
            #expect(s.rating == 1500)
            #expect(s.totalScore == 0 && s.displayedScore == 0)
            #expect(s.streak == 0 && s.bestStreak == 0 && s.solvedTotal == 0 && s.timeTrialBest == 0)
            #expect(s.tutorialSolved == 0)
            #expect(s.practice.entries.isEmpty)
            #expect(!s.tutorialCleared)
            #expect(s.mode == .tutorial)
            #expect(s.musicVolume == 0.6)
        }
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

    @Test func 数え上げの途中で次を詰ませても_前の表示を片づけて今回の分だけ数え上げる() async {
        let session = Session(store: store)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        let first = session.totalScore
        let second = session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        // 前の問題の数え上げが終わる前に、次の問題を詰ませた
        session.settleScore(excludingPending: second.points)
        #expect(session.displayedScore == first)
        #expect(session.scorePopup == nil)
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
        session.soundVolume = 0.3

        let reloaded = Session(store: store)
        #expect(reloaded.rating == session.rating)
        #expect(reloaded.totalScore == session.totalScore)
        #expect(reloaded.displayedScore == session.totalScore)
        #expect(reloaded.streak == 1)
        #expect(reloaded.boardSize == .medium)
        #expect(reloaded.mode == .timeTrial)
        #expect(reloaded.tutorialCleared)
        #expect(reloaded.timeTrialBest == 7)
        #expect(reloaded.soundVolume == 0.3)
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

    @Test func 段位の境目と名前() {
        #expect(Session.rank(for: 1100).badge == "級")
        #expect(Session.rank(for: 1399).name == "級位")
        #expect(Session.rank(for: 1400).name == "初段")
        #expect(Session.rank(for: 1999).badge == "三")
        #expect(Session.rank(for: 2500).name == "五段")
    }

    @Test func 次の段までの進み具合() throws {
        let next = try #require(Session.nextRank(for: 1500))
        #expect(next.rank.name == "二段")
        #expect(next.remaining == 100)
        #expect(next.fraction == 0.5)
        let fromKyu = try #require(Session.nextRank(for: 1300))
        #expect(fromKyu.rank.name == "初段")
        #expect(fromKyu.fraction == 0.5)  // 級位のゲージは 1200 から
        #expect(Session.nextRank(for: 2200) == nil)  // 最高段
    }
}
