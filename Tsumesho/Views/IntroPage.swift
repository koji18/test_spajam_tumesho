import SwiftUI

// ホーム画面。成績を見て、モードと盤の大きさを選んで始める。遊び方は折りたたんでおく。
// 盤の大きさとモードは遊んでいる間も、問題画面のメニューから変えられる
struct IntroPage: View {
    let onStart: () -> Void
    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette
    @State private var showsRules = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    if session.solvedTotal > 0 { statsStrip }
                    modePicker
                    boardSizePicker
                    rules
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)

            startButton
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .background(NeonBackdrop())
    }

    // MARK: タイトル

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                KomaView(label: "金", size: 44, tone: .hand)
                KomaView(label: "玉", upsideDown: true, size: 44, tone: .defender)
            }
            Text("ツメショー")
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(palette.text)
            Text("1問1分の詰将棋。\nスワイプで次々に解こう。")
                .font(.system(size: 16))
                .foregroundStyle(palette.subText)
        }
    }

    // MARK: 成績

    private var statsStrip: some View {
        HStack(spacing: 0) {
            stat(session.rankName, "段位")
            divider
            stat("\(session.rating)", "レーティング")
            divider
            stat("\(session.bestStreak)", "最高連勝")
            divider
            stat("\(session.solvedTotal)", "解いた数")
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.panelStroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ name: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.number(20))
                .foregroundStyle(palette.rating)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.subText)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(palette.panelStroke).frame(width: 1, height: 28)
    }

    // MARK: モード

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("モード")
            HStack(spacing: 12) {
                modeCard(.normal, title: "ノーマル", text: "自分のペースで\nずっと解ける")
                modeCard(.timeTrial, title: "タイムトライアル",
                         text: session.timeTrialBest > 0 ? "60秒から。\n最高 \(session.timeTrialBest) 問" : "60秒から。\n何問解ける？")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func modeCard(_ mode: PlayMode, title: String, text: String) -> some View {
        let selected = session.mode == mode
        return Button {
            session.mode = mode
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ModeIcon(mode: mode, size: 24)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.subText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(palette.panel))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? palette.accent : palette.panelStroke, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)。\(text)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: 盤の大きさ

    private var boardSizePicker: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("盤のサイズ")
            Picker("盤のサイズ", selection: $session.boardSize) {
                ForEach(BoardSize.allCases, id: \.self) { size in
                    Text(size.label).tag(size)
                }
            }
            .pickerStyle(.segmented)
            Text("5×5・7×7 は玉のまわりだけ、9×9 は普通の盤です。大きいほど高得点")
                .font(.system(size: 12))
                .foregroundStyle(palette.subText)
        }
    }

    // MARK: 遊び方

    private var rules: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showsRules.toggle() }
            } label: {
                HStack {
                    sectionTitle("遊び方")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.subText)
                        .rotationEffect(.degrees(showsRules ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsRules {
                VStack(alignment: .leading, spacing: 18) {
                    rule(no: "1", title: "毎回「王手」をかける",
                         text: "王手は、次に玉を取れる状態にする手。詰将棋では王手しか指せません") {
                        KomaView(label: "玉", upsideDown: true, size: 40, tone: .defender)
                    }
                    rule(no: "2", title: "駒をタップすると、動けるマスが光る",
                         text: "光ったマスをタップすると指せます。持ち駒は空いているマスに打てます") {
                        RoundedRectangle(cornerRadius: 4).fill(palette.target.opacity(palette.targetFill))
                            .frame(width: 34, height: 34)
                            .overlay(KomaView(label: "金", size: 30, tone: .hand))
                    }
                    rule(no: "3", title: "迷ったら「ヒント」",
                         text: "1回目で王手をかけられる駒、2回目で正解の場所が光ります") {
                        Image(systemName: "lightbulb.fill").font(.system(size: 26)).foregroundStyle(Theme.hint)
                    }
                }
                .padding(.top, 14)
                .transition(.opacity)
            }
        }
    }

    private func rule<Icon: View>(no: String, title: String, text: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon().frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(palette.text)
                Text(text).font(.system(size: 13)).foregroundStyle(palette.subText).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(no). \(title)。\(text)")
    }

    // MARK: 共通

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .bold)).foregroundStyle(palette.subText)
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text(session.solvedTotal > 0 ? "つづける" : "はじめる")
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(palette.plain ? Theme.woodLine : Theme.goldGlow)
        .foregroundStyle(palette.plain ? Color.white : Theme.background)
    }
}
