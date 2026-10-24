import SwiftUI

@main
struct TsumeshoApp: App {
    @State private var session = Session()

    var body: some Scene {
        WindowGroup {
            FeedView()
                .environment(session)
                .preferredColorScheme(.dark)
        }
    }
}

// 問題を縦に並べ、ショート動画のように 1 問ずつスワイプで送る
struct FeedView: View {
    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    IntroPage(insets: geo.safeAreaInsets)
                        .containerRelativeFrame([.horizontal, .vertical])
                    ForEach(problems) { problem in
                        ProblemPage(problem: problem, total: problems.count, insets: geo.safeAreaInsets)
                            .containerRelativeFrame([.horizontal, .vertical])
                    }
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
