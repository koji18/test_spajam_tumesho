import SwiftUI

@main
struct TsumeshoApp: App {
    @State private var session = Session()
    @State private var trial = TimeTrial()

    /// 起動時に、同梱したフォントを登録する
    init() {
        Theme.registerFonts()
        Sound.prepare()
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

/// 最初の画面で盤の大きさを選んで始め、メニューの「ホーム」で最初の画面に戻る。
/// 作った問題は戻っても残しておく
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
            if playing && session.mode == .tutorial {
                TutorialView(startAt: session.tutorialNext) {
                    playing = false
                } onFinish: {
                    // 修了したらノーマルで実戦へ。1 問目を解いているあいだに、作り置きも始めておく
                    session.mode = .normal
                    feed.didShow(index: 0, size: session.boardSize)
                }
                .transition(.move(edge: .bottom))
            } else if playing && session.mode == .zen {
                PracticeView(problems: session.practice.problems(size: session.boardSize)) {
                    playing = false
                } onNormal: {
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
        .environment(tilt)
        .animation(.easeInOut(duration: 0.3), value: playing)
        // ホーム・入門・修行は明るい和紙の見た目なので、いつも明るい表示にする。暗くするのは、ネオンの問題画面だけ
        .preferredColorScheme(playing && session.mode != .tutorial && session.mode != .zen && session.tutorialCleared ? .dark : .light)
        .task(id: scenePhase == .active && !reduceMotion) {
            guard scenePhase == .active, !reduceMotion else { return }
            await tilt.run()
        }
        .onAppear(perform: applyDebugArguments)
        // BGM は遊んでいるあいだだけ。ホームとバックグラウンドでは止める
        .onChange(of: musicTrack, initial: true) { _, track in Music.play(track, volume: session.musicVolume) }
        .onChange(of: session.musicVolume) { _, volume in Music.play(musicTrack, volume: volume) }
    }

    // 普通の見た目のあいだ（初回の問題を詰ませる前）は、ノーマルとタイムトライアルの曲を流さない。
    // 詰ませてネオンに変わったところで、曲が流れ始める
    private var musicTrack: Music.Track? {
        guard playing, scenePhase == .active else { return nil }
        let disguised = (session.mode == .normal || session.mode == .timeTrial) && !session.tutorialCleared
        return disguised ? nil : Music.Track(mode: session.mode)
    }

    /// Debug ビルドだけ：起動オプションで最初の画面を飛ばす（シミュレーターで画面を確かめる用）。
    /// 例：-startPlaying -boardSize full -neon
    private func applyDebugArguments() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-boardSize"), i + 1 < args.count, let size = BoardSize(rawValue: args[i + 1]) {
            session.boardSize = size
        }
        if args.contains("-neon") { session.tutorialCleared = true }
        if args.contains("-startPlaying") {
            feed.didShow(index: 0, size: session.boardSize)
            playing = true
        }
        #endif
    }
}
