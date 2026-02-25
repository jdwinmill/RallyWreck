import Foundation
import Observation

@Observable
final class GameState {
    var phase: GamePhase = .lobby
    var players: [Player] = []
    var localPlayer: Player?
    var isHost: Bool = false
    var activePlayerID: String?
    var turnDuration: TimeInterval = 3.0
    var turnStartDate: Date?
    var eliminationStandings: [Player] = []

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
