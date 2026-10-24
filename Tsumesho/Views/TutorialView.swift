import SwiftUI
import UIKit

// 入門チュートリアル。詰将棋の考え方を 7 段階で覚える。落ち着いた和紙の見た目で、
// 1 段ごとに「説明 → 解く → 解説」と進み、解けるたびに朱の印と星がつく。派手な演出はしない。
// 7 段は縦のスワイプでも、上の駒の印をタップしても、いつでも好きな段へ行き来できる
struct TutorialView: View {
    let startAt: Int
    let onHome: () -> Void
    let onFinish: () -> Void

    @Environment(Session.self) private var session
    @State private var current: Int?
    @State private var finished = false

    private let stages = TutorialStage.all

    init(startAt: Int, onHome: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.startAt = startAt
        self.onHome = onHome
        self.onFinish = onFinish
        _current = State(initialValue: 0)
    }

    private var index: Int { current ?? 0 }

    var body: some View {
        ZStack {
            PaperBackground()
            if finished {
                TutorialFinish(stages: stages, stars: session.tutorialStars, onFinish: onFinish, onRestart: restart)
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    header
                    pages
                }
            }
        }
        .environment(\.palette, .classic)
        .animation(.easeInOut(duration: 0.4), value: finished)
        // 開始位置は、最初のレイアウトのあとで指定し直さないとスクロールされない
        .task {
            let target = min(max(0, startAt), stages.count - 1)
            guard target > 0 else { return }
            try? await Task.sleep(for: .milliseconds(60))
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { current = target }
        }
    }

    // 縦に 7 段を並べ、1 段ずつ止めながらスクロールする
    private var pages: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { i, stage in
                    StagePage(stage: stage, total: stages.count,
                              previousStars: session.tutorialStars[i],
                              nextLabel: nextLabel(after: i),
                              onSolved: { earned in session.recordTutorial(stage: i, stars: earned) },
                              onNext: { auto in goNext(from: i, auto: auto) })
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $current)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        // スクロールの中身は下の安全領域の下にも続くので、はみ出して見える次の段の上端を切り落とす
        .clipped()
    }

    // MARK: 上の段

    private var header: some View {
        HStack {
            Button(action: onHome) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                    Text("ホーム").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Washi.inkSoft)
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<stages.count, id: \.self) { i in
                    pip(i)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // 駒の形の印。解いた段は朱、いまの段は墨の縁取り。タップでその段へ飛ぶ
    private func pip(_ i: Int) -> some View {
        let done = session.tutorialStars[i] > 0
        let isCurrent = i == index
        return Button {
            if session.hapticsOn { UISelectionFeedbackGenerator().selectionChanged() }
            withAnimation(.easeInOut(duration: 0.4)) { current = i }
        } label: {
            KomaShape()
                .fill(done ? Washi.vermilion : Color.clear)
                .overlay(KomaShape().stroke(isCurrent ? Washi.ink : Washi.kayaEdge.opacity(0.55), lineWidth: isCurrent ? 2 : 1))
                .frame(width: 15, height: 17)
                .scaleEffect(isCurrent ? 1.18 : 1)
                .padding(.horizontal, 3)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: done)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("第\(i + 1)段" + (done ? "、解いた" : ""))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    // MARK: 進行

    // 最後の段では、全部解けていれば「修了へ」、まだなら最初の未クリアの段へ戻る
    private func nextLabel(after i: Int) -> String {
        guard i == stages.count - 1 else { return "つぎの段へ" }
        return session.tutorialDone ? "修了へ" : "解いていない段へ"
    }

    // 解いた演出のあとの自動送りは、まだその段を見ているときだけ進める（途中で別の段へ動かしていたら進めない）
    private func goNext(from i: Int, auto: Bool) {
        if auto && index != i { return }
        if i + 1 < stages.count {
            withAnimation(.easeInOut(duration: 0.45)) { current = i + 1 }
        } else if session.tutorialDone {
            finished = true
        } else {
            withAnimation(.easeInOut(duration: 0.45)) { current = session.tutorialNext }
        }
    }

    private func restart() {
        current = 0
        finished = false
    }
}

// MARK: 1 段ぶんの画面

private struct StagePage: View {
    let stage: TutorialStage
    let total: Int
    let previousStars: Int
    let nextLabel: String
    let onSolved: (_ stars: Int) -> Void
    let onNext: (_ auto: Bool) -> Void

    @Environment(Session.self) private var session
    @State private var game: Game
    @State private var misses = 0
    @State private var cleared = false
    @State private var stampScale: CGFloat = 2.2
    @State private var stampOpacity = 0.0
    @State private var burstStart: Date?
    @State private var sealScale: CGFloat = 2.4
    @State private var sealOpacity = 0.0
    @State private var bump: CGFloat = 0
    @State private var advanceTask: Task<Void, Never>?

    init(stage: TutorialStage, total: Int, previousStars: Int, nextLabel: String,
         onSolved: @escaping (_ stars: Int) -> Void, onNext: @escaping (_ auto: Bool) -> Void) {
        self.stage = stage
        self.total = total
        self.previousStars = previousStars
        self.nextLabel = nextLabel
        self.onSolved = onSolved
        self.onNext = onNext
        _game = State(initialValue: Self.makeGame(stage.problem))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    titleBlock
                    lessonCard
                    boardWithEffect
                    statusLine
                    handRow
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            bottomBar
        }
        .onAppear { game.start() }
        // 成れる手を指したときの確認。ないと、第1段の歩・第2段の銀・第5段の桂馬が指せない
        .confirmationDialog("成りますか？", isPresented: promotionBinding, titleVisibility: .visible) {
            Button("成る") { game.choosePromotion(true) }
            Button("成らない") { game.choosePromotion(false) }
        }
        .onChange(of: game.status) { _, status in
            switch status {
            case .solved: solved()
            case .failed:
                misses += 1
                if session.hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.error) }
            default: break
            }
        }
        .sensoryFeedback(trigger: game.lastMove) { _, _ in session.hapticsOn ? .selection : nil }
        .animation(.spring(duration: 0.35), value: game.status)
    }

    private var promotionBinding: Binding<Bool> {
        Binding(get: { game.pendingPromotion != nil }, set: { if !$0 { game.pendingPromotion = nil } })
    }

    // 入門では、間違えてもすぐには答えを見せず、「答えを見る」を押したときだけ見せる
    private static func makeGame(_ problem: Problem) -> Game {
        let game = Game(problem: problem)
        game.answerOnDemand = true
        return game
    }

    // 星は、ミスもヒントもなければ 3、どちらかなら 2、両方なら 1
    private var earnedStars: Int {
        3 - (misses > 0 ? 1 : 0) - (game.hintsUsed > 0 ? 1 : 0)
    }

    private func solved() {
        if session.hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        withAnimation(.easeOut(duration: 0.2)) { cleared = true }
        stampOpacity = 1
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.15)) { stampScale = 1 }
        onSolved(earnedStars)
        celebrate()
        // 演出を見せてから、自動で次の段へ進む
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(for: .milliseconds(2300))
            guard !Task.isCancelled else { return }
            onNext(true)
        }
    }

    // 解けた瞬間の、少しだけ派手な演出。盤の上に朱の落款が押され、紙吹雪が舞う
    private func celebrate() {
        burstStart = Date()
        sealOpacity = 1
        sealScale = 2.4
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { sealScale = 1 }
        if session.hapticsOn { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
        Task {
            for value: CGFloat in [5, -2, 1, 0] {
                withAnimation(.easeOut(duration: 0.05)) { bump = value }
                try? await Task.sleep(for: .milliseconds(55))
            }
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeIn(duration: 0.3)) { sealOpacity = 0 }
        }
    }

    private var boardWithEffect: some View {
        BoardView(game: game)
            .offset(y: bump)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        MateBurst(start: burstStart, side: geo.size.width, light: true)
                        seal(side: geo.size.width)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .allowsHitTesting(false)
            }
    }

    private func seal(side: CGFloat) -> some View {
        let size = side * 0.36
        return ZStack {
            RoundedRectangle(cornerRadius: 7).fill(Washi.vermilion)
            RoundedRectangle(cornerRadius: 4).inset(by: 6).stroke(Washi.paper.opacity(0.8), lineWidth: 2)
            Text("詰")
                .font(Theme.brush(size * 0.7))
                .foregroundStyle(Washi.paper)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-9))
        .scaleEffect(sealScale)
        .opacity(sealOpacity)
        .shadow(color: Washi.vermilion.opacity(0.35), radius: 8, y: 4)
    }

    // もう一度、はじめから解く。前に解いた星は残る
    private func retry() {
        advanceTask?.cancel()
        game = Self.makeGame(stage.problem)
        game.start()
        burstStart = nil
        sealOpacity = 0
        misses = 0
        cleared = false
        stampOpacity = 0
        stampScale = 2.2
    }

    // MARK: 見出しと説明

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("第\(stage.number)段")
                    .font(Theme.koma(14))
                    .foregroundStyle(Washi.vermilion)
                Text("\(Theme.kanjiNumber(stage.problem.plies))手詰")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Washi.paper)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 2).fill(Washi.inkSoft))
                if previousStars > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < previousStars ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(i < previousStars ? Washi.vermilion : Washi.kayaEdge.opacity(0.45))
                        }
                    }
                    .accessibilityLabel("解いた。星\(previousStars)")
                }
            }
            Text(stage.title)
                .font(Theme.koma(30))
                .foregroundStyle(Washi.ink)
        }
    }

    private var lessonCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cleared ? "解説" : "ポイント")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(cleared ? Washi.vermilion : Washi.inkSoft)
            Text(cleared ? stage.review : stage.lesson)
                .font(.system(size: 14))
                .foregroundStyle(Washi.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if cleared { starRow }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 4).fill(Washi.paper.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Washi.kayaEdge.opacity(0.5), lineWidth: 1))
        .overlay(alignment: .topTrailing) { stamp }
    }

    private var starRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < earnedStars ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(i < earnedStars ? Washi.vermilion : Washi.kayaEdge.opacity(0.5))
            }
            Text(earnedStars == 3 ? "ノーミス！" : (game.hintsUsed > 0 ? "ヒントを使いました" : "ミスがありました"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Washi.inkSoft)
                .padding(.leading, 4)
        }
        .padding(.top, 4)
    }

    // 解けたときに押される朱の印。大げさにはせず、小さくポンと押す
    private var stamp: some View {
        Text("済")
            .font(Theme.koma(20))
            .foregroundStyle(Washi.paper)
            .frame(width: 38, height: 38)
            .background(RoundedRectangle(cornerRadius: 4).fill(Washi.vermilion))
            .rotationEffect(.degrees(-8))
            .scaleEffect(stampScale)
            .opacity(stampOpacity)
            .offset(x: -10, y: -14)
            .allowsHitTesting(false)
    }

    // MARK: 盤の下

    private var statusLine: some View {
        Group {
            if game.isNotCheckNotice || game.status.isFailed {
                // 下のカードに同じ知らせを出すので、ここでは出さない
                Text("")
            } else if let guide = game.guide {
                Label(guide, systemImage: "hand.point.up.left.fill").foregroundStyle(Washi.vermilion)
            } else {
                Text(game.message).foregroundStyle(game.message.hasPrefix("王手になって") ? Washi.vermilion : Washi.ink)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(2)
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .animation(.default, value: game.message)
    }

    private var handRow: some View {
        HStack(spacing: 12) {
            Text("持ち駒").font(.system(size: 13, weight: .semibold)).foregroundStyle(Washi.inkSoft)
            if game.hand.isEmpty {
                Text("なし").font(.system(size: 13)).foregroundStyle(Washi.inkSoft)
            }
            ForEach(game.hand) { item in
                handTile(item)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 52)
    }

    private func handTile(_ item: Game.HandItem) -> some View {
        let selected = game.selection == .hand(item.kind)
        let guiding = game.guideHandKind == item.kind
        let hinted = game.hintHandKinds.contains(item.kind)
        return Button {
            game.tap(hand: item.kind)
        } label: {
            KomaView(label: Notation.label(item.kind), size: 44, tone: .hand)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 6).fill(Washi.paper))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Washi.vermilion : Washi.kayaEdge.opacity(0.6), lineWidth: selected ? 2.5 : 1)
                )
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hint, lineWidth: hinted ? 3 : 0))
                .overlay {
                    if guiding {
                        RoundedRectangle(cornerRadius: 6).stroke(Washi.vermilion, lineWidth: 3)
                            .phaseAnimator([0.2, 1.0]) { ring, phase in ring.opacity(phase) } animation: { _ in .easeInOut(duration: 0.7) }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if item.count > 1 {
                        Text("×\(item.count)")
                            .font(Theme.number(11))
                            .foregroundStyle(Washi.paper)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Washi.inkSoft))
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("持ち駒の\(Notation.label(item.kind))" + (item.count > 1 ? "、\(item.count)枚" : ""))
    }

    // 間違えたとき（玉に逃げられた、王手になっていない）だけ、画面の下に出す。
    // どの段でも同じ形で、「答えを見る」を押すまで正解は出さない。「もう一度」で盤が戻って消える
    private func helpCard(failed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(helpTitle(failed: failed))
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Washi.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if failed || game.answerShown {
                    helpButton("もう一度", filled: true) { game.reset() }
                } else {
                    helpButton(game.hintLevel >= 2 ? "ヒント済み" : "ヒント", filled: true) { game.showHint() }
                        .disabled(game.hintLevel >= 2)
                }
                if !game.answerShown {
                    helpButton("答えを見る", filled: false) { game.showAnswer() }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 4).fill(Washi.paper.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Washi.vermilion.opacity(0.6), lineWidth: 1))
    }

    private func helpTitle(failed: Bool) -> String {
        if let text = game.answerText { return "正解は \(text)（盤の緑の枠）" }
        return failed ? "残念、玉に逃げられました" : "王手になっていません。王手をかけよう"
    }

    private func helpButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(filled ? Washi.paper : Washi.vermilion)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(RoundedRectangle(cornerRadius: 4).fill(filled ? Washi.vermilion : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Washi.vermilion, lineWidth: filled ? 0 : 1.5))
    }

    // MARK: 下のボタン

    @ViewBuilder
    private var bottomBar: some View {
        if cleared {
            VStack(spacing: 8) {
                Button {
                    if session.hapticsOn { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                    advanceTask?.cancel()
                    onNext(false)
                } label: {
                    Text(nextLabel)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Washi.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Washi.vermilion))
                }
                .buttonStyle(.plain)
                Button("もう一度解く", action: retry)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Washi.inkSoft)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if case .failed = game.status {
            // 間違えたときは、スクロールしなくても読んで押せるように、画面の下に固定して出す
            helpCard(failed: true)
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if game.isNotCheckNotice || (game.answerShown && game.status == .playing) {
            helpCard(failed: false)
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack(spacing: 28) {
                Button { game.showHint() } label: {
                    Label(game.hintLevel == 0 ? "ヒント" : (game.hintLevel == 1 ? "もう一段" : "ヒント済み"), systemImage: "lightbulb")
                }
                .disabled(game.hintLevel >= 2)
                Button { game.reset() } label: {
                    Label("やり直し", systemImage: "arrow.counterclockwise")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Washi.inkSoft)
            .padding(.vertical, 14)
        }
    }
}

// MARK: 修了

private struct TutorialFinish: View {
    let stages: [TutorialStage]
    let stars: [Int]
    let onFinish: () -> Void
    let onRestart: () -> Void

    @Environment(Session.self) private var session
    @State private var stampScale: CGFloat = 2.6
    @State private var stampOpacity = 0.0

    private var totalStars: Int { stars.reduce(0, +) }
    private var maxStars: Int { stages.count * 3 }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Washi.vermilion)
                RoundedRectangle(cornerRadius: 5).inset(by: 7).stroke(Washi.paper.opacity(0.8), lineWidth: 2)
                VStack(spacing: 0) {
                    Text("修").font(Theme.koma(46))
                    Text("了").font(Theme.koma(46))
                }
                .foregroundStyle(Washi.paper)
            }
            .frame(width: 128, height: 128)
            .rotationEffect(.degrees(-6))
            .scaleEffect(stampScale)
            .opacity(stampOpacity)
            .shadow(color: Washi.vermilion.opacity(0.3), radius: 8, y: 4)

            VStack(spacing: 6) {
                Text("チュートリアル 修了").font(Theme.koma(30)).foregroundStyle(Washi.ink)
                Text("王手・成り・読み・捨て駒。詰将棋の基本はこれで一通りです。")
                    .font(.system(size: 13)).foregroundStyle(Washi.inkSoft)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(Array(stages.enumerated()), id: \.offset) { i, stage in
                    HStack {
                        Text("第\(stage.number)段").font(Theme.koma(13)).foregroundStyle(Washi.vermilion)
                        Text(stage.title).font(.system(size: 14)).foregroundStyle(Washi.ink)
                        Spacer()
                        let earned = i < stars.count ? stars[i] : 0
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { k in
                                Image(systemName: k < earned ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundStyle(k < earned ? Washi.vermilion : Washi.kayaEdge.opacity(0.45))
                            }
                        }
                    }
                }
                Rectangle().fill(Washi.kayaEdge.opacity(0.4)).frame(height: 1).padding(.vertical, 2)
                HStack {
                    Text("星").font(.system(size: 13, weight: .bold)).foregroundStyle(Washi.inkSoft)
                    Spacer()
                    Text("\(totalStars) / \(maxStars)").font(Theme.number(18)).foregroundStyle(Washi.ink)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 4).fill(Washi.paper.opacity(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Washi.kayaEdge.opacity(0.5), lineWidth: 1))

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button(action: onFinish) {
                    Text("実戦へ")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Washi.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Washi.vermilion))
                }
                .buttonStyle(.plain)
                Button("もう一度やる", action: onRestart)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Washi.inkSoft)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .onAppear {
            stampOpacity = 1
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5).delay(0.25)) { stampScale = 1 }
            Task {
                try? await Task.sleep(for: .milliseconds(380))
                if session.hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
        }
    }
}
