import SwiftUI

// 修行。ノーマルで間違えた問題を、入門と同じ和紙の見た目で、静かに解き直す。
// レーティング・スコア・連勝は変えず、時間制限・振動・全面の詰み演出もない。
// 問題はミスの多い順に縦に並べ、最後まで行ったら「もう一巡」できる
struct PracticeView: View {
    let onHome: () -> Void
    let onNormal: () -> Void

    @Environment(Session.self) private var session
    // 始めたときの並びで固定する。解いている途中にミスが足されても、問題や順番が入れ替わらないように
    @State private var problems: [Problem]
    @State private var current: Int? = 0
    @State private var round = 0

    init(problems: [Problem], onHome: @escaping () -> Void, onNormal: @escaping () -> Void) {
        self.onHome = onHome
        self.onNormal = onNormal
        _problems = State(initialValue: problems)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                header
                pages
            }
        }
        .environment(\.palette, .classic)
    }

    // 縦に問題を並べ、最後に「ひと巡り」のページを置く。一巡し直すときは、ページを作り直して盤を最初に戻す
    private var pages: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(problems.enumerated()), id: \.offset) { i, problem in
                    PracticePage(problem: problem, number: i + 1, total: problems.count) {
                        withAnimation(.easeInOut(duration: 0.35)) { current = i + 1 }
                    }
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(i)
                }
                PracticeEndPage(isEmpty: problems.isEmpty, size: session.boardSize,
                                onNormal: onNormal, onRepeat: repeatRound)
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(problems.count)
            }
            .scrollTargetLayout()
            .id(round)
        }
        .scrollPosition(id: $current)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
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
                .padding(.trailing, 16)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 6) {
                ForEach(BoardSize.allCases, id: \.self) { size in
                    sizeTab(size)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // 盤の大きさの札。選び直したら、その大きさで間違えた問題に並べ直す
    private func sizeTab(_ size: BoardSize) -> some View {
        let selected = session.boardSize == size
        return Button {
            guard !selected else { return }
            Sound.playPick(volume: session.soundVolume)
            session.boardSize = size
            problems = session.practice.problems(size: size)
            round += 1
            current = 0
        } label: {
            FudaTag(text: size.displayLabel, selected: selected, fontSize: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("盤のサイズ \(size.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func repeatRound() {
        round += 1
        current = 0
    }
}

// MARK: 1 問ぶん

private struct PracticePage: View {
    let problem: Problem
    let number: Int
    let total: Int
    let onNext: () -> Void

    @State private var game: Game

    init(problem: Problem, number: Int, total: Int, onNext: @escaping () -> Void) {
        self.problem = problem
        self.number = number
        self.total = total
        self.onNext = onNext
        _game = State(initialValue: Game(problem: problem))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    titleBlock
                    BoardView(game: game)
                    statusLine
                    WashiHandRow(game: game)
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
        .confirmationDialog("成りますか？", isPresented: promotionBinding, titleVisibility: .visible) {
            Button("成る") { game.choosePromotion(true) }
            Button("成らない") { game.choosePromotion(false) }
        }
    }

    private var promotionBinding: Binding<Bool> {
        Binding(get: { game.pendingPromotion != nil }, set: { if !$0 { game.pendingPromotion = nil } })
    }

    private var titleBlock: some View {
        HStack(spacing: 8) {
            Text("\(number) / \(total)")
                .font(Theme.koma(14))
                .foregroundStyle(Washi.vermilion)
            Text("\(Theme.kanjiNumber(problem.plies))手詰")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Washi.paper)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 2).fill(Washi.inkSoft))
        }
        .accessibilityElement(children: .combine)
    }

    // 詰ませたら「詰み！」を控えめに出す。間違えたときは、玉方がどう防いだかの説明を出す
    private var statusLine: some View {
        Group {
            if case .solved = game.status {
                PracticeMateMessage()
            } else if let guide = game.guide {
                Label(guide, systemImage: "hand.point.up.left.fill").foregroundStyle(Washi.vermilion)
            } else {
                Text(game.message)
                    .foregroundStyle(game.status.isFailed || game.isNotCheckNotice ? Washi.vermilion : Washi.ink)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
    }

    // MARK: 下のボタン

    @ViewBuilder
    private var bottomBar: some View {
        if case .solved = game.status {
            VStack(spacing: 8) {
                washiButton("次の一問", filled: true, action: onNext)
                Button { game.reset() } label: {
                    Text("もう一度解く")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Washi.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        } else if game.status.isFailed {
            // 間違えたら、盤に正解の手（緑）と玉方の防ぎ方を出したまま、解き直せるようにする
            washiButton("もう一度", filled: true) { game.reset() }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
        } else {
            HStack(spacing: 0) {
                Button { game.showHint() } label: {
                    Label(game.hintLevel == 0 ? "ヒント" : (game.hintLevel == 1 ? "もう一段" : "ヒント済み"), systemImage: "lightbulb")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(game.hintLevel >= 2)
                Button { game.reset() } label: {
                    Label("やり直し", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Washi.inkSoft)
            .padding(.horizontal, 24)
        }
    }
}

// 朱で塗ったボタンと、朱の枠だけのボタン（入門の「もう一度」「答えを見る」と同じ形）
private func washiButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(filled ? Washi.paper : Washi.vermilion)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 4).fill(filled ? Washi.vermilion : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Washi.vermilion, lineWidth: filled ? 0 : 1.5))
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}

// MARK: 詰みの一言とひと巡りのページ

// 詰んだときの「詰み！」。一度だけ朱で少し持ち上がり、墨色に落ち着く。リセットして解き直したときも、もう一度動く
private struct PracticeMateMessage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        Text("詰み！")
            .font(Theme.koma(22))
            .foregroundStyle(settled ? Washi.ink : Washi.vermilion)
            .scaleEffect(settled || reduceMotion ? 1 : 1.08, anchor: .leading)
            .offset(y: settled || reduceMotion ? 0 : 3)
            .task {
                do {
                    try await Task.sleep(for: .milliseconds(150))
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) { settled = true }
                } catch { }
            }
    }
}

// 最後の問題の次のページ。間違えた問題がまだないときは、ノーマルで遊ぶと溜まることを伝える
private struct PracticeEndPage: View {
    let isEmpty: Bool
    let size: BoardSize
    let onNormal: () -> Void
    let onRepeat: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf")
                .font(.system(size: 30))
                .foregroundStyle(Washi.inkSoft)
            Text(isEmpty ? "修行する問題は、これから。" : "ひと巡り、おつかれさまでした。")
                .font(Theme.koma(23))
                .foregroundStyle(Washi.ink)
                .multilineTextAlignment(.center)
            Text(isEmpty
                 ? "\(size.label)で間違えた問題はまだありません。\nノーマルで間違えた問題が、ここに残ります。\n上の札で、ほかの盤の大きさも選べます。"
                 : "同じ問題を、もう一度くり返すこともできます。\n自分のペースで続けましょう。")
                .font(.system(size: 14))
                .foregroundStyle(Washi.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            VStack(spacing: 10) {
                if !isEmpty {
                    washiButton("もう一巡する", filled: true, action: onRepeat)
                }
                washiButton("ノーマルへ", filled: false, action: onNormal)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
