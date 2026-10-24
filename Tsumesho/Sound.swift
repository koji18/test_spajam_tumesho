import AVFoundation

/// 効果音。音量は設定で変えられ、0 なら鳴らさない
@MainActor
enum Sound {
    private static var matePlayer: AVAudioPlayer?

    /// 起動時に一度呼ぶ。ゲームの効果音として扱い、マナーモードのときは鳴らさず、音楽などは止めずに重ねて鳴らす
    static func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        guard let url = Bundle.main.url(forResource: "mate", withExtension: "wav") else { return }
        matePlayer = try? AVAudioPlayer(contentsOf: url)
        matePlayer?.prepareToPlay()
    }

    /// 詰んだときの音を volume（0〜1）で鳴らす。鳴っている途中なら頭から鳴らし直す
    static func playMate(volume: Double) {
        guard volume > 0, let player = matePlayer else { return }
        player.volume = Float(min(1, volume))
        player.currentTime = 0
        player.play()
    }
}
