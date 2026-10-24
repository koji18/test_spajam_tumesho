import AVFoundation

/// BGM。遊んでいるあいだだけ、モードに合った曲をくり返し流す。音量は効果音とは別に設定で変えられ、0 なら流さない
@MainActor
enum Music {
    enum Track: String {
        case calm = "bgm_calm"       // 80・ロ短調。入門と修行
        case normal = "bgm_normal"   // 180・ロ短調。ノーマル
        case hyper = "bgm_hyper"     // 160・ニ長調。タイムトライアル

        init(mode: PlayMode) {
            switch mode {
            case .tutorial, .zen: self = .calm
            case .normal: self = .normal
            case .timeTrial: self = .hyper
            }
        }
    }

    /// BGM の大きさ。効果音が埋もれないように、設定の音量より控えめにする
    static let gain = 0.5
    /// 曲を切り替えるときに、前の曲を消していく時間
    private static let fade: TimeInterval = 0.6

    private static var player: AVAudioPlayer?
    private static var current: Track?

    /// track を volume（0〜1）で流す。nil か音量 0 なら止める。同じ曲なら頭に戻さず、音量だけ合わせる
    static func play(_ track: Track?, volume: Double) {
        guard let track, volume > 0 else { stop(); return }
        let target = Float(min(1, volume * gain))
        if track == current, let player {
            player.setVolume(target, fadeDuration: 0.2)
            if !player.isPlaying { player.play() }
            return
        }
        stop()
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "m4a"),
              let next = try? AVAudioPlayer(contentsOf: url) else { return }
        next.numberOfLoops = -1
        next.volume = 0
        next.play()
        next.setVolume(target, fadeDuration: fade)
        player = next
        current = track
    }

    /// 少しずつ消してから止める
    static func stop() {
        guard let old = player else { return }
        player = nil
        current = nil
        old.setVolume(0, fadeDuration: fade)
        Task {
            try? await Task.sleep(for: .seconds(fade))
            old.stop()
        }
    }
}
