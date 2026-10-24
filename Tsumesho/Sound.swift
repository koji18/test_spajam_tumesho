import AVFoundation

/// 効果音。音量は設定で変えられ、0 なら鳴らさない
@MainActor
enum Sound {
    private static var pickPlayer: AVAudioPlayer?
    // 詰みの音は、連勝に合わせて高さを変える。AVAudioPlayer の rate は高さを保ったまま速さだけ変えるので、
    // 速さと高さを一緒に変える Varispeed を通して鳴らす
    private static let engine = AVAudioEngine()
    private static let mateNode = AVAudioPlayerNode()
    private static let varispeed = AVAudioUnitVarispeed()
    private static var mateBuffer: AVAudioPCMBuffer?

    /// 起動時に一度呼ぶ。ゲームの効果音として扱い、マナーモードのときは鳴らさず、音楽などは止めずに重ねて鳴らす
    static func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        pickPlayer = load("pick")
        prepareMate()
    }

    /// mate.wav を読み込み、プレイヤー → Varispeed → ミキサーとつないでおく
    private static func prepareMate() {
        guard let url = Bundle.main.url(forResource: "mate", withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return }
        mateBuffer = buffer
        engine.attach(mateNode)
        engine.attach(varispeed)
        engine.connect(mateNode, to: varispeed, format: buffer.format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: buffer.format)
        engine.prepare()
    }

    /// 画面を離れたときと、バックグラウンドへ移ったときに止める。
    static func stop() {
        mateNode.stop()
        if engine.isRunning { engine.pause() }
        pickPlayer?.stop()
    }

    /// Sounds/ に入れた wav を読み込んで、すぐ鳴らせるようにしておく
    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    /// 詰みの音の高さを、連勝ごとにドレミファソラシドの音階で上げる（元の高さから半音いくつ分か）。
    /// 1 連勝がド、8 連勝で 1 オクターブ上のドになり、そこで頭打ち
    static let mateScale = [0, 2, 4, 5, 7, 9, 11, 12]

    /// 連勝 streak のときの詰みの音の速さ。速く鳴らして高くするので、高いほど音は少し短くなる
    static func mateRate(streak: Int) -> Float {
        let step = min(max(streak - 1, 0), mateScale.count - 1)
        return Float(pow(2, Double(mateScale[step]) / 12))
    }

    /// 詰んだときの音を volume（0〜1）で鳴らす。連勝 streak が続くほど高くする。鳴っている途中なら頭から鳴らし直す
    static func playMate(volume: Double, streak: Int) {
        guard volume > 0, let buffer = mateBuffer else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        mateNode.stop()
        varispeed.rate = mateRate(streak: streak)
        mateNode.volume = Float(min(1, volume))
        mateNode.scheduleBuffer(buffer, at: nil)
        mateNode.play()
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
