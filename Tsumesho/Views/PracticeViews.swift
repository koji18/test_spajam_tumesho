import SwiftUI

// 一度だけ少し持ち上げて、墨色に落ち着く。リセットして解き直したときも再生する。
struct PracticeMateMessage: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        Text("詰み！")
            .font(.system(size: 22, weight: .semibold, design: .serif))
            .foregroundStyle(settled ? palette.text : palette.accent)
            .shadow(color: palette.accent.opacity(settled ? 0 : 0.4), radius: settled ? 0 : 6)
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

struct PracticeEndPage: View {
    let isEmpty: Bool
    let size: BoardSize
    let onNormal: () -> Void
    let onRepeat: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf")
                .font(.system(size: 32)).foregroundStyle(palette.accent)
            Text(isEmpty ? "練習する問題は、これから。" : "ひと巡り、おつかれさまでした。")
                .font(.system(size: 23, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
            Text(isEmpty
                 ? "\(size.label)の問題はまだありません。\nノーマルでミスした問題が、ここに残ります。\nほかの盤サイズは右上のメニューから選べます。"
                 : "同じ問題を繰り返すこともできます。\n自分のペースで続けましょう。")
                .font(.system(size: 15)).foregroundStyle(palette.subText)
                .multilineTextAlignment(.center)
            if !isEmpty {
                Button("もう一巡する", action: onRepeat).buttonStyle(.borderedProminent)
            }
            Button("ノーマルへ", action: onNormal).buttonStyle(.bordered)
        }
        .tint(palette.accent)
        .foregroundStyle(palette.text)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeonBackdrop())
    }
}
