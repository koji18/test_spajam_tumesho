import AVFoundation

/// 効果音。音量は設定で変えられ、0 なら鳴らさない
@MainActor
enum Sound {
    private static var matePlayer: AVAudioPlayer?
    private static var pickPlayer: AVAudioPlayer?

    /// 起動時に一度呼ぶ。ゲームの効果音として扱い、マナーモードのときは鳴らさず、音楽などは止めずに重ねて鳴らす
    static func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        matePlayer = load("mate", changesPitch: true)
        pickPlayer = load("pick")
    }

    /// 画面を離れたときと、バックグラウンドへ移ったときに止める。
    static func stop() {
        matePlayer?.stop()
        pickPlayer?.stop()
    }

    /// Sounds/ に入れた wav を読み込んで、すぐ鳴らせるようにしておく。changesPitch なら、鳴らす速さ（音の高さ）を変えられるようにする
    private static func load(_ name: String, changesPitch: Bool = false) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.enableRate = changesPitch
        player.prepareToPlay()
        return player
    }

    /// 詰みの音を上げる上限（半音いくつ分か）。9 連勝で頭打ちになる
    static let maxMateSemitones = 8

    /// 連勝 streak のときの詰みの音の速さ。1 連勝は元の高さで、連勝が 1 つ増えるごとに半音ずつ上げる。
    /// 速く鳴らして高くするので、高いほど音は少し短くなる
    static func mateRate(streak: Int) -> Float {
        let semitones = min(max(streak - 1, 0), maxMateSemitones)
        return Float(pow(2, Double(semitones) / 12))
    }

    /// 詰んだときの音を volume（0〜1）で鳴らす。連勝 streak が続くほど高くする
    static func playMate(volume: Double, streak: Int) {
        matePlayer?.rate = mateRate(streak: streak)
        play(matePlayer, volume: volume)
    }

    /// 選ぶ音の大きさ。何度も鳴る音なので、設定の音量より控えめにする
    static let pickGain = 0.5

    /// 駒や持ち駒、ボタンを押したときの音を鳴らす。設定の音量 volume（0〜1）に pickGain をかける。
    /// 設定で音量を確かめるときもこの音
    static func playPick(volume: Double) {
        play(pickPlayer, volume: volume * pickGain)
    }

    /// 鳴っている途中なら頭から鳴らし直す
    private static func play(_ player: AVAudioPlayer?, volume: Double) {
        guard volume > 0, let player else { return }
        player.volume = Float(min(1, volume))
        player.currentTime = 0
        player.play()
    }
}
