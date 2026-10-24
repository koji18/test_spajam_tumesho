import SwiftUI

/// 画面の上に固定するバー。左に今のモード、右にメニューを開く歯車
struct TopBar: View {
    let insets: EdgeInsets
    let menuOpen: Bool
    let onMenu: () -> Void
    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette
    @Environment(\.pageLayout) private var layout

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // 今のモード。押すとメニューを開く
                Button(action: onMenu) {
                    ModeIcon(mode: session.mode)
                        .foregroundStyle(palette.accent)
                        .frame(width: layout.barButton, height: layout.barButton)
                        .background(Circle().fill(palette.panel.opacity(0.8)))
                        .overlay(Circle().stroke(palette.accent, lineWidth: 1.5))
                        .shadow(color: Theme.goldGlow.opacity(0.7 * palette.glow), radius: 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("モード：\(session.mode == .normal ? "ノーマル" : "タイムトライアル")")
                .accessibilityHint("メニューを開きます")

                Spacer()

                Button(action: onMenu) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22))
                        .foregroundStyle(menuOpen ? Theme.neonCyan : palette.text.opacity(0.85))
                        .frame(width: layout.barButton, height: layout.barButton)
                        .background(Circle().fill(palette.panel.opacity(0.8)))
                        .overlay(Circle().stroke(menuOpen ? Theme.neonCyan : palette.text.opacity(0.3), lineWidth: 1.5))
                        .shadow(color: Theme.neonCyan.opacity(menuOpen ? 0.7 : 0), radius: 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(menuOpen ? "メニューを閉じる" : "メニュー")
            }
            .padding(.horizontal, 20)
            .frame(height: layout.topBarHeight - 1)
            Rectangle().fill(palette.text.opacity(0.08)).frame(height: 1)
        }
        .padding(.top, insets.top)
    }
}

/// モードのアイコン。ノーマルは「＋」の入った駒、タイムトライアルはストップウォッチ
struct ModeIcon: View {
    let mode: PlayMode
    var size: CGFloat = 22

    var body: some View {
        switch mode {
        case .normal:
            ZStack {
                KomaShape().stroke(lineWidth: 1.8).frame(width: size * 0.82, height: size)
                Image(systemName: "plus").font(.system(size: size * 0.42, weight: .bold)).offset(y: size * 0.08)
            }
        case .timeTrial:
            Image(systemName: "stopwatch").font(.system(size: size))
        }
    }
}

/// 歯車から開くメニュー
struct MenuPanel: View {
    let onHome: () -> Void
    let onMode: (PlayMode) -> Void
    let onRecords: () -> Void
    let onSettings: () -> Void
    let onSize: (BoardSize) -> Void
    @Environment(Session.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row(title: "ホーム", selected: false, action: onHome) { Image(systemName: "house") }
            row(title: "ノーマル", selected: session.mode == .normal, action: { onMode(.normal) }) { ModeIcon(mode: .normal, size: 20) }
            row(title: "タイムトライアル", selected: session.mode == .timeTrial, action: { onMode(.timeTrial) }) { ModeIcon(mode: .timeTrial, size: 20) }
            row(title: "記録", selected: false, action: onRecords) { Image(systemName: "chart.bar") }
            row(title: "設定", selected: false, action: onSettings) { Image(systemName: "gearshape") }

            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1).padding(.vertical, 8)

            Text("盤のサイズ").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.soft).padding(.leading, 4)
            HStack(spacing: 10) {
                ForEach(BoardSize.allCases, id: \.self) { size in
                    let selected = session.boardSize == size
                    Button {
                        onSize(size)
                    } label: {
                        Text(size.displayLabel)
                            .font(Theme.number(15))
                            .foregroundStyle(selected ? Theme.goldGlow : Theme.soft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Theme.goldGlow.opacity(0.14) : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.goldGlow : Color.white.opacity(0.2), lineWidth: selected ? 1.5 : 1))
                            .shadow(color: Theme.goldGlow.opacity(selected ? 0.5 : 0), radius: 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("盤のサイズ \(size.label)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 300)
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.panel.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.neonCyan.opacity(0.75), lineWidth: 1.2))
        .shadow(color: Theme.neonCyan.opacity(0.45), radius: 18)
    }

    /// メニューの 1 行。選ばれている行は金色で光らせる
    private func row<Icon: View>(title: String, selected: Bool, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                icon().frame(width: 26)
                Text(title).font(.system(size: 17, weight: .bold)).tracking(1)
                Spacer()
                if selected { Circle().fill(Theme.goldGlow).frame(width: 8, height: 8) }
            }
            .foregroundStyle(selected ? Theme.goldGlow : Theme.ink.opacity(0.9))
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Theme.goldGlow.opacity(0.1) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Theme.goldGlow : Color.clear, lineWidth: 1.2))
            .shadow(color: Theme.goldGlow.opacity(selected ? 0.4 : 0), radius: 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// タイムトライアルの時間切れ
struct TimeUpView: View {
    let solved: Int
    let best: Int
    let onRetry: () -> Void
    let onNormal: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("TIME UP")
                    .font(Theme.display(44, weight: .black))
                    .foregroundStyle(Theme.neonPink)
                    .shadow(color: Theme.neonPink, radius: 16)
                Text("\(solved) 問正解")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                Text(solved >= best && solved > 0 ? "ベスト記録！" : "ベスト \(best) 問")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.goldGlow)
                VStack(spacing: 12) {
                    Button(action: onRetry) {
                        Text("もう一度")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.cream)
                            .frame(width: 240).padding(.vertical, 14)
                            .overlay(Capsule().stroke(Theme.goldGlow, lineWidth: 2))
                            .shadow(color: Theme.goldGlow, radius: 10)
                    }
                    Button(action: onNormal) {
                        Text("ノーマルで続ける")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.soft)
                            .frame(width: 240).padding(.vertical, 12)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
    }
}

/// 記録
struct RecordsView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("スコア") {
                    stat("累計スコア", "\(session.totalScore)")
                }
                Section("レーティング") {
                    stat("段位", session.rankName)
                    stat("レーティング", "\(session.rating)")
                }
                Section("ノーマル") {
                    stat("正解した問題", "\(session.solvedTotal) 問")
                    stat("今の連勝", "\(session.streak)")
                    stat("最高連勝", "\(session.bestStreak)")
                }
                Section("タイムトライアル（60秒＋正解で加算）") {
                    stat("最高記録", "\(session.timeTrialBest) 問")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NeonBackdrop())
            .navigationTitle("記録")
            .toolbar { Button("閉じる") { dismiss() } }
        }
    }

    /// 記録の 1 行
    private func stat(_ name: String, _ value: String) -> some View {
        LabeledContent(name) {
            Text(value).font(Theme.number(16)).foregroundStyle(Theme.neonCyan)
        }
    }
}

/// 設定
struct SettingsView: View {
    let onShowTutorial: () -> Void
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            List {
                Section {
                    Toggle("振動", isOn: $session.hapticsOn).tint(Theme.neonCyan)
                } footer: {
                    Text("詰んだとき、駒を動かしたとき、間違えたときに振動します")
                }
                Section {
                    Button("遊び方をもう一度見る", action: onShowTutorial)
                    Button("最初の演出をもう一度見る") {
                        // 普通の見た目に戻し、1 問目のチュートリアルを詰ませたらネオンに変わる演出をもう一度見せる
                        session.tutorialCleared = false
                        onShowTutorial()
                    }
                } footer: {
                    Text("「最初の演出」は、1問目を詰ませた瞬間に、普通の見た目からネオンの見た目に変わる演出です")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NeonBackdrop())
            .navigationTitle("設定")
            .toolbar { Button("閉じる") { dismiss() } }
        }
    }
}
