import SwiftUI
import UIKit

// 遊び方。ホームの木札から開くシート。横にめくる 6 枚の絵解きカードで、
// 1 枚ごとに小さな盤が動いて、やることを見せる。落ち着いた和紙の見た目で、文字は少なめにする
struct RulesSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private static let cards: [RuleCard] = [
        RuleCard(title: "玉を逃げられなくする", text: "相手の玉が、どこへも逃げられなくなったら勝ち。これを「詰み」といいます。駒の動き方は、覚えなくて大丈夫です。"),
        RuleCard(title: "毎回「王手」をかける", text: "王手は、次に玉を取れる形にすること。詰将棋では王手しか指せません。持ち駒は、空いているマスに打てます。"),
        RuleCard(title: "駒をタップすると光る", text: "盤の駒をタップすると、動けるマスが光ります。光ったマスをタップすると、そこへ指せます。"),
        RuleCard(title: "迷ったら「ヒント」", text: "1回目で、王手をかけられる駒が光ります。もう一度押すと、正解の駒と行き先が光ります。"),
        RuleCard(title: "連勝すると得点が伸びる", text: "続けて解くほど、得点の倍率が上がります（最大3倍）。速く、ヒントなしで解くと、さらに高得点です。"),
        RuleCard(title: "3つのモード", text: "はじめてなら「チュートリアル」。慣れたら、自分のペースの「ノーマル」か、60秒勝負の「タイム」へ。"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                ForEach(Array(Self.cards.enumerated()), id: \.offset) { i, card in
                    RulePage(number: i + 1, card: card)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(PaperBackground())
        .environment(\.palette, .classic)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: page) { _, _ in
            if session.hapticsOn { UISelectionFeedbackGenerator().selectionChanged() }
        }
    }

    private var header: some View {
        HStack {
            Text("遊び方").font(Theme.koma(26)).foregroundStyle(Washi.ink)
            Spacer()
            Button { dismiss() } label: {
                Text("閉じる")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Washi.inkSoft)
                    .padding(.horizontal, 6)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }

    // 下の段。進み具合を駒の形で出し、大きなボタンで次へ進む
    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<Self.cards.count, id: \.self) { i in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { page = i }
                    } label: {
                        KomaShape()
                            .fill(i == page ? Washi.vermilion : Color.clear)
                            .overlay(KomaShape().stroke(i == page ? Washi.vermilion : Washi.kayaEdge.opacity(0.6), lineWidth: 1))
                            .frame(width: 13, height: 15)
                            .scaleEffect(i == page ? 1.2 : 1)
                            .padding(5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(i + 1)枚目")
                }
            }
            Button {
                if session.hapticsOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                if page < Self.cards.count - 1 {
                    withAnimation(.easeInOut(duration: 0.35)) { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page < Self.cards.count - 1 ? "つぎへ" : "はじめる")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Washi.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Washi.vermilion))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
        .padding(.top, 6)
        .padding(.bottom, 18)
    }
}

private struct RuleCard {
    let title: String
    let text: String
}

// 1 枚ぶん。朱の印に入れた漢数字、見出し、絵、説明の順に並べ、縦の真ん中に寄せる。
// 小さい画面で収まらないときだけ、縦にスクロールできる
private struct RulePage: View {
    let number: Int
    let card: RuleCard

    private static let numerals = ["一", "二", "三", "四", "五", "六"]

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content
                    .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Text(Self.numerals[number - 1])
                    .font(Theme.koma(28))
                    .foregroundStyle(Washi.paper)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Washi.vermilion))
                    .rotationEffect(.degrees(-4))
                Text(card.title)
                    .font(Theme.koma(23))
                    .foregroundStyle(Washi.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            RuleIllustration(index: number - 1)
                .frame(maxWidth: .infinity)
            Text(card.text)
                .font(.system(size: 16))
                .foregroundStyle(Washi.ink)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }
}

// MARK: 絵

// 小さな盤。5 筋 × 4 段の木の盤で、駒や印は cell の大きさに合わせて重ねる
private struct MiniBoard<Content: View>: View {
    static var cols: Int { 5 }
    static var rows: Int { 4 }
    let cell: CGFloat
    @ViewBuilder let content: () -> Content

    var width: CGFloat { cell * CGFloat(Self.cols) + 16 }
    var height: CGFloat { cell * CGFloat(Self.rows) + 16 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5).fill(Washi.kayaSide).offset(y: 5)
            RoundedRectangle(cornerRadius: 5).fill(Washi.kaya)
            Path { p in
                for c in 0...Self.cols {
                    p.move(to: CGPoint(x: 8 + cell * CGFloat(c), y: 8))
                    p.addLine(to: CGPoint(x: 8 + cell * CGFloat(c), y: 8 + cell * CGFloat(Self.rows)))
                }
                for r in 0...Self.rows {
                    p.move(to: CGPoint(x: 8, y: 8 + cell * CGFloat(r)))
                    p.addLine(to: CGPoint(x: 8 + cell * CGFloat(Self.cols), y: 8 + cell * CGFloat(r)))
                }
            }
            .stroke(Washi.ink.opacity(0.8), lineWidth: 1)
            content()
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 8)
    }

    func center(_ col: Int, _ row: Int) -> CGPoint {
        CGPoint(x: 8 + cell * (CGFloat(col) + 0.5), y: 8 + cell * (CGFloat(row) + 0.5))
    }
}

private func koma(_ label: String, upsideDown: Bool = false, size: CGFloat) -> some View {
    KomaView(label: label, upsideDown: upsideDown, size: size)
        .environment(\.palette, .classic)
        .shadow(color: .black.opacity(0.35), radius: 2, x: 1, y: 3)
}

private struct RuleIllustration: View {
    let index: Int

    var body: some View {
        switch index {
        case 0: GoalIllustration()
        case 1: CheckIllustration()
        case 2: TapIllustration()
        case 3: HintIllustration()
        case 4: ScoreIllustration()
        default: ModesIllustration()
        }
    }
}

private let cellSize: CGFloat = 56

// 一：玉の逃げ道に ✕ がつき、詰みの印が押される。形は頭金（玉の前の金を、後ろの歩が守る）
private struct GoalIllustration: View {
    @State private var marks = 0
    @State private var sealed = false
    /// 玉の逃げ道。どれも金が押さえている
    private let escapes: [(Int, Int)] = [(1, 0), (3, 0), (1, 1), (3, 1)]

    var body: some View {
        let board = MiniBoard(cell: cellSize) { EmptyView() }
        MiniBoard(cell: cellSize) {
            ForEach(0..<escapes.count, id: \.self) { i in
                if i < marks {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Washi.vermilion)
                        .position(board.center(escapes[i].0, escapes[i].1))
                        .transition(.scale(scale: 2).combined(with: .opacity))
                }
            }
            koma("玉", upsideDown: true, size: cellSize).position(board.center(2, 0))
            koma("金", size: cellSize).position(board.center(2, 1))
            koma("歩", size: cellSize).position(board.center(2, 2))
            if sealed {
                Text("詰")
                    .font(Theme.brush(30))
                    .foregroundStyle(Washi.paper)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Washi.vermilion))
                    .rotationEffect(.degrees(-8))
                    .position(x: board.width - 40, y: board.height - 36)
                    .transition(.scale(scale: 2.4).combined(with: .opacity))
            }
        }
        .task {
            while !Task.isCancelled {
                marks = 0
                sealed = false
                try? await Task.sleep(for: .milliseconds(700))
                for i in 1...escapes.count {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { marks = i }
                    try? await Task.sleep(for: .milliseconds(380))
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { sealed = true }
                try? await Task.sleep(for: .milliseconds(2200))
            }
        }
    }
}

// 二：持ち駒の金が、玉の前に打たれて「王手！」
private struct CheckIllustration: View {
    @State private var dropped = false
    @State private var ring = 0.0

    var body: some View {
        let board = MiniBoard(cell: cellSize) { EmptyView() }
        VStack(spacing: 16) {
            MiniBoard(cell: cellSize) {
                koma("玉", upsideDown: true, size: cellSize).position(board.center(2, 0))
                koma("歩", size: cellSize).position(board.center(2, 2))
                Circle()
                    .stroke(Washi.vermilion, lineWidth: 4 * (1 - ring) + 1)
                    .frame(width: cellSize, height: cellSize)
                    .scaleEffect(0.6 + ring * 1.8)
                    .opacity(dropped ? 1 - ring : 0)
                    .position(board.center(2, 1))
                if dropped {
                    koma("金", size: cellSize)
                        .position(board.center(2, 1))
                        .transition(.scale(scale: 1.7).combined(with: .opacity))
                    Text("王手！")
                        .font(Theme.koma(22))
                        .foregroundStyle(Washi.vermilion)
                        .position(x: board.center(3, 1).x + 34, y: board.center(3, 1).y)
                        .transition(.scale(scale: 1.8).combined(with: .opacity))
                }
            }
            // 持ち駒の台。打つと空になる
            HStack(spacing: 10) {
                Text("持ち駒").font(.system(size: 13, weight: .semibold)).foregroundStyle(Washi.inkSoft)
                RoundedRectangle(cornerRadius: 5)
                    .fill(Washi.paper)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Washi.kayaEdge.opacity(0.6), lineWidth: 1))
                    .frame(width: 60, height: 60)
                    .overlay {
                        if !dropped { koma("金", size: 46).transition(.scale.combined(with: .opacity)) }
                    }
            }
        }
        .task {
            while !Task.isCancelled {
                dropped = false
                ring = 0
                try? await Task.sleep(for: .milliseconds(1200))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { dropped = true }
                withAnimation(.easeOut(duration: 0.7)) { ring = 1 }
                try? await Task.sleep(for: .milliseconds(2600))
            }
        }
    }
}

// 三：指でタップすると、動けるマスが光る
private struct TapIllustration: View {
    @State private var selected = false
    private let targets: [(Int, Int)] = [(1, 1), (2, 1), (3, 1), (1, 2), (3, 2), (2, 3)]

    var body: some View {
        let board = MiniBoard(cell: cellSize) { EmptyView() }
        MiniBoard(cell: cellSize) {
            ForEach(0..<targets.count, id: \.self) { i in
                Rectangle()
                    .fill(Color(red: 0.16, green: 0.45, blue: 0.85).opacity(selected ? 0.4 : 0))
                    .frame(width: cellSize - 3, height: cellSize - 3)
                    .position(board.center(targets[i].0, targets[i].1))
            }
            koma("金", size: cellSize).position(board.center(2, 2))
                .scaleEffect(selected ? 1.1 : 1)
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 34))
                .foregroundStyle(Washi.ink.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 3)
                .position(x: board.center(2, 2).x + 16, y: board.center(2, 2).y + (selected ? 26 : 44))
        }
        .task {
            while !Task.isCancelled {
                selected = false
                try? await Task.sleep(for: .milliseconds(1000))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { selected = true }
                try? await Task.sleep(for: .milliseconds(2400))
            }
        }
    }
}

// 四：ヒント。1回目は駒、2回目は行き先が光る。金は斜め前に 1 マス動いて頭金になる
private struct HintIllustration: View {
    @State private var step = 0

    var body: some View {
        let board = MiniBoard(cell: cellSize) { EmptyView() }
        VStack(spacing: 14) {
            MiniBoard(cell: cellSize) {
                Rectangle()
                    .fill(Theme.hint.opacity(step >= 2 ? 0.55 : 0))
                    .frame(width: cellSize - 3, height: cellSize - 3)
                    .position(board.center(2, 1))
                koma("玉", upsideDown: true, size: cellSize).position(board.center(2, 0))
                koma("歩", size: cellSize).position(board.center(2, 2))
                koma("金", size: cellSize)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hint, lineWidth: step == 1 ? 3 : 0).padding(2))
                    .position(board.center(3, 2))
            }
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.hint)
                    .scaleEffect(step == 1 || step == 2 ? 1.2 : 1)
                chip("1回目：駒", on: step == 1)
                chip("2回目：行き先", on: step == 2)
            }
        }
        .task {
            while !Task.isCancelled {
                step = 0
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.25)) { step = 1 }
                try? await Task.sleep(for: .milliseconds(1400))
                withAnimation(.easeOut(duration: 0.25)) { step = 2 }
                try? await Task.sleep(for: .milliseconds(1800))
            }
        }
    }

    private func chip(_ text: String, on: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(on ? Washi.paper : Washi.inkSoft)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 3).fill(on ? Theme.hint : Washi.paperDark))
    }
}

// 五：連勝が増えるほど、倍率と得点が伸びる
private struct ScoreIllustration: View {
    @State private var streak = 1

    /// 「次の得点」の倍率。次に解くと streak + 1 連勝目になる（Session.nextStreakMultiplier と同じ）。
    /// 実際のスコアと同じ式で求める（Score.swift）。式を変えたときに、説明と食い違わないように
    private var multiplier: Double { ScoreGain.streakMultiplier(for: streak + 1) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28 + CGFloat(streak) * 2))
                    .foregroundStyle(Washi.vermilion)
                    .scaleEffect(1.0)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak)連勝")
                        .font(Theme.koma(26))
                        .foregroundStyle(Washi.ink)
                        .contentTransition(.numericText())
                    Text("次の得点  " + ScoreGain.format(multiplier))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Washi.paper)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Washi.vermilion))
                        .contentTransition(.numericText())
                }
            }
            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= streak ? Washi.vermilion : Washi.paperDark)
                        .frame(width: 30, height: 8 + CGFloat(i) * 3)
                }
            }
            .frame(height: 30, alignment: .bottom)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(Washi.paper.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Washi.kayaEdge.opacity(0.5), lineWidth: 1))
        .task {
            while !Task.isCancelled {
                streak = 1
                try? await Task.sleep(for: .milliseconds(900))
                for s in 2...6 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { streak = s }
                    try? await Task.sleep(for: .milliseconds(650))
                }
                try? await Task.sleep(for: .milliseconds(1600))
            }
        }
    }
}

// 六：3 つのモードの木札が、順に選ばれる
private struct ModesIllustration: View {
    @State private var selected = 0
    private let names = ["チュートリアル", "ノーマル", "タイム"]
    private let notes = ["\(TutorialStage.all.count)段階で学ぶ。まずはここから", "自分のペースで、ずっと解ける", "60秒から。正解で時間が増える"]

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    FudaTag(text: names[i], selected: i == selected, fontSize: 14)
                }
            }
            Text(notes[selected])
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Washi.inkSoft)
                .id(selected)
                .transition(.opacity)
        }
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(Washi.paper.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Washi.kayaEdge.opacity(0.5), lineWidth: 1))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1800))
                withAnimation(.easeInOut(duration: 0.3)) { selected = (selected + 1) % 3 }
            }
        }
    }
}
