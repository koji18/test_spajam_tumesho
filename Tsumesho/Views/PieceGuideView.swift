import SwiftUI
import UIKit

// 駒の動き。ホームの木札から開くシート。駒を選ぶと、動けるマスが光り、駒が実際に動いてみせる。
// 成れる駒は「成る」で、成ったあとの動きに切り替わる。役割は、詰将棋でどう使うかを一言で書く
struct PieceGuideSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .gold
    @State private var promoted = false

    private static let order: [Kind] = [.king, .gold, .silver, .knight, .lance, .pawn, .bishop, .rook]

    var body: some View {
        VStack(spacing: 0) {
            header
            selector
            // 駒ごとのページ。左右にスワイプしても、上の駒を押しても切り替わる
            TabView(selection: $kind) {
                ForEach(Self.order, id: \.self) { k in
                    page(k).tag(k)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(PaperBackground())
        .environment(\.palette, .classic)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: kind) { _, _ in
            promoted = false
            if session.hapticsOn { UISelectionFeedbackGenerator().selectionChanged() }
        }
    }

    // 1 つの駒のページ。縦に長いときだけ、上下にスクロールする
    private func page(_ k: Kind) -> some View {
        let isPromoted = promoted && k.canPromote
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleRow(k, isPromoted)
                PieceMoveBoard(kind: k, promoted: isPromoted)
                    .frame(maxWidth: .infinity)
                    .id("\(k.rawValue)-\(isPromoted)")
                legend
                infoCard(k, isPromoted)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 上の段

    private var header: some View {
        HStack {
            Text("駒の動き").font(Theme.koma(26)).foregroundStyle(Washi.ink)
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

    // 駒を選ぶ列。8 つの駒を横にそろえる。選んでいる駒は朱の縁で、少し大きくする
    private var selector: some View {
        HStack(spacing: 2) {
            ForEach(Self.order, id: \.self) { k in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { kind = k }
                } label: {
                    KomaView(label: Notation.label(k), size: 38)
                        .environment(\.palette, .classic)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 5).fill(k == kind ? Washi.kaya.opacity(0.7) : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(k == kind ? Washi.vermilion : Color.clear, lineWidth: 2))
                        .scaleEffect(k == kind ? 1.08 : 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.reading(k).name)
                .accessibilityAddTraits(k == kind ? .isSelected : [])
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .padding(.top, 4)
    }

    // MARK: 見出し

    private func titleRow(_ kind: Kind, _ promoted: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            KomaView(label: Notation.label(Piece(side: .black, kind: kind, promoted: promoted)),
                     promoted: promoted, size: 54)
                .environment(\.palette, .classic)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(promoted ? Self.promotedReading(kind).name : Self.reading(kind).name)
                    .font(Theme.koma(24)).foregroundStyle(Washi.ink)
                Text(promoted ? Self.promotedReading(kind).kana : Self.reading(kind).kana)
                    .font(.system(size: 12)).foregroundStyle(Washi.inkSoft)
            }
            Spacer()
            if kind.canPromote { promoteSwitch(promoted) }
        }
    }

    // 「成る」の切り替え。成ったあとの駒の動きを見られる
    private func promoteSwitch(_ isPromoted: Bool) -> some View {
        Button {
            if session.hapticsOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { promoted.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPromoted ? "arrow.uturn.backward" : "arrow.up.circle.fill")
                Text(isPromoted ? "元に戻す" : "成る")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(isPromoted ? Washi.vermilion : Washi.paper)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 4).fill(isPromoted ? Color.clear : Washi.vermilion))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Washi.vermilion, lineWidth: isPromoted ? 1.5 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.16, green: 0.45, blue: 0.85).opacity(0.45)).frame(width: 16, height: 16)
            Text("動けるマス。うすい駒が、動いた先のようすです")
            Spacer()
        }
        .font(.system(size: 12)).foregroundStyle(Washi.inkSoft)
    }

    // MARK: 説明

    private func infoCard(_ kind: Kind, _ promoted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let info = promoted ? Self.promotedInfo(kind) : Self.info(kind)
            section("動き方", info.move)
            section("詰将棋での役割", info.role)
            if kind.canPromote && !promoted {
                section("成ると", Self.promoteNote(kind))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 4).fill(Washi.paper.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Washi.kayaEdge.opacity(0.5), lineWidth: 1))
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(Washi.vermilion)
            Text(text).font(.system(size: 15)).foregroundStyle(Washi.ink).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 文言

    static func reading(_ k: Kind) -> (name: String, kana: String) {
        switch k {
        case .king: ("玉将", "ぎょくしょう ・ 取られたら負け")
        case .gold: ("金将", "きんしょう ・ 成れない")
        case .silver: ("銀将", "ぎんしょう")
        case .knight: ("桂馬", "けいま")
        case .lance: ("香車", "きょうしゃ")
        case .pawn: ("歩兵", "ふひょう")
        case .bishop: ("角行", "かくぎょう")
        case .rook: ("飛車", "ひしゃ")
        }
    }

    static func promotedReading(_ k: Kind) -> (name: String, kana: String) {
        switch k {
        case .pawn: ("と金", "ときん ・ 金と同じ動き")
        case .lance: ("成香", "なりきょう ・ 金と同じ動き")
        case .knight: ("成桂", "なりけい ・ 金と同じ動き")
        case .silver: ("成銀", "なりぎん ・ 金と同じ動き")
        case .bishop: ("竜馬", "りゅうま ・ 通称「馬」")
        case .rook: ("竜王", "りゅうおう ・ 通称「龍」")
        default: (reading(k).name, reading(k).kana)
        }
    }

    static func info(_ k: Kind) -> (move: String, role: String) {
        switch k {
        case .king: ("全部の方向に、1マスずつ進みます。", "詰将棋では、相手の玉を追いつめます。逃げ道を1つずつふさいで、動けなくしたら「詰み」です。")
        case .gold: ("前・左右・後ろ・斜め前の6方向に、1マスずつ。斜め後ろにだけ動けません。", "守りにも攻めにも強い駒です。玉のすぐ前に打つ「頭金」は、詰みの基本の形です。")
        case .silver: ("前と斜めの5方向に、1マスずつ。横と真後ろには動けません。", "攻めの要です。斜めに動けるので、金では届かない場所から王手をかけられます。")
        case .knight: ("前に2マス進んで、左右どちらかに1マス曲がります。ほかの駒を飛び越えられます。", "ほかの駒に邪魔されず、意外な方向から王手をかけられます。後ろには戻れません。")
        case .lance: ("前にまっすぐ、駒にぶつかるまで進めます。後ろには戻れません。", "遠くから、玉の前の筋を一気に押さえる王手が得意です。")
        case .pawn: ("前に1マスだけ進みます。", "いちばん小さな駒ですが、ほかの駒を「支える」役目や、あえて取らせる「捨て駒」で大活躍します。")
        case .bishop: ("斜めに、駒にぶつかるまで何マスでも進めます。", "遠くから斜めの線で王手をかけます。玉の逃げ道の斜めをまとめてふさげます。")
        case .rook: ("縦と横に、駒にぶつかるまで何マスでも進めます。", "いちばん強い攻めの駒です。縦横の一直線に王手をかけ、逃げ道をまとめてふさぎます。")
        }
    }

    static func promotedInfo(_ k: Kind) -> (move: String, role: String) {
        switch k {
        case .bishop: ("角の斜めの動きに加えて、縦横にも1マスずつ動けます。", "遠くまで届く斜めの線と、玉のまわりを固める1マスの動きを両方使えて、とても強力です。")
        case .rook: ("飛車の縦横の動きに加えて、斜めにも1マスずつ動けます。", "最強の駒です。龍がいる形は、詰みのヒントになることが多いです。")
        default: ("金と同じ動きになります。前・左右・後ろ・斜め前に、1マスずつ。", "動けるマスが増えるので、玉の逃げ道をふさぎやすくなります。")
        }
    }

    static func promoteNote(_ k: Kind) -> String {
        switch k {
        case .bishop: "敵陣（一〜三段）に入ると、馬に成れます。縦横の1マスが加わります。"
        case .rook: "敵陣（一〜三段）に入ると、龍に成れます。斜めの1マスが加わります。"
        default: "敵陣（一〜三段）に入ると成れます。金と同じ動きになります。"
        }
    }
}

// 5×5 の盤の真ん中に駒を置き、動けるマスを青く光らせる。駒の分身が、動けるマスへ順に跳んでみせる
private struct PieceMoveBoard: View {
    let kind: Kind
    let promoted: Bool

    @State private var ghost: Int?
    @State private var pulse = false

    private let cell: CGFloat = 56
    private let span = 5

    var body: some View {
        let targets = Self.targets(kind: kind, promoted: promoted, span: span)
        let label = Notation.label(Piece(side: .black, kind: kind, promoted: promoted))
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5).fill(Washi.kayaSide).offset(y: 5)
            RoundedRectangle(cornerRadius: 5).fill(Washi.kaya)
            Path { p in
                for i in 0...span {
                    let v = 8 + cell * CGFloat(i)
                    p.move(to: CGPoint(x: v, y: 8)); p.addLine(to: CGPoint(x: v, y: 8 + cell * CGFloat(span)))
                    p.move(to: CGPoint(x: 8, y: v)); p.addLine(to: CGPoint(x: 8 + cell * CGFloat(span), y: v))
                }
            }
            .stroke(Washi.ink.opacity(0.8), lineWidth: 1)
            ForEach(Array(targets.enumerated()), id: \.offset) { i, t in
                Rectangle()
                    .fill(Color(red: 0.16, green: 0.45, blue: 0.85).opacity(pulse ? 0.5 : 0.32))
                    .frame(width: cell - 3, height: cell - 3)
                    .position(center(t.col, t.row))
            }
            // 分身。動けるマスへ順に跳んで、真ん中へ戻る
            KomaView(label: label, promoted: promoted, size: cell)
                .environment(\.palette, .classic)
                .opacity(ghost == nil ? 0 : 0.5)
                .position(ghost.map { center(targets[$0].col, targets[$0].row) } ?? center(2, 2))
            KomaView(label: label, promoted: promoted, size: cell)
                .environment(\.palette, .classic)
                .shadow(color: .black.opacity(0.35), radius: 2, x: 1, y: 3)
                .position(center(2, 2))
        }
        .frame(width: cell * CGFloat(span) + 16, height: cell * CGFloat(span) + 16)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 8)
        .task(id: "\(kind.rawValue)-\(promoted)") {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            while !Task.isCancelled {
                for i in targets.indices {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { ghost = i }
                    try? await Task.sleep(for: .milliseconds(targets.count > 8 ? 260 : 420))
                    if Task.isCancelled { return }
                }
                withAnimation(.easeOut(duration: 0.2)) { ghost = nil }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func center(_ col: Int, _ row: Int) -> CGPoint {
        CGPoint(x: 8 + cell * (CGFloat(col) + 0.5), y: 8 + cell * (CGFloat(row) + 0.5))
    }

    // 駒の動き。盤は先手（下から上へ攻める向き）で、前は画面の上
    struct Square { let col: Int; let row: Int }

    static func targets(kind: Kind, promoted: Bool, span: Int) -> [Square] {
        let gold: [(Int, Int)] = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (0, 1)]
        let orth: [(Int, Int)] = [(0, -1), (0, 1), (-1, 0), (1, 0)]
        let diag: [(Int, Int)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        var steps: [(Int, Int)] = []
        var slides: [(Int, Int)] = []
        switch (kind, promoted) {
        case (.king, _): steps = orth + diag
        case (.gold, _), (.pawn, true), (.lance, true), (.knight, true), (.silver, true): steps = gold
        case (.silver, false): steps = [(-1, -1), (0, -1), (1, -1), (-1, 1), (1, 1)]
        case (.knight, false): steps = [(-1, -2), (1, -2)]
        case (.lance, false): slides = [(0, -1)]
        case (.pawn, false): steps = [(0, -1)]
        case (.bishop, false): slides = diag
        case (.bishop, true): slides = diag; steps = orth
        case (.rook, false): slides = orth
        case (.rook, true): slides = orth; steps = diag
        }
        var result: [Square] = []
        func add(_ c: Int, _ r: Int) {
            guard (0..<span).contains(c), (0..<span).contains(r) else { return }
            if !result.contains(where: { $0.col == c && $0.row == r }) { result.append(Square(col: c, row: r)) }
        }
        let c0 = span / 2, r0 = span / 2
        for (dc, dr) in steps { add(c0 + dc, r0 + dr) }
        for (dc, dr) in slides {
            var n = 1
            while (0..<span).contains(c0 + dc * n) && (0..<span).contains(r0 + dr * n) {
                add(c0 + dc * n, r0 + dr * n)
                n += 1
            }
        }
        return result
    }
}
