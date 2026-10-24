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

    static func koma(_ size: CGFloat) -> Font { .custom("HiraMinProN-W6", size: size) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .monospaced) }
}
