import Foundation
import Observation

enum PlayMode: String {
    case normal
    case timeTrial

    var title: String { self == .normal ? "NORMAL" : "TIME TRIAL" }
}

// 遊び方の設定と成績。問題のページをまたいで共有し、次に起動したときも残す
@MainActor @Observable
final class Session {
    private let store: UserDefaults

    var mode: PlayMode { didSet { store.set(mode.rawValue, forKey: "mode") } }
    var boardSize: BoardSize { didSet { store.set(boardSize.rawValue, forKey: "boardSize") } }
    var hapticsOn: Bool { didSet { store.set(hapticsOn, forKey: "hapticsOn") } }
    /// 効果音の音量（0〜1）。0 なら鳴らさない
    var soundVolume: Double { didSet { store.set(soundVolume, forKey: "soundVolume") } }
    /// 初回のチュートリアルを詰ませたか。詰ませるまでは普通の見た目で出し、詰ませたらネオンの見た目に切り替える
    var tutorialCleared: Bool { didSet { store.set(tutorialCleared, forKey: "tutorialCleared") } }

    var palette: Palette { tutorialCleared ? .neon : .classic }

    private(set) var rating: Int { didSet { store.set(rating, forKey: "rating") } }
    private(set) var streak: Int { didSet { store.set(streak, forKey: "streak") } }
    private(set) var bestStreak: Int { didSet { store.set(bestStreak, forKey: "bestStreak") } }
    private(set) var solvedTotal: Int { didSet { store.set(solvedTotal, forKey: "solvedTotal") } }
    private(set) var timeTrialBest: Int { didSet { store.set(timeTrialBest, forKey: "timeTrialBest") } }
    private(set) var totalScore: Int { didSet { store.set(totalScore, forKey: "totalScore") } }
    /// カードに出しているスコア。解いた直後は前の値のままにしておき、演出が消えてから数え上げる
    private(set) var displayedScore: Int
    /// 数え上げている間だけ、カードの横に「+735」と出す
    private(set) var scorePopup: Int?
    private var scoreRevealID = UUID()

    /// 保存してある設定と成績を読み込む。テストでは store にテスト専用の保存先を渡す
    init(store: UserDefaults = .standard) {
        self.store = store
        mode = PlayMode(rawValue: store.string(forKey: "mode") ?? "") ?? .normal
        boardSize = BoardSize(rawValue: store.string(forKey: "boardSize") ?? "") ?? .full
        hapticsOn = store.object(forKey: "hapticsOn") as? Bool ?? true
        soundVolume = store.object(forKey: "soundVolume") as? Double ?? 0.8
        tutorialCleared = store.bool(forKey: "tutorialCleared")
        rating = store.object(forKey: "rating") as? Int ?? 1500
        streak = store.integer(forKey: "streak")
        bestStreak = store.integer(forKey: "bestStreak")
        solvedTotal = store.integer(forKey: "solvedTotal")
        timeTrialBest = store.integer(forKey: "timeTrialBest")
        let score = store.integer(forKey: "totalScore")
        totalScore = score
        displayedScore = score
    }

    /// 正解したとき。連勝と正解数を増やし、レーティングを上げ、スコアを累計に足して、得た点を返す。
    /// レーティングは 1 手詰めで +12、3 手詰めで +20。ヒントを 1 段使うごとに 5 減らす（最低 +2）。
    /// 間違えたときは recordMiss（レーティング -10、連勝を 0 に戻す）
    @discardableResult
    func recordSolve(plies: Int, size: BoardSize, seconds: Int, hintsUsed: Int) -> ScoreGain {
        streak += 1
        solvedTotal += 1
        bestStreak = max(bestStreak, streak)
        rating += max(2, (plies == 1 ? 12 : 20) - hintsUsed * 5)
        let gain = ScoreGain.make(plies: plies, size: size, seconds: seconds, hintsUsed: hintsUsed, streak: streak)
        totalScore += gain.points
        return gain
    }

    /// カードのスコアを、今の表示から累計まで約 0.8 秒で数え上げる
    func revealScore() async {
        let revealID = UUID()
        scoreRevealID = revealID
        let from = displayedScore
        let to = totalScore
        guard to > from else { return }
        scorePopup = to - from
        let steps = 24
        for i in 1...steps {
            guard !Task.isCancelled, scoreRevealID == revealID else { return }
            displayedScore = from + (to - from) * i / steps
            do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
        }
        displayedScore = to
        do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
        guard scoreRevealID == revealID else { return }
        scorePopup = nil
    }

    func settleScore() {
        scoreRevealID = UUID()
        displayedScore = totalScore
        scorePopup = nil
    }

    /// 間違えたとき。レーティングを下げ、連勝を 0 に戻す
    func recordMiss() {
        streak = 0
        rating = max(0, rating - 10)
    }

    /// 次に解いたときにかかる連勝の倍率
    var nextStreakMultiplier: Double { ScoreGain.streakMultiplier(for: streak + 1) }

    /// タイムトライアルが終わったとき。最高記録を更新する
    func recordTimeTrial(solved: Int) {
        timeTrialBest = max(timeTrialBest, solved)
    }

    /// レーティングに応じた段位のバッジ
    var rankBadge: String {
        switch rating {
        case ..<1400: "級"
        case ..<1600: "初"
        case ..<1800: "二"
        case ..<2000: "三"
        case ..<2200: "四"
        default: "五"
        }
    }

    var rankName: String { rankBadge == "級" ? "級位" : "\(rankBadge)段" }
}
