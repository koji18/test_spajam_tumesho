import SwiftUI

@main
struct TsumeshoApp: App {
    @State private var session = Session()
    @State private var trial = TimeTrial()

    init() {
        Theme.registerFonts()
        NativeFeedback.prepare()
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

// 最初の画面で盤の大きさを選んで始め、メニューの「ホーム」で最初の画面に戻る。
// 作った問題は戻っても残しておく
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(TimeTrial.self) private var trial
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt = TiltMotion()
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
        .environment(tilt)
        .animation(.easeInOut(duration: 0.3), value: playing)
        .task(id: scenePhase == .active && !reduceMotion) {
            guard scenePhase == .active, !reduceMotion else { return }
            await tilt.run()
        }
    }
}

// 問題を縦に並べ、ショート動画のように 1 問ずつスワイプで送る。
// 1 問目の例題のあとは、裏で作った問題が続く。上のバーとメニュー、詰み演出は列の上のレイヤーに出す
struct FeedView: View {
    let feed: ProblemFeed
    let onHome: () -> Void

    @Environment(Session.self) private var session
    @Environment(TimeTrial.self) private var trial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    // 今見ているページ。問題は problem.key、作り置きを待つページは "generating"
    @State private var currentPage: String?
    // 盤のサイズを切り替えたとき、前に見ていたページに戻るために覚えておく
    @State private var lastPage: [BoardSize: String] = [:]
    @State private var celebration: Celebration?
    @State private var menuOpen = false
    @State private var showRecords = false
    @State private var showSettings = false
    @State private var settling = false
    @State private var rankCelebration: SolveReward?
    @State private var scoreFlight: ScoreFlight?
    @State private var celebrationTask: Task<Void, Never>?
    @State private var scoreTask: Task<Void, Never>?

    struct Celebration: Identifiable {
        let id = UUID()
        let problem: Problem
        let seconds: Int
        let tesuji: String?
        let reward: SolveReward
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
                            ProblemPage(problem: problem, insets: geo.safeAreaInsets) { seconds, tesuji, reward in
                                celebrate(problem, seconds: seconds, tesuji: tesuji, reward: reward)
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
                .scrollDisabled(settling || celebration != nil || rankCelebration != nil)
                .allowsHitTesting(!settling && celebration == nil && rankCelebration == nil)
                .ignoresSafeArea()
                .blur(radius: menuOpen ? 10 : 0)

                TopBar(insets: geo.safeAreaInsets, menuOpen: menuOpen) {
                    withAnimation(.spring(duration: 0.3)) { menuOpen.toggle() }
                }
                .disabled(settling || celebration != nil || rankCelebration != nil)

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
                    MateEffectView(plies: c.problem.plies, seconds: c.seconds, tesuji: c.tesuji, seed: c.problem.id, reward: c.reward) {
                        finishCelebration()
                    }
                    .id(c.id)
                    .transition(.opacity)
                    .zIndex(3)
                }

                if let reward = rankCelebration {
                    RankUpView(reward: reward)
                        .transition(.opacity)
                        .zIndex(3.5)
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
            .overlayPreferenceValue(ScoreTargetKey.self) { anchors in
                GeometryReader { overlay in
                    if let scoreFlight, let anchor = anchors[currentPage ?? ""] {
                        let target = overlay[anchor]
                        ScoreFlightView(flight: scoreFlight,
                                        origin: CGPoint(x: overlay.size.width / 2, y: overlay.size.height * MateEffectView.centerRatio),
                                        target: CGPoint(x: target.midX, y: target.midY))
                    }
                }
                .allowsHitTesting(false)
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
            while trial.isRunning && !Task.isCancelled {
                if trial.remaining() <= 0 {
                    trial.finish()
                    session.recordTimeTrial(solved: trial.solved)
                    break
                }
                do { try await Task.sleep(for: .milliseconds(250)) } catch { break }
            }
        }
        .sheet(isPresented: $showRecords) { RecordsView() }
        .sheet(isPresented: $showSettings) {
            SettingsView { showSettings = false; onHome() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { NativeFeedback.stop() }
        }
        .onDisappear {
            celebrationTask?.cancel()
            scoreTask?.cancel()
            NativeFeedback.stop()
            session.settleScore()
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
    private func celebrate(_ problem: Problem, seconds: Int, tesuji: String?, reward: SolveReward) {
        celebrationTask?.cancel()
        scoreTask?.cancel()
        scoreFlight = nil
        let c = Celebration(problem: problem, seconds: seconds, tesuji: tesuji, reward: reward)
        settling = true
        celebrationTask = Task { @MainActor in
            do {
                // 着地と盤面の波紋を見せてから、全面の詰み演出へつなぐ。
                try await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 620))
                settling = false
                NativeFeedback.play(.mate(reward.streak), sound: session.soundOn, haptics: session.hapticsOn)
                withAnimation(.easeOut(duration: 0.15)) { celebration = c }
                try await Task.sleep(for: .seconds(0.9))
                guard celebration?.id == c.id else { return }
                // 初回のチュートリアルを詰ませたら、演出の裏で普通の見た目からネオンの見た目に切り替える
                if !session.tutorialCleared {
                    withAnimation(.easeInOut(duration: 0.6)) { session.tutorialCleared = true }
                }
                slideToNext()
                try await Task.sleep(for: .seconds(1.3))
                guard celebration?.id == c.id else { return }
                finishCelebration()
            } catch { }
        }
    }

    // 演出をタップしたとき。まだスライドしていなければスライドさせて、すぐ演出を消す
    private func finishCelebration() {
        guard let c = celebration else { return }
        celebrationTask?.cancel()
        if !session.tutorialCleared { session.tutorialCleared = true }
        slideToNext()
        withAnimation(.easeOut(duration: 0.3)) { celebration = nil }
        settling = true
        scoreTask?.cancel()
        scoreTask = Task { @MainActor in
            do {
                // タップで即送りした場合も、スコアの着地点が止まるまで待つ。
                try await Task.sleep(for: .milliseconds(550))
                if c.reward.rankedUp {
                    withAnimation(.easeOut(duration: 0.2)) { rankCelebration = c.reward }
                    NativeFeedback.play(.rankUp, sound: session.soundOn, haptics: session.hapticsOn)
                    try await Task.sleep(for: .milliseconds(1400))
                    withAnimation(.easeOut(duration: 0.2)) { rankCelebration = nil }
                }
                settling = false
                scoreFlight = ScoreFlight()
                try await Task.sleep(for: .milliseconds(450))
                NativeFeedback.play(.score, sound: session.soundOn, haptics: session.hapticsOn)
                async let bonus: Void = trial.revealBonus()
                await session.revealScore()
                await bonus
                scoreFlight = nil
            } catch { }
        }
    }

    // 詰んだ問題の次へ。まだできていなければ作り置きを待つページへ。一度の演出で一度だけ進める
    private func slideToNext() {
        guard let c = celebration, !c.slid,
              let index = problems.firstIndex(where: { $0.key == c.problem.key }) else { return }
        celebration?.slid = true
        let next = index + 1 < problems.count ? problems[index + 1].key : "generating"
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) { currentPage = next }
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
