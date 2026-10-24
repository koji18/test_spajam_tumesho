import SwiftUI

/// 縦スワイプの 1 ページ。1 問ぶん。上のバー（モードとメニュー）は FeedView が画面の上に固定して出す
struct ProblemPage: View {
    let problem: Problem
    let insets: EdgeInsets
    let onSolved: (_ seconds: Int, _ tesuji: String?) -> Void
    @Environment(Session.self) private var session
    @Environment(TimeTrial.self) private var trial
    @Environment(\.palette) private var palette
    @Environment(\.pageLayout) private var layout
    @State private var game: Game

    /// 1 問ぶんのページを作る。詰んだら onSolved に解いた秒数と手筋の名前を渡す
    init(problem: Problem, insets: EdgeInsets, onSolved: @escaping (_ seconds: Int, _ tesuji: String?) -> Void) {
        self.problem = problem
        self.insets = insets
        self.onSolved = onSolved
        _game = State(initialValue: Game(problem: problem))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            modeRow
            titleRow
            // 盤は残った高さに収まる大きさになるので、盤より下の部品は高さを変えない
            BoardView(game: game)
            statusLine
            handRow
            Spacer(minLength: 0)
            // 間違えたときは、レーティングのカードの場所に正解のカードを出す
            Group {
                if case .failed(let answer) = game.status {
                    failCard(answer)
                } else {
                    RatingCard()
                }
            }
            .frame(height: layout.cardHeight)
            controls
        }
        .padding(.horizontal, 20)
        .padding(.top, insets.top + layout.topBarHeight + (layout.compact ? 4 : 8))
        .padding(.bottom, insets.bottom + 6)
        .background(NeonBackdrop())
        .confirmationDialog("成りますか？", isPresented: promotionBinding, titleVisibility: .visible) {
            Button("成る") { game.choosePromotion(true) }
            Button("成らない") { game.choosePromotion(false) }
        }
        .onAppear { game.start() }
        .onChange(of: game.status) { _, status in
            switch status {
            case .solved(let tesuji):
                trial.recordSolve(plies: problem.plies, hintsUsed: game.hintsUsed)
                // スコアは裏で累計に足し、演出が消えてからカードで数え上げる
                session.recordSolve(plies: problem.plies, size: problem.size,
                                    seconds: game.solvedSeconds, hintsUsed: game.hintsUsed)
                // 詰み演出と振動は、問題の列の上のレイヤーで出す（FeedView）
                onSolved(game.solvedSeconds, tesuji)
            case .failed:
                session.recordMiss()
                trial.recordMiss()
            default:
                break
            }
        }
        .sensoryFeedback(trigger: game.lastMove) { _, _ in session.hapticsOn ? .selection : nil }
        // 間違えたとき（王手でない手も含む）。盤の揺れに合わせて鳴らす
        .sensoryFeedback(trigger: game.mistakes) { _, _ in session.hapticsOn ? .error : nil }
        .animation(.spring(duration: 0.35), value: game.status)
    }

    private var promotionBinding: Binding<Bool> {
        Binding(get: { game.pendingPromotion != nil }, set: { if !$0 { game.pendingPromotion = nil } })
    }

    // MARK: 見出し

    private var modeRow: some View {
        HStack {
            Text("[ \(session.mode.title) ]")
                .font(Theme.display(14))
                .tracking(2)
                .foregroundStyle(palette.accent)
            Spacer()
            Text(problem.size.displayLabel)
                .font(Theme.number(14))
                .foregroundStyle(palette.subText)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Theme.kanjiNumber(problem.plies))手詰")
                    .font(.system(size: layout.title, weight: .heavy))
                    .foregroundStyle(palette.text)
                Text("第\(problem.id)問 ・ 攻め方 先手")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.subText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if trial.isRunning {
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        let left = trial.remaining(at: context.date)
                        /// 残り 10 秒を切ったら赤く点滅させる
                        let urgent = left < 10
                        let blinkOff = urgent && Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                        Text(TimeTrial.format(left))
                            .font(Theme.number(layout.counter, weight: .black))
                            .monospacedDigit()
                            .foregroundStyle(urgent ? Color.red : palette.counter)
                            .shadow(color: (urgent ? Color.red : Theme.neonPink).opacity(0.8 * palette.glow), radius: 8)
                            .opacity(blinkOff ? 0.35 : 1)
                    }
                    .overlay(alignment: .leading) {
                        // 正解で増えた秒数、間違いで減った秒数
                        if let popup = trial.popup {
                            Text(verbatim: popup.seconds > 0 ? "+\(popup.seconds)s" : "\(popup.seconds)s")
                                .font(Theme.number(18, weight: .heavy))
                                .foregroundStyle(popup.seconds > 0 ? palette.accent : Color.red)
                                .shadow(color: (popup.seconds > 0 ? Theme.goldGlow : Color.red).opacity(palette.glow), radius: 8)
                                .fixedSize()
                                .offset(x: -64)
                                .id(popup.id)
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                        removal: .move(edge: .top).combined(with: .opacity)))
                        }
                    }
                    .animation(.spring(duration: 0.4), value: trial.popup)
                    Text("\(game.currentPly) / \(problem.plies) 手目")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.subText)
                } else {
                    Text("\(game.currentPly)/\(problem.plies)")
                        .font(Theme.number(layout.counter, weight: .black))
                        .foregroundStyle(palette.counter)
                        .shadow(color: Theme.neonPink.opacity(0.8 * palette.glow), radius: 8)
                    Text("手目")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.subText)
                }
            }
        }
    }

    // MARK: 盤の下

    /// 1 問目の案内か、遊んでいる途中の知らせ（王手になっていない、玉方の応手など）
    private var statusLine: some View {
        Group {
            if let guide = game.guide {
                Label(guide, systemImage: "hand.point.up.left.fill").foregroundStyle(palette.plain ? Theme.hint : Theme.goldGlow)
            } else {
                Text(game.message).foregroundStyle(messageColor)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        // 1 行に固定する。長い文は文字を小さくして収める（2 行になると盤が縮むため）
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20, alignment: .leading)
        .animation(.default, value: game.message)
    }

    private var messageColor: Color {
        switch game.status {
        case .failed: Theme.neonPink
        case .thinking: palette.subText
        default: game.message.hasPrefix("王手になって") ? Theme.hint : palette.text
        }
    }

    private var handRow: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("持ち駒").font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.subText)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    if game.hand.isEmpty {
                        Text("なし").font(.system(size: 14)).foregroundStyle(palette.subText)
                    }
                    ForEach(game.hand) { item in
                        handTile(item)
                    }
                }
                // いつも場所を取っておき、持ち駒を選んでいるときだけ見せる（出し入れで盤が縮まないように）
                Text("選択中 ・ 空きマスに打つ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .opacity(isHandSelected ? 1 : 0)
                    .accessibilityHidden(!isHandSelected)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: layout.handRowHeight)
    }

    /// 持ち駒の 1 枚ぶんのタイル
    private func handTile(_ item: Game.HandItem) -> some View {
        let selected = game.selection == .hand(item.kind)
        return Button {
            game.tap(hand: item.kind)
        } label: {
            // 選んだ持ち駒は少し大きくして浮かせる
            KomaView(label: Notation.label(item.kind), size: layout.handPiece, tone: .hand)
                .scaleEffect(selected ? 1.1 : 1)
                .offset(y: selected ? -3 : 0)
                .animation(.spring(duration: 0.25, bounce: 0.45), value: selected)
                .frame(width: layout.handTile, height: layout.handTile)
                .background(RoundedRectangle(cornerRadius: 12).fill(palette.panel))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(palette.accent.opacity(selected ? 1 : 0.45), lineWidth: selected ? 2 : 1)
                )
                .shadow(color: Theme.goldGlow.opacity(selected ? 0.7 * palette.glow : 0), radius: 10)
                .overlay(alignment: .topTrailing) {
                    if item.count > 1 {
                        Text("x\(item.count)")
                            .font(Theme.number(11))
                            .foregroundStyle(palette.text)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(palette.panel))
                            .offset(x: 8, y: -8)
                    }
                }
                // ヒントで光らせるとき
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hint, lineWidth: game.hintHandKinds.contains(item.kind) ? 3 : 0))
                // 間違えたときに見せる正解が、この持ち駒を打つ手のとき
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ok, lineWidth: isRevealedDrop(item.kind) ? 3 : 0))
                .overlay {
                    // 1 問目の案内：タップしてほしい持ち駒を点滅させる
                    if game.guideHandKind == item.kind {
                        RoundedRectangle(cornerRadius: 12).strokeBorder(palette.plain ? Theme.hint : Theme.goldGlow, lineWidth: 3)
                            .phaseAnimator([0.2, 1.0]) { ring, phase in
                                ring.opacity(phase)
                            } animation: { _ in .easeInOut(duration: 0.7) }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("持ち駒の\(Notation.label(item.kind))" + (item.count > 1 ? "、\(item.count)枚" : ""))
    }

    /// 持ち駒を選んでいるか
    private var isHandSelected: Bool {
        if case .hand = game.selection { return true }
        return false
    }

    /// 間違えたときに見せる正解が、kind の持ち駒を打つ手か
    private func isRevealedDrop(_ kind: Kind) -> Bool {
        guard let m = game.revealedAnswer else { return false }
        return m.from == nil && m.kind == kind
    }

    /// 間違えたときに出す、正解とやり直しのカード
    private func failCard(_ answer: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("正解は \(answer)").font(.system(size: 16, weight: .bold)).foregroundStyle(palette.text)
                Text("盤の緑の枠が正解の駒と行き先です").font(.system(size: 12)).foregroundStyle(palette.subText)
            }
            Spacer()
            Button("もう一度") { game.reset() }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.neonPink)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .overlay(Capsule().stroke(Theme.neonPink, lineWidth: 1.5))
        }
        .padding(.horizontal, 14).padding(.vertical, layout.compact ? 8 : 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.panel.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.neonPink.opacity(0.6), lineWidth: 1))
        .shadow(color: Theme.neonPink.opacity(0.3 * palette.glow), radius: 10)
    }

    // MARK: 下のボタン

    private var controls: some View {
        HStack(spacing: 56) {
            CircleButton(systemImage: "lightbulb", color: palette.hintButton, glow: false, size: layout.circleButton) {
                game.showHint()
            }
            .overlay(alignment: .topTrailing) {
                if game.hintLevel > 0 {
                    Text("\(game.hintLevel)/2")
                        .font(Theme.number(10))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.hint))
                }
            }
            .disabled(game.status != .playing || game.hintLevel >= 2)
            .accessibilityLabel(game.hintLevel == 0 ? "ヒント" : "ヒント、\(game.hintLevel)回目まで使用")

            CircleButton(systemImage: "arrow.counterclockwise", color: palette.resetButton, glow: !palette.plain,
                         size: layout.circleButton) {
                game.reset()
            }
            .accessibilityLabel("盤面をリセット")
        }
        .frame(maxWidth: .infinity)
    }
}

/// レーティングと連勝数のカード
struct RatingCard: View {
    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette
    @Environment(\.pageLayout) private var layout

    var body: some View {
        /// 連勝の目盛りは 5 つ。5 連勝ごとに一周する
        let filled = session.streak == 0 ? 0 : (session.streak - 1) % 5 + 1
        HStack(spacing: 14) {
            Text(session.rankBadge)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(palette.text)
                .frame(width: layout.badge, height: layout.badge)
                .background(Circle().fill(palette.panel))
                .overlay(Circle().stroke(palette.badgeStroke, lineWidth: 1.5))
                .shadow(color: Theme.neonCyan.opacity(0.6 * palette.glow), radius: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text("RATING").font(Theme.display(11, weight: .medium)).tracking(2).foregroundStyle(palette.subText)
                Text(verbatim: "\(session.rating)")
                    .font(Theme.number(layout.rating, weight: .black))
                    .foregroundStyle(palette.rating)
                    .shadow(color: Theme.neonCyan.opacity(0.8 * palette.glow), radius: 8)
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("SCORE").font(Theme.display(11, weight: .medium)).tracking(2).foregroundStyle(palette.subText)
                Text(verbatim: "\(session.displayedScore)")
                    .font(Theme.number(layout.score, weight: .black))
                    .foregroundStyle(palette.accent)
                    .shadow(color: Theme.goldGlow.opacity(0.7 * palette.glow), radius: 6)
                    .overlay(alignment: .topLeading) {
                        // 数え上げている間だけ、得た点を浮かべる
                        if let popup = session.scorePopup {
                            Text(verbatim: "+\(popup)")
                                .font(Theme.number(15, weight: .heavy))
                                .foregroundStyle(palette.accent)
                                .shadow(color: Theme.goldGlow.opacity(palette.glow), radius: 8)
                                .fixedSize()
                                .offset(x: -8, y: -20)
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                        removal: .move(edge: .top).combined(with: .opacity)))
                        }
                    }
                    .animation(.spring(duration: 0.4), value: session.scorePopup)
                HStack(spacing: 6) {
                    Text("\(session.streak)連勝")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                        .fixedSize()
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Capsule()
                                .fill(i < filled ? palette.accent : palette.text.opacity(0.15))
                                .frame(width: 10, height: 5)
                        }
                    }
                    // 次に解いたときにかかる連勝の倍率
                    Text(ScoreGain.format(session.nextStreakMultiplier))
                        .font(Theme.number(11))
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, layout.cardPadding)
        .background(RoundedRectangle(cornerRadius: 18).fill(palette.panel.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.panelStroke, lineWidth: 1))
        .animation(.spring, value: session.rating)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.rankName)、レーティング\(session.rating)、スコア\(session.totalScore)、\(session.streak)連勝中")
    }
}

/// 丸い枠のボタン
struct CircleButton: View {
    let systemImage: String
    let color: Color
    let glow: Bool
    var size: CGFloat = 60
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .regular))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Circle().fill(palette.panel.opacity(0.7)))
                .overlay(Circle().stroke(color.opacity(glow ? 1 : 0.7), lineWidth: 1.5))
                .shadow(color: color.opacity(glow ? 0.7 : 0), radius: 10)
        }
        .buttonStyle(.plain)
    }
}

/// 画面の背景。ネオンの見た目では、上にピンク、下にシアンのぼんやりした光を置く
struct NeonBackdrop: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.background
            if !palette.plain {
                RadialGradient(colors: [Theme.neonPink.opacity(0.22), .clear], center: .topTrailing, startRadius: 0, endRadius: 460)
                RadialGradient(colors: [Theme.neonCyan.opacity(0.2), .clear], center: .bottomLeading, startRadius: 0, endRadius: 460)
            }
        }
        .ignoresSafeArea()
    }
}
