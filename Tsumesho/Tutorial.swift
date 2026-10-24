import Foundation

// 入門チュートリアルの 7 段階。詰将棋の考え方を 1 段ずつ覚える。
// 問題はどれも 5×5 の盤の 1 手詰めか 3 手詰めで、正解の初手が一つだけになることを Tools/test.sh で確かめている。
struct TutorialStage: Identifiable {
    let number: Int
    let title: String
    let lesson: String   // 解く前に読む説明
    let review: String   // 詰ませたあとの解説
    let problem: Problem

    var id: Int { number }

    private init(_ number: Int, title: String, board: String, hand: String, plies: Int, answer: String,
                 lesson: String, review: String) {
        self.number = number
        self.title = title
        self.lesson = lesson
        self.review = review
        problem = Problem(id: number, size: .small, plies: plies, board: board, hand: hand, answer: answer, lesson: lesson)
    }

    static let all: [TutorialStage] = [
        TutorialStage(1, title: "王手をかけよう",
                      board: "6k2/9/6P2/9/9/9/9/9/9", hand: "G", plies: 1, answer: "３二金打",
                      lesson: "詰将棋は、毎回「王手」をかけて玉を追いつめるパズルです。王手とは、次の一手で玉を取れる形にすること。持ち駒の金を、玉のすぐ前に打ってみよう。",
                      review: "金を玉の真ん前に打ちました。後ろの歩が金を守っているので、玉は金を取れません。逃げ道もなく、詰みです。"),
        TutorialStage(2, title: "盤の駒も動かそう",
                      board: "9/6+B1k/6S2/9/9/9/9/9/9", hand: "", plies: 1, answer: "２二馬",
                      lesson: "持ち駒を打つだけでなく、盤の上の駒を動かして王手をかけることもできます。駒をタップすると動けるマスが光ります。馬（成った角）を動かしてみよう。",
                      review: "馬が玉のとなりに移動しました。銀が馬を守っているので、玉は取れません。馬が玉の逃げ道もふさいで、詰みです。"),
        TutorialStage(3, title: "飛車は一直線",
                      board: "7k1/9/8+B/9/9/9/9/9/9", hand: "R", plies: 1, answer: "３一飛打",
                      lesson: "飛車は、縦と横にまっすぐ、駒にぶつかるまで進めます。王手の「線」を引くのが得意です。持ち駒の飛車を、玉の逃げ道がなくなる場所に打とう。",
                      review: "飛車の王手に、馬が飛車を守っています。玉の逃げ先は、馬と飛車がすべて押さえていて、詰みです。"),
        TutorialStage(4, title: "取られない王手",
                      board: "6k2/5s3/5+R3/9/9/9/9/9/9", hand: "G", plies: 1, answer: "３二金打",
                      lesson: "王手をかけた駒を、玉に取られたら終わりです。味方が守っている場所に打てば、玉は取れません。龍（成った飛車）がどこを守っているか見てみよう。",
                      review: "金を龍が守っているので、玉は金を取れません。金の斜め前と横が、玉の逃げ道もふさいでいます。"),
        TutorialStage(5, title: "桂馬と成り",
                      board: "7k1/5+R3/9/7N1/9/9/9/9/9", hand: "", plies: 1, answer: "１二桂成",
                      lesson: "桂馬は、前に2マス進んで、左右どちらかに曲がる駒。ほかの駒を飛び越えます。敵陣（一〜三段）に入ると「成る」ことができ、金と同じ動きになります。",
                      review: "桂馬が跳ねて成り、金の動きになりました。龍が守っているので取られず、玉の逃げ道もなくなって詰みです。"),
        TutorialStage(6, title: "玉の逃げ先を読もう",
                      board: "9/8k/9/7L1/9/9/9/9/9", hand: "G", plies: 3, answer: "２三金打",
                      lesson: "3手詰めは「自分・玉・自分」の3手で詰ませます。王手をかけると、玉は逃げます（玉方の手は自動で進みます）。逃げた先で、もう一度王手して詰ませる手を探そう。",
                      review: "金で王手をかけると、玉は2一へ逃げました。そこで金を2二へ進めて詰みです。香車が後ろから金を守っていました。玉の逃げ先を先に読むのがコツです。"),
        TutorialStage(7, title: "捨て駒の妙手",
                      board: "9/8k/9/6+R2/9/9/9/9/9", hand: "GP", plies: 3, answer: "１三歩打",
                      lesson: "わざと駒を取らせる手を「捨て駒」といいます。損に見えても、玉を動かして、詰みの形に引っぱり出せます。まず歩を打ってみよう。",
                      review: "歩を玉に取らせて、玉を1三に引っぱり出しました。そこへ金を打つと詰みです。龍が金を守っています。歩は「捨て駒」でした。"),
    ]
}
