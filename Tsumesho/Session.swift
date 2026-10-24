import Foundation
import Observation

enum PlayMode: String {
    case tutorial
    case normal
    case timeTrial
    case zen      // 修行。ノーマルで間違えた問題を解き直す

    var title: String {
        switch self {
        case .tutorial: "TUTORIAL"
        case .normal: "NORMAL"
        case .timeTrial: "TIME TRIAL"
        case .zen: "ZEN"
        }
    }

    /// 読み上げなどに使う日本語の名前
    var label: String {
        switch self {
        case .tutorial: "チュートリアル"
        case .normal: "ノーマル"
        case .timeTrial: "タイムトライアル"
        case .zen: "修行"
        }
    }
}

// 遊び方の設定と成績。問題のページをまたいで共有し、次に起動したときも残す
@MainActor @Observable
final class Session {
    private let store: UserDefaults
    /// ノーマルでミスした問題。修行モードで解き直す
    let practice: PracticeLibrary

    var mode: PlayMode { didSet { store.set(mode.rawValue, forKey: "mode") } }
    var boardSize: BoardSize { didSet { store.set(boardSize.rawValue, forKey: "boardSize") } }
    var hapticsOn: Bool { didSet { store.set(hapticsOn, forKey: "hapticsOn") } }
    /// 効果音の音量（0〜1）。0 なら鳴らさない
    var soundVolume: Double { didSet { store.set(soundVolume, forKey: "soundVolume") } }
    /// BGM の音量（0〜1）。0 なら流さない
    var musicVolume: Double { didSet { store.set(musicVolume, forKey: "musicVolume") } }
    /// 初回のチュートリアルを詰ませたか。詰ませるまでは普通の見た目で出し、詰ませたらネオンの見た目に切り替える
    var tutorialCleared: Bool { didSet { store.set(tutorialCleared, forKey: "tutorialCleared") } }

    // 入門チュートリアルの、段ごとの星（0 はまだ解いていない）。段はいつでも好きな順に行き来できる
    private(set) var tutorialStars: [Int] { didSet { store.set(tutorialStars, forKey: "tutorialStars") } }
    var tutorialSolved: Int { tutorialStars.filter { $0 > 0 }.count }
    var tutorialDone: Bool { tutorialSolved >= TutorialStage.all.count }
    // 次に挑む段（最初の未クリアの段。全部終えていれば最初）
    var tutorialNext: Int { tutorialStars.firstIndex(of: 0) ?? 0 }

    func recordTutorial(stage: Int, stars: Int) {
        guard tutorialStars.indices.contains(stage) else { return }
        tutorialStars[stage] = max(tutorialStars[stage], stars)
    }

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
        practice = PracticeLibrary(store: store)
        // はじめて起動したときは、入門から始める。すでに遊んでいる人はノーマルのまま
        let played = store.integer(forKey: "solvedTotal") > 0
        mode = PlayMode(rawValue: store.string(forKey: "mode") ?? "") ?? (played ? .normal : .tutorial)
        let saved = store.array(forKey: "tutorialStars") as? [Int] ?? []
        tutorialStars = (0..<TutorialStage.all.count).map { $0 < saved.count ? saved[$0] : 0 }
        boardSize = BoardSize(rawValue: store.string(forKey: "boardSize") ?? "") ?? .full
        hapticsOn = store.object(forKey: "hapticsOn") as? Bool ?? true
        soundVolume = store.object(forKey: "soundVolume") as? Double ?? 0.8
        musicVolume = store.object(forKey: "musicVolume") as? Double ?? 0.6
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

    /// 途中の数え上げを止めて、カードのスコアを累計に合わせ、「+○○」を消す。
    /// pending には、累計に足したがまだ数え上げていない点（詰ませた直後の問題の点）を渡す。その分はあとの revealScore で数え上げる
    func settleScore(excludingPending pending: Int = 0) {
        scoreRevealID = UUID()
        displayedScore = totalScore - pending
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

    /// 段位。レーティングが lowerBound 以上になると、その段位になる
    struct Rank: Equatable {
        let badge: String     // バッジの一文字（級・初・二…）
        let lowerBound: Int

        /// 段位の名前（級位・初段・二段…）
        var name: String { Rank.name(ofBadge: badge) }

        /// バッジの一文字から段位の名前を作る
        static func name(ofBadge badge: String) -> String { badge == "級" ? "級位" : "\(badge)段" }
    }

    /// 段位の一覧。段位の境目と名前は、ここだけで決める。級位の lowerBound は、ホームのゲージの起点
    static let ranks: [Rank] = [
        Rank(badge: "級", lowerBound: 1200),
        Rank(badge: "初", lowerBound: 1400),
        Rank(badge: "二", lowerBound: 1600),
        Rank(badge: "三", lowerBound: 1800),
        Rank(badge: "四", lowerBound: 2000),
        Rank(badge: "五", lowerBound: 2200),
    ]

    /// rating のときの段位
    static func rank(for rating: Int) -> Rank {
        ranks.last { rating >= $0.lowerBound && $0.badge != "級" } ?? ranks[0]
    }

    /// 次の段位と、そこまでの進み具合（0〜1）と、あと何点か。最高段なら nil
    static func nextRank(for rating: Int) -> (rank: Rank, fraction: Double, remaining: Int)? {
        let current = rank(for: rating)
        guard let i = ranks.firstIndex(of: current), i + 1 < ranks.count else { return nil }
        let next = ranks[i + 1]
        let span = Double(next.lowerBound - current.lowerBound)
        let fraction = min(1, max(0, Double(rating - current.lowerBound) / span))
        return (next, fraction, next.lowerBound - rating)
    }

    /// レーティングに応じた段位のバッジ
    var rankBadge: String { Self.rank(for: rating).badge }

    var rankName: String { Self.rank(for: rating).name }
}
