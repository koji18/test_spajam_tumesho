import Foundation
import Observation

// ノーマルでミスした問題だけを保存する。解けたあとも反復練習用に残す。
@MainActor @Observable
final class PracticeLibrary {
    struct Entry: Codable, Identifiable {
        let problem: Problem
        var mistakes: Int
        var lastMistakeAt: Date

        // 通し番号はアプリの起動ごとに重なるため、局面そのものを識別子にする。
        var id: String { Self.key(for: problem) }

        static func key(for problem: Problem) -> String {
            "\(problem.size.rawValue)|\(problem.plies)|\(problem.board)|\(problem.hand)"
        }
    }

    private let store: UserDefaults
    private static let storageKey = "zenPractice.v1"
    private(set) var entries: [Entry]

    init(store: UserDefaults = .standard) {
        self.store = store
        entries = store.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
    }

    func recordMistake(_ problem: Problem, mode: PlayMode) {
        guard mode == .normal else { return }
        let key = Entry.key(for: problem)
        if let index = entries.firstIndex(where: { $0.id == key }) {
            entries[index].mistakes += 1
            entries[index].lastMistakeAt = Date()
        } else {
            entries.append(Entry(problem: problem, mistakes: 1, lastMistakeAt: Date()))
        }
        if let data = try? JSONEncoder().encode(entries) {
            store.set(data, forKey: Self.storageKey)
        }
    }

    func problems(size: BoardSize) -> [Problem] {
        entries.filter { $0.problem.size == size }
            .sorted {
                if $0.mistakes != $1.mistakes { return $0.mistakes > $1.mistakes }
                if $0.lastMistakeAt != $1.lastMistakeAt { return $0.lastMistakeAt > $1.lastMistakeAt }
                return $0.id < $1.id
            }
            .map(\.problem)
    }
}
