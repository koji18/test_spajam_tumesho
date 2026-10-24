import SwiftUI

@main
struct TsumeshoApp: App {
    @State private var session = Session()
    @State private var trial = TimeTrial()

    init() {
        Theme.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(trial)
                .environment(\.palette, session.palette)
        }
    }
}

// 最初の画面で盤の大きさを選んで始め、メニューの「ホーム」で最初の画面に戻る。
// 作った問題は戻っても残しておく
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(TimeTrial.self) private var trial
    @State private var feed = ProblemFeed()
    @State private var playing = false

    var body: some View {
        ZStack {
            if playing && session.mode == .tutorial {
                TutorialView(startAt: session.tutorialNext) {
                    playing = false
                } onFinish: {
                    // 修了したらノーマルで実戦へ。1 問目を解いているあいだに、作り置きも始めておく
                    session.mode = .normal
                    feed.didShow(index: 0, size: session.boardSize)
                }
                .transition(.move(edge: .bottom))
            } else if playing {
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
        // ホームと入門は明るい和紙の見た目なので、いつも明るい表示にする。暗くするのは、ネオンの問題画面だけ
        .preferredColorScheme(playing && session.mode != .tutorial && session.tutorialCleared ? .dark : .light)
    }
}

// 問題を縦に並べ、ショート動画のように 1 問ずつスワイプで送る。
// 1 問目の例題のあとは、裏で作った問題が続く。上のバーとメニュー、詰み演出は列の上のレイヤーに出す
struct FeedView: View {
    let feed: ProblemFeed
    let onHome: () -> Void

    @Environment(Session.self) private var session
    @Environment(TimeTrial.self) private var trial

    // 今見ているページ。問題は problem.key、作り置きを待つページは "generating"
    @State private var currentPage: String?
    // 盤のサイズを切り替えたとき、前に見ていたページに戻るために覚えておく
    @State private var lastPage: [BoardSize: String] = [:]
    @State private var celebration: Celebration?
    @State private var menuOpen = false
    @State private var showRecords = false
    @State private var showSettings = false

    struct Celebration: Identifiable {
        let id = UUID()
        let problem: Problem
        let seconds: Int
        let tesuji: String?
        var slid = false
    }

    private var size: BoardSize { session.boardSize }
    private var problems: [Problem] { feed.problems(size) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(problems.enumerated()), id: \.element.key) { index, problem in
                            ProblemPage(problem: problem, insets: geo.safeAreaInsets) { seconds, tesuji in
                                celebrate(problem, seconds: seconds, tesuji: tesuji)
                            }
                            .containerRelativeFrame([.horizontal, .vertical])
                            .onAppear { feed.didShow(index: index, size: size) }
                        }
                        // 作り置きが追いつかなかったときに見えるページ。問題ができると、この前に足される
                        GeneratingPage()
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id("generating")
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $currentPage)
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .ignoresSafeArea()
                .blur(radius: menuOpen ? 10 : 0)

                TopBar(insets: geo.safeAreaInsets, menuOpen: menuOpen) {
                    withAnimation(.spring(duration: 0.3)) { menuOpen.toggle() }
                }

                if menuOpen {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(duration: 0.3)) { menuOpen = false } }
                        .transition(.opacity)
                    MenuPanel(
                        onHome: { closeMenu(); onHome() },
                        onMode: { mode in closeMenu(); select(mode) },
                        onRecords: { closeMenu(); showRecords = true },
                        onSettings: { closeMenu(); showSettings = true },
                        onSize: { newSize in closeMenu(); switchSize(to: newSize) }
                    )
                    .padding(.top, geo.safeAreaInsets.top + TopBar.height + 4)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
                    .zIndex(2)
                }

                if let c = celebration {
                    MateEffectView(plies: c.problem.plies, seconds: c.seconds, tesuji: c.tesuji, seed: c.problem.id) {
                        finishCelebration()
                    }
                    .id(c.id)
                    .transition(.opacity)
                    .zIndex(3)
                }

                if trial.finished {
                    TimeUpView(
                        solved: trial.solved,
                        best: session.timeTrialBest,
                        onRetry: { trial.begin() },
                        onNormal: { trial.stop(); session.mode = .normal }
                    )
                    .transition(.opacity)
                    .zIndex(4)
                }
            }
            // 上のバーとメニューは geo.safeAreaInsets で自分で安全領域をよける
            .ignoresSafeArea()
        }
        .background(Theme.background.ignoresSafeArea())
        .onChange(of: problems.count) {
            // 作り置きを待っているあいだに問題ができたら、その問題へ進む
            if currentPage == "generating", let last = problems.last {
                withAnimation(.easeInOut(duration: 0.45)) { currentPage = last.key }
            }
        }
        // タイムトライアルの持ち時間を見張り、0 になったら結果を出す
        .task(id: trial.startedAt) {
            while trial.isRunning {
                if trial.remaining() <= 0 {
                    trial.finish()
                    session.recordTimeTrial(solved: trial.solved)
                    break
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        .sheet(isPresented: $showRecords) { RecordsView() }
        .sheet(isPresented: $showSettings) {
            SettingsView { showSettings = false; onHome() }
        }
    }

    private func closeMenu() {
        withAnimation(.spring(duration: 0.3)) { menuOpen = false }
    }

    private func select(_ mode: PlayMode) {
        session.mode = mode
        if mode == .timeTrial { trial.begin() } else { trial.stop() }
    }

    // 盤のサイズを変えたら、その大きさの問題の列に移る。前に見ていたページがあればそこへ
    private func switchSize(to newSize: BoardSize) {
        guard newSize != size else { return }
        lastPage[size] = currentPage
        session.boardSize = newSize
        feed.didShow(index: 0, size: newSize)
        currentPage = lastPage[newSize] ?? feed.problems(newSize).first?.key
    }

    // 演出を出し、少し見せてから下の列だけを次の問題へスライドさせ、最後に演出を消す
    private func celebrate(_ problem: Problem, seconds: Int, tesuji: String?) {
        Haptics.mate(enabled: session.hapticsOn)
        let c = Celebration(problem: problem, seconds: seconds, tesuji: tesuji)
        withAnimation(.easeOut(duration: 0.15)) { celebration = c }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            guard celebration?.id == c.id else { return }
            // 初回のチュートリアルを詰ませたら、演出の裏で普通の見た目からネオンの見た目に切り替える
            if !session.tutorialCleared {
                withAnimation(.easeInOut(duration: 0.6)) { session.tutorialCleared = true }
            }
            slideToNext()
            try? await Task.sleep(for: .seconds(1.3))
            guard celebration?.id == c.id else { return }
            withAnimation(.easeOut(duration: 0.35)) { celebration = nil }
            // 演出が消えたら、タイムトライアルで増えた秒数を出し、カードのスコアを数え上げる
            Task { await trial.revealBonus() }
            await session.revealScore()
        }
    }

    // 演出をタップしたとき。まだスライドしていなければスライドさせて、すぐ演出を消す
    private func finishCelebration() {
        guard celebration != nil else { return }
        if !session.tutorialCleared { session.tutorialCleared = true }
        slideToNext()
        withAnimation(.easeOut(duration: 0.3)) { celebration = nil }
        Task { await trial.revealBonus() }
        Task { await session.revealScore() }
    }

    // 詰んだ問題の次へ。まだできていなければ作り置きを待つページへ。一度の演出で一度だけ進める
    private func slideToNext() {
        guard let c = celebration, !c.slid,
              let index = problems.firstIndex(where: { $0.key == c.problem.key }) else { return }
        celebration?.slid = true
        let next = index + 1 < problems.count ? problems[index + 1].key : "generating"
        withAnimation(.easeInOut(duration: 0.5)) { currentPage = next }
    }
}

struct GeneratingPage: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(Theme.neonCyan)
            Text("次の問題を作っています…").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeonBackdrop())
    }
}
