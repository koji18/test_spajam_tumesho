import SwiftUI

// 和紙の見た目の画面（入門・修行）で使う、持ち駒の段。
// 選んだ駒は朱、ヒントは橙、「答えを見る」で見せている正解の駒は緑の枠で光らせる
struct WashiHandRow: View {
    let game: Game

    var body: some View {
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
        // 「答えを見る」で見せている正解が、この持ち駒を打つ手か。盤の行き先と同じ緑の枠で光らせる
        let revealed = game.revealedAnswer.map { $0.from == nil && $0.kind == item.kind } ?? false
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
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.ok, lineWidth: revealed ? 3 : 0))
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
        .accessibilityLabel("持ち駒の\(Notation.label(item.kind))" + (item.count > 1 ? "、\(item.count)枚" : "") + (revealed ? "、正解の駒" : ""))
    }
}
