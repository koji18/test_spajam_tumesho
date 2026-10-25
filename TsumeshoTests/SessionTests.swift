import Foundation
import Testing
@testable import Tsumesho

/// 成績と設定。本物の成績を書き換えないよう、テストごとに専用の保存先を使う
@MainActor
struct SessionTests {
    let store = UserDefaults(suiteName: "SessionTests-\(UUID().uuidString)")!

    @Test func 初めて起動したときの値() {
        let session = Session(store: store)
        #expect(session.rating == 0)
        #expect(session.rankName == "10級")
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
            #expect(s.rating == 0)
            #expect(s.rankName == "10級")
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
        #expect(session.rating == 12)
        #expect(session.totalScore == gain.points)
    }

    @Test func 三手詰めはレーティングが20上がり_ヒントで減る() {
        let session = Session(store: store)
        session.recordSolve(plies: 3, size: .small, seconds: 0, hintsUsed: 0)
        #expect(session.rating == 20)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 3)
        #expect(session.rating == 22)  // 12 - 15 は最低の +2 になる
    }

    @Test func 間違えると連勝が0に戻りレーティングが10下がる() {
        let session = Session(store: store)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        session.recordMiss()
        #expect(session.streak == 0)
        #expect(session.bestStreak == 2)
        #expect(session.rating == 14)
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
        #expect(Session(store: store).rankBadge == "10級")
    }

    @Test func 未プレイの旧初期値は10級になり_再起動しても維持する() {
        store.set(1500, forKey: "rating")
        let session = Session(store: store)
        #expect(session.rating == 0)
        #expect(session.rankName == "10級")
        #expect(Session(store: store).rating == 0)
        session.recordSolve(plies: 1, size: .small, seconds: 0, hintsUsed: 0)
        #expect(Session(store: store).rating == 12)
    }

    @Test func 旧開始点だけを一度差し引き_獲得分と成績を引き継ぐ() {
        store.set(1512, forKey: "rating")
        store.set(1, forKey: "solvedTotal")
        store.set(374, forKey: "totalScore")
        store.set(1, forKey: "streak")
        let session = Session(store: store)
        #expect(session.rating == 12)
        #expect(session.rankName == "10級")
        #expect(session.solvedTotal == 1)
        #expect(session.totalScore == 374)
        #expect(session.streak == 1)
        #expect(Session(store: store).rating == 12)
    }

    @Test func 旧レーティングの移行でも0未満にならない() {
        store.set(1490, forKey: "rating")
        #expect(Session(store: store).rating == 0)
    }

    @Test func 十級で間違えてもレーティングは0未満にならない() {
        let session = Session(store: store)
        session.recordMiss()
        #expect(session.rating == 0)
        #expect(session.rankName == "10級")
    }

    @Test func 段位の境目と名前() {
        let boundaries: [(rating: Int, name: String)] = [
            (0, "10級"), (500, "9級"), (600, "8級"), (700, "7級"), (800, "6級"),
            (900, "5級"), (1000, "4級"), (1100, "3級"), (1200, "2級"), (1300, "1級"),
            (1400, "初段"), (1600, "二段"), (1800, "三段"), (2000, "四段"),
            (2200, "五段"), (2400, "六段"), (2600, "七段"), (2800, "八段"),
        ]
        #expect(Session.ranks.count == 18)
        for (index, boundary) in boundaries.enumerated() {
            #expect(Session.rank(for: boundary.rating).name == boundary.name)
            #expect(Session.rank(for: boundary.rating + 1).name == boundary.name)
            if index > 0 {
                #expect(Session.rank(for: boundary.rating - 1).name == boundaries[index - 1].name)
            }
        }
        #expect(Session.rank(for: -1).name == "10級")
        #expect(Session.rank(for: 10_000).name == "八段")
        #expect(Session.Rank.name(ofBadge: "10級") == "10級")
        #expect(Session.Rank.name(ofBadge: "八") == "八段")
    }

    @Test func 次の段までの進み具合() throws {
        let next = try #require(Session.nextRank(for: 1500))
        #expect(next.rank.name == "二段")
        #expect(next.remaining == 100)
        #expect(next.fraction == 0.5)
        let fromKyu = try #require(Session.nextRank(for: 1350))
        #expect(fromKyu.rank.name == "初段")
        #expect(fromKyu.fraction == 0.5)
        #expect(fromKyu.remaining == 50)
        let first = try #require(Session.nextRank(for: 250))
        #expect(first.rank.name == "9級")
        #expect(first.fraction == 0.5)
        #expect(first.remaining == 250)
        let upper = try #require(Session.nextRank(for: 2700))
        #expect(upper.rank.name == "八段")
        #expect(upper.fraction == 0.5)
        #expect(upper.remaining == 100)
        #expect(Session.nextRank(for: 2800) == nil)
        #expect(Session.nextRank(for: 10_000) == nil)
    }

    @Test func 保存済みのレーティングを変えずに新しい段位を表示する() {
        store.set(2526, forKey: "rating")
        store.set(true, forKey: "ratingStartsAtTenKyu")
        let session = Session(store: store)
        #expect(session.rating == 2526)
        #expect(session.rankBadge == "六")
        #expect(session.rankName == "六段")
        #expect(store.integer(forKey: "rating") == 2526)
    }
}
