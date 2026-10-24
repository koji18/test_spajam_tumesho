import SwiftUI

// 縦スワイプの 1 ページ。1 問ぶん
struct ProblemPage: View {
    let problem: Problem
    let insets: EdgeInsets
    let onExit: () -> Void
    @Environment(Session.self) private var session
    @State private var game: Game

    init(problem: Problem, insets: EdgeInsets, onExit: @escaping () -> Void) {
        self.problem = problem
        self.insets = insets
        self.onExit = onExit
        _game = State(initialValue: Game(problem: problem))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            VStack(alignment: .leading, spacing: 10) {
                Text(game.message)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(messageColor)
                if let guide = game.guide {
                    Label(guide, systemImage: "hand.point.up.left.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.hint)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.hint.opacity(0.14)))
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            .animation(.default, value: game.message)
            .animation(.default, value: game.guide)

            BoardView(game: game)

            handRow
            Spacer(minLength: 0)
            result
            footer
        }
        .padding(.horizontal, 20)
        .padding(.top, insets.top + 12)
        .padding(.bottom, insets.bottom + 12)
        .background(Theme.background)
        .confirmationDialog("成りますか？", isPresented: promotionBinding, titleVisibility: .visible) {
            Button("成る") { game.choosePromotion(true) }
            Button("成らない") { game.choosePromotion(false) }
        }
        .onChange(of: game.status) { _, status in
            switch status {
            case .solved: session.record(solved: true)
            case .failed: session.record(solved: false)
            default: break
            }
        }
        .sensoryFeedback(.selection, trigger: game.lastMove)
        .sensoryFeedback(trigger: game.status) { _, status in
            switch status {
            case .solved: .success
            case .failed: .error
            default: nil
            }
        }
    }

    private var promotionBinding: Binding<Bool> {
        Binding(get: { game.pendingPromotion != nil }, set: { if !$0 { game.pendingPromotion = nil } })
    }

    private var messageColor: Color {
        switch game.status {
        case .solved: Theme.ok
        case .failed: Theme.ng
        case .thinking: Theme.soft
        case .playing: game.message.hasPrefix("王手になって") ? Theme.hint : Theme.ink
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("\(problem.id)問目").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
            chip("\(problem.plies)手詰め", color: Theme.ink)
            chip(problem.size == .small ? "5×5" : "9×9", color: Theme.soft)
            Spacer()
            // 最初の画面に戻る。盤の大きさを選び直すときはここから
            Button(action: onExit) {
                Label("トップ", systemImage: "house")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .tint(Theme.ink)
            .accessibilityHint("最初の画面に戻ります。盤の大きさを選び直せます")
        }
    }

    private func isRevealedDrop(_ kind: Kind) -> Bool {
        guard let m = game.revealedAnswer else { return false }
        return m.from == nil && m.kind == kind
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Capsule().fill(Theme.surface))
            .foregroundStyle(color)
    }

    private var handRow: some View {
        HStack(spacing: 10) {
            Text("持ち駒").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.soft)
            if game.hand.isEmpty {
                Text("なし").font(.system(size: 13)).foregroundStyle(Theme.soft)
            }
            ForEach(game.hand) { item in
                Button {
                    game.tap(hand: item.kind)
                } label: {
                    HStack(spacing: 2) {
                        KomaView(label: Notation.label(item.kind), size: 44)
                        if item.count > 1 { Text("×\(item.count)").font(Theme.mono(12)).foregroundStyle(Theme.ink) }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(game.selection == .hand(item.kind) ? Theme.accent.opacity(0.85) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hint, lineWidth: game.hintHandKinds.contains(item.kind) ? 3 : 0)
                    )
                    .overlay(
                        // 間違えたときに見せる正解が、この持ち駒を打つ手のとき
                        RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.ok, lineWidth: isRevealedDrop(item.kind) ? 3 : 0)
                    )
                    .overlay {
                        // 1 問目の案内：タップしてほしい持ち駒を点滅させる
                        if game.guideHandKind == item.kind {
                            RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hint, lineWidth: 3)
                                .phaseAnimator([0.2, 1.0]) { ring, phase in
                                    ring.opacity(phase)
                                } animation: { _ in .easeInOut(duration: 0.7) }
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("持ち駒の\(Notation.label(item.kind))")
            }
            Spacer()
        }
        .frame(minHeight: 56)
    }

    @ViewBuilder
    private var result: some View {
        switch game.status {
        case .solved(let tesuji):
            VStack(alignment: .leading, spacing: 4) {
                Text("詰み！").font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.ok)
                if let tesuji {
                    Text("今の手には「\(tesuji)」という名前があります").font(.system(size: 15)).foregroundStyle(Theme.ink)
                }
                Text("上にスワイプで次の問題へ").font(.system(size: 13)).foregroundStyle(Theme.soft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ok.opacity(0.14)))
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        case .failed(let answer):
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("正解は \(answer)").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("盤の緑の枠が正解の駒と行き先です。もう一度か、上にスワイプで次へ").font(.system(size: 13)).foregroundStyle(Theme.soft)
                }
                Spacer()
                Button("もう一度") { game.reset() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ng.opacity(0.14)))
        default:
            EmptyView()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                game.showHint()
            } label: {
                Label(game.hintLevel == 0 ? "ヒント" : "ヒント \(game.hintLevel)/2", systemImage: "lightbulb")
            }
            .disabled(game.status != .playing || game.hintLevel >= 2)

            Button {
                game.reset()
            } label: {
                Label("盤面をリセット", systemImage: "arrow.counterclockwise")
            }

            Spacer()
            Text("連続 \(session.streak)")
                .font(Theme.mono(13))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(Theme.surface))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
                .animation(.spring, value: session.streak)
        }
        .font(.system(size: 14, weight: .semibold))
        .tint(Theme.ink)
        .buttonStyle(.bordered)
        .animation(.spring(duration: 0.35), value: game.status)
    }
}
