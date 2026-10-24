import SwiftUI

// 木札の形。上の2つの角を斜めに落とした板
struct FudaShape: Shape {
    var chamfer: CGFloat = 6

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + chamfer, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - chamfer, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + chamfer))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 2, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 2, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 2), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + chamfer))
        p.closeSubpath()
        return p
    }
}

// ホーム画面のメニューに使う木札。上に紐を通す穴があり、選んでいる札は木の色が濃く、朱の文字で、影が深い。
// 選んでいない札は色が薄い。選んでも位置は動かない
struct FudaTag: View {
    let text: String
    var selected = false
    var fontSize: CGFloat = 15

    var body: some View {
        Text(text)
            .font(Theme.koma(fontSize))
            .foregroundStyle(selected ? Washi.vermilion : Washi.ink.opacity(0.85))
            .padding(.horizontal, 11)
            .padding(.top, 17)
            .padding(.bottom, 8)
            .background { board }
            .overlay(alignment: .top) { hole }
            .overlay { FudaShape().stroke(selected ? Washi.vermilion : Washi.kayaEdge.opacity(0.65), lineWidth: selected ? 2 : 1) }
            .shadow(color: .black.opacity(selected ? 0.3 : 0.14), radius: selected ? 4 : 1.5, x: 0, y: selected ? 5 : 2)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: selected)
    }

    private var board: some View {
        ZStack {
            FudaShape().fill(selected ? Washi.kaya : Washi.kaya.opacity(0.5))
            Canvas { ctx, size in
                for i in 0..<9 {
                    let y = size.height * (Double(i) + 0.5) / 9
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addCurve(to: CGPoint(x: size.width, y: y + (i % 2 == 0 ? 1.5 : -1.5)),
                                  control1: CGPoint(x: size.width * 0.35, y: y - 1.5),
                                  control2: CGPoint(x: size.width * 0.7, y: y + 2))
                    ctx.stroke(path, with: .color(Washi.kayaSide.opacity(i % 3 == 0 ? 0.16 : 0.08)), lineWidth: 0.7)
                }
            }
            .clipShape(FudaShape())
        }
    }

    // 紐を通す穴と、そこから上へ出る紐
    private var hole: some View {
        ZStack {
            Capsule()
                .fill(selected ? Washi.vermilion : Washi.inkSoft)
                .frame(width: 2.5, height: 11)
                .offset(y: -3)
            Circle()
                .fill(Washi.kayaSide)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Washi.paper.opacity(0.5), lineWidth: 0.5))
        }
        .offset(y: 7)
    }
}
