import Foundation
import Observation

enum Difficulty: String, CaseIterable {
    case easy, standard, medium, hard

    var label: String {
        switch self {
        case .easy: "EASY"
        case .standard: "STANDARD"
        case .medium: "MEDIUM"
        case .hard: "HARD"
        }
    }

    static let varyingSizes: [CGFloat] = [200, 150, 110, 80]

    func buttonSize() -> CGFloat {
        switch self {
        case .easy: 240
        case .standard: 200
        case .medium, .hard: Self.varyingSizes.randomElement()!
        }
    }

    var hidesInactiveButton: Bool { self == .hard }

    var startingDuration: TimeInterval {
        switch self {
        case .easy: 5.0
        case .standard: 3.0
        case .medium: 3.0
        case .hard: 3.0
        }
    }

    var shrinkFactor: Double {
        switch self {
        case .easy: 0.97
        case .standard: 0.92
        case .medium: 0.92
        case .hard: 0.92
        }
    }

    var minimumDuration: TimeInterval {
        switch self {
        case .easy: 1.5
        case .standard: 0.5
        case .medium: 0.5
        case .hard: 0.5
        }
    }

    /// Bot reaction range (fraction of turn duration)
    var botReactionRange: ClosedRange<Double> {
        switch self {
        case .easy: 0.5...0.95
        case .standard: 0.3...0.8
        case .medium: 0.3...0.8
        case .hard: 0.3...0.8
        }
    }

    func next() -> Difficulty {
        let all = Difficulty.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

@Observable
final class GameState {
    var phase: GamePhase = .lobby
    var difficulty: Difficulty = .standard
    var players: [Player] = []
    var localPlayer: Player?
    var isHost: Bool = false
    var activePlayerID: String?
    var turnDuration: TimeInterval = 3.0
    var turnStartDate: Date?
    var eliminationStandings: [Player] = []
    var errorMessage: String?

    var isMyTurn: Bool {
        guard let localPlayer else { return false }
        return activePlayerID == localPlayer.id && !localPlayer.isEliminated
    }

    var activePlayers: [Player] {
        players.filter { !$0.isEliminated }
    }

    func reset() {
        phase = .lobby
        for i in players.indices {
            players[i].isEliminated = false
        }
        activePlayerID = nil
        turnDuration = 3.0
        turnStartDate = nil
        eliminationStandings = []
    }
}
