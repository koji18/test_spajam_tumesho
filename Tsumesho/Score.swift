import Foundation

/// 1 問を解いて得たスコアとその内訳
struct ScoreGain {
    let points: Int
    let speedBonus: Int
    let sizeMultiplier: Double
    let streakMultiplier: Double

    /// 基本点（1 手詰め 100・3 手詰め 300）に盤のサイズの倍率をかけ、スピードボーナスを足す。
    /// ヒント 1 段ごとに 25% 減らし（最低 25%）、最後に連勝の倍率をかける
    static func make(plies: Int, size: BoardSize, seconds: Int, hintsUsed: Int, streak: Int) -> ScoreGain {
        let base = Double(plies == 1 ? 100 : 300)
        let sizeMultiplier = switch size {
        case .small: 1.0
        case .medium: 1.2
        case .full: 1.5
        }
        /// 1 手詰めは 15 秒、3 手詰めは 40 秒より速いほど増える。最大で基本点の半分
        let par = plies == 1 ? 15.0 : 40.0
        let speedBonus = Int(base * 0.5 * max(0, 1 - Double(seconds) / par))
        let hintFactor = max(0.25, 1 - 0.25 * Double(hintsUsed))
        let streakMultiplier = streakMultiplier(for: streak)
        let points = Int(((base * sizeMultiplier + Double(speedBonus)) * hintFactor * streakMultiplier).rounded())
        return ScoreGain(points: points, speedBonus: speedBonus, sizeMultiplier: sizeMultiplier, streakMultiplier: streakMultiplier)
    }

    /// 連勝の倍率。2 連勝目から 0.1 ずつ上がり、最大 3 倍
    static func streakMultiplier(for streak: Int) -> Double {
        min(3, 1 + 0.1 * Double(max(0, streak - 1)))
    }

    /// 倍率を「x1.4」の形にする
    static func format(_ multiplier: Double) -> String {
        String(format: "x%.1f", multiplier)
    }
}

// 一度の正解の内訳を固定し、次の問題へ移っても同じ報酬を演出する。
struct SolveReward: Identifiable {
    let id = UUID()
    let gain: ScoreGain
    let streak: Int
    let previousRank: String
    let rank: String

    var rankedUp: Bool { previousRank != rank }
    var isMilestone: Bool { streak > 0 && streak.isMultiple(of: 5) }
}
