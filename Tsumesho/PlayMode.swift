enum PlayMode: String, CaseIterable {
    case normal
    case timeTrial
    case zen

    var title: String {
        switch self {
        case .normal: "NORMAL"
        case .timeTrial: "TIME TRIAL"
        case .zen: "修行"
        }
    }

    var label: String {
        switch self {
        case .normal: "ノーマル"
        case .timeTrial: "タイムトライアル"
        case .zen: "修行"
        }
    }

    var awardsScore: Bool { self != .zen }
}
