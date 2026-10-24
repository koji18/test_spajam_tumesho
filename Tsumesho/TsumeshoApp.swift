import SwiftUI

@main
struct TsumeshoApp: App {
    @State private var session = Session()
    @State private var trial = TimeTrial()

    /// 起動時に、同梱したフォントを登録する
    init() {
        Theme.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(trial)
                .environment(\.palette, session.palette)
                .preferredColorScheme(session.tutorialCleared ? .dark : .light)
        }
    }
}

/// 最初の画面で盤の大きさを選んで始め、メニューの「ホーム」で最初の画面に戻る。
/// 作った問題は戻っても残しておく
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(TimeTrial.self) private var trial
    @State private var feed = ProblemFeed()
    @State private var playing = false

    var body: some View {
        ZStack {
            if playing {
                FeedView(feed: feed) {
                    trial.stop()
                    playing = false
                }
                .transition(.move(edge: .bottom))
            } else {
                IntroPage {
                    // 1 問目を解いているあいだに、2 問目からの作り置きを始めておく
                    feed.didShow(index: 0, size: session.boardSize)
                    if session.mode == .timeTrial { trial.begin() }
                    playing = true
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: playing)
    }
}
