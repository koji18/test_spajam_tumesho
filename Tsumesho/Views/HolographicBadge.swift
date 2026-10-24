import SwiftUI

// 傾きで光と縁の色が流れる段位バッジ。文字は反射の上に描いて読みやすくする。
struct HolographicBadge: View {
    let title: String
    let size: CGFloat
    var celebrating = false
    @Environment(TiltMotion.self) private var tilt
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var neon: Bool { celebrating || !palette.plain }
    private var x: Double { neon && !reduceMotion ? tilt.horizontal : 0 }
    private var y: Double { neon && !reduceMotion ? tilt.vertical : 0 }

    var body: some View {
        ZStack {
            Circle().fill(neon ? Theme.panel : palette.panel)
            if neon {
                Circle().fill(RadialGradient(
                    colors: [Theme.neonCyan.opacity(0.32), Theme.panel],
                    center: UnitPoint(x: 0.5 + x * 0.35, y: 0.25 + y * 0.35),
                    startRadius: 0, endRadius: size * 0.85))
                Ellipse()
                    .fill(LinearGradient(colors: [.clear, Theme.cream.opacity(0.3), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: size * 0.65, height: size * 1.6)
                    .rotationEffect(.degrees(-32))
                    .offset(x: x * size * 0.7, y: y * size * 0.2)
                    .blur(radius: size * 0.035)
            }
            Text(title)
                .font(.system(size: size * (celebrating ? 0.49 : 0.39), weight: .heavy,
                              design: celebrating ? .serif : .default))
                .foregroundStyle(neon ? Theme.cream : palette.text)
                .shadow(color: .black.opacity(neon ? 0.55 : 0), radius: 2, y: 1)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if neon {
                Circle().stroke(AngularGradient(
                    colors: [Theme.neonCyan, Theme.cream, Theme.goldGlow, Theme.neonMagenta, Theme.neonCyan],
                    center: .center, angle: .degrees(x * 70 + y * 35)),
                    lineWidth: celebrating ? 4 : 1.8)
            } else {
                Circle().stroke(palette.badgeStroke, lineWidth: 1.5)
            }
        }
        .shadow(color: (celebrating ? Theme.goldGlow : Theme.neonCyan).opacity(neon ? 0.6 : 0),
                radius: celebrating ? 25 : 8, x: x * 4, y: y * 4)
        .rotation3DEffect(.degrees(-y * 8), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(x * 8), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title == "級" ? "級位" : "\(title)段")
    }
}
