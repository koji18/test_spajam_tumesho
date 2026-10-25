import SwiftUI

/// 画面の高さに合わせた部品の大きさ。高さ 760pt より低い機種（SE・mini など）では、
/// 盤のまわりの部品と間隔を詰めて、盤を大きく残す
struct PageLayout {
    let compact: Bool

    static let regular = PageLayout(compact: false)

    /// 画面全体の高さ（安全領域も含む）から決める
    static func forScreen(height: CGFloat) -> PageLayout {
        PageLayout(compact: height < 760)
    }

    var topBarHeight: CGFloat { compact ? 60 : 72 }
    var barButton: CGFloat { compact ? 44 : 52 }
    var spacing: CGFloat { compact ? 7 : 12 }
    var title: CGFloat { compact ? 26 : 34 }
    var counter: CGFloat { compact ? 24 : 30 }
    var handTile: CGFloat { compact ? 50 : 60 }
    var handPiece: CGFloat { compact ? 38 : 46 }
    var handRowHeight: CGFloat { compact ? 64 : 78 }
    var badge: CGFloat { compact ? 38 : 46 }
    var rating: CGFloat { compact ? 24 : 30 }
    var score: CGFloat { compact ? 18 : 22 }
    var cardPadding: CGFloat { compact ? 8 : 12 }
    var circleButton: CGFloat { compact ? 50 : 60 }
    /// レーティングのカードと、間違えたときのカードの高さ。入れ替えても盤の大きさが変わらないように同じにする
    var cardHeight: CGFloat { compact ? 58 : 74 }
}

private struct PageLayoutKey: EnvironmentKey {
    static let defaultValue = PageLayout.regular
}

extension EnvironmentValues {
    /// 画面の高さに合わせた部品の大きさ。FeedView が画面の大きさから決めて渡す
    var pageLayout: PageLayout {
        get { self[PageLayoutKey.self] }
        set { self[PageLayoutKey.self] = newValue }
    }
}
