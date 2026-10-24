import SwiftUI

@main
struct TsumeshoApp: App {
    @State private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.dark)
        }
    }
}

// 最初の画面で盤の大きさを選んで始め、「トップ」で最初の画面に戻る。
// 作った問題は戻っても残しておき、同じ大きさで始め直すと 1 問目から並ぶ
struct RootView: View {
    @Environment(Session.self) private var session
    @State private var feed = ProblemFeed()
    @State private var playing = false

    var body: some View {
        ZStack {
            if playing {
                FeedView(feed: feed, size: session.smallBoard ? .small : .full) { playing = false }
                    .transition(.move(edge: .bottom))
            } else {
                IntroPage {
                    // 1 問目を解いているあいだに、2 問目からの作り置きを始めておく
                    feed.didShow(index: 0, size: session.smallBoard ? .small : .full)
                    playing = true
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: playing)
    }
}

// 問題を縦に並べ、ショート動画のように 1 問ずつスワイプで送る。
// 1 問目の例題のあとは、裏で作った問題が続く
struct FeedView: View {
    let feed: ProblemFeed
    let size: BoardSize
    let onExit: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(feed.problems(size).enumerated()), id: \.element.key) { index, problem in
                        ProblemPage(problem: problem, insets: geo.safeAreaInsets, onExit: onExit)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .onAppear { feed.didShow(index: index, size: size) }
                    }
                    // 作り置きが追いつかなかったときに見えるページ。問題ができると、この前に足される
                    GeneratingPage()
                        .containerRelativeFrame([.horizontal, .vertical])
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

struct GeneratingPage: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(Theme.accent)
            Text("次の問題を作っています…").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
