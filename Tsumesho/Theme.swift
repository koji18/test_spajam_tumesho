import CoreText
import SwiftUI

enum Theme {
    static let background = Color(red: 0.098, green: 0.106, blue: 0.125)  // #191b20
    static let surface = Color(red: 0.137, green: 0.149, blue: 0.176)     // #23262d
    static let ink = Color(red: 0.945, green: 0.945, blue: 0.953)
    static let soft = Color(red: 0.655, green: 0.667, blue: 0.702)
    static let accent = Color(red: 0.725, green: 0.651, blue: 0.949)      // 半蔵門線の紫
    static let hint = Color(red: 0.953, green: 0.592, blue: 0.0)          // 銀座線の橙
    static let ok = Color(red: 0.373, green: 0.812, blue: 0.639)
    static let ng = Color(red: 0.941, green: 0.478, blue: 0.533)

    static let wood = Color(red: 0.902, green: 0.776, blue: 0.549)
    static let woodLine = Color(red: 0.541, green: 0.416, blue: 0.208)
    static let piece = Color(red: 0.965, green: 0.906, blue: 0.769)
    static let pieceInk = Color(red: 0.114, green: 0.102, blue: 0.078)

    // ネオン風の盤と駒
    static let boardBackground = Color(red: 0.035, green: 0.043, blue: 0.067)
    static let neonCyan = Color(red: 0.25, green: 0.88, blue: 1.0)   // 攻め方の駒と盤の枠
    static let neonPink = Color(red: 1.0, green: 0.24, blue: 0.6)    // 玉方の駒
    static let pieceFill = Color(red: 0.07, green: 0.08, blue: 0.14)
    static let gridLine = Color.white.opacity(0.32)
    static let panel = Color(red: 0.05, green: 0.06, blue: 0.09)

    // 詰み演出の色
    static let neonGreen = Color(red: 0.78, green: 1.0, blue: 0.18)
    static let neonMagenta = Color(red: 1.0, green: 0.24, blue: 0.81)
    static let cream = Color(red: 1.0, green: 0.96, blue: 0.86)
    static let goldGlow = Color(red: 0.96, green: 0.76, blue: 0.35)
    static let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.97, blue: 0.86), Color(red: 0.96, green: 0.81, blue: 0.48), Color(red: 0.75, green: 0.54, blue: 0.17)],
        startPoint: .top, endPoint: .bottom)

    static func koma(_ size: CGFloat) -> Font { .custom("HiraMinProN-W6", size: size) }

    // 毛筆体（Yuji Boku）。演出に使う「詰」「正」「解」の 3 文字だけに絞って同梱している（Fonts/YujiBoku-OFL.txt）
    static func brush(_ size: CGFloat) -> Font { .custom("YujiBoku-Regular", size: size) }

    // 英数字の飾り文字（NORMAL・1540・01:24 など）。Orbitron は予約フォント名があるので、改変せずに同梱している
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Orbitron", size: size).weight(weight)
    }

    // 数字。Orbitron の数字は「7」が独特の形で読みにくいので、数字は丸ゴシックの太字で出し、桁の幅をそろえる
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static func registerFonts() {
        for name in ["YujiBoku-Subset", "Orbitron"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // 「三手詰」のように手数を漢数字にする
    static func kanjiNumber(_ n: Int) -> String {
        let digits = Array("〇一二三四五六七八九")
        return n < 10 ? String(digits[n]) : String(n)
    }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .monospaced) }
}

// 見た目の組み合わせ。初回のチュートリアルを詰ませるまでは落ち着いた「普通」の見た目で出し、
// 詰ませた瞬間に派手な「ネオン」の見た目に切り替える
struct Palette {
    let plain: Bool

    static let neon = Palette(plain: false)
    static let classic = Palette(plain: true)

    var background: Color { plain ? Color(red: 0.95, green: 0.93, blue: 0.88) : Color(red: 0.03, green: 0.035, blue: 0.06) }
    var text: Color { plain ? Theme.pieceInk : .white }
    var subText: Color { plain ? Color(red: 0.42, green: 0.39, blue: 0.33) : Theme.soft }
    var accent: Color { plain ? Theme.woodLine : Theme.goldGlow }
    var counter: Color { plain ? Theme.pieceInk : Theme.neonPink }
    var rating: Color { plain ? Theme.pieceInk : Color(red: 0.75, green: 0.97, blue: 1.0) }
    var panel: Color { plain ? .white : Theme.panel }
    var panelStroke: Color { plain ? .black.opacity(0.12) : .white.opacity(0.14) }
    var badgeStroke: Color { plain ? Theme.woodLine : Theme.neonCyan }
    var resetButton: Color { plain ? Theme.pieceInk : Theme.neonCyan }
    var hintButton: Color { plain ? Theme.pieceInk : .white }
    // 光らせる強さ。普通の見た目では光らせない
    var glow: Double { plain ? 0 : 1 }

    // 盤
    var boardFill: Color { plain ? Theme.wood : .black }
    var gridLine: Color { plain ? Theme.woodLine.opacity(0.7) : Theme.gridLine }
    var boardEdge: Color { plain ? Theme.woodLine : .white.opacity(0.9) }
    var coordinate: Color { plain ? Color(red: 0.42, green: 0.39, blue: 0.33) : Theme.ink.opacity(0.75) }
    var target: Color { plain ? Theme.woodLine : Theme.neonCyan }
    var lastMove: Color { plain ? Theme.hint : Theme.neonPink }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.neon
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
