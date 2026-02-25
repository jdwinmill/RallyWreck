import Foundation
import MultipeerConnectivity

/// Handles incoming host messages on non-host (client) devices
struct ClientMessageHandler {
    let gameState: GameState
    let multipeerService: MultipeerService

    func setupMessageHandling() {
        multipeerService.onMessageReceived = { [gameState] message, _ in
            handleMessage(message, gameState: gameState)
        }
    }

    private func handleMessage(_ message: GameMessage, gameState: GameState) {
        switch message {
        case .joinAccepted(let yourPlayer, let roster):
            gameState.localPlayer = yourPlayer
            gameState.players = roster

        case .joinRejected(let reason):
            gameState.errorMessage = reason
            gameState.localPlayer = nil
            gameState.phase = .lobby

        case .lobbyUpdate(let roster):
            gameState.players = roster

        case .gameStart(let difficulty):
            if let diff = Difficulty(rawValue: difficulty) {
                gameState.difficulty = diff
            }

        case .gameCountdown(let remaining):
            gameState.phase = .countdown(remaining: remaining)

        case .turnStart(let activePlayerID, let duration):
            gameState.phase = .playing
            gameState.activePlayerID = activePlayerID
            gameState.turnDuration = duration
            gameState.turnStartDate = Date()

        case .playerEliminated(let playerID, let playerName):
            if let index = gameState.players.firstIndex(where: { $0.id == playerID }) {
                gameState.players[index].isEliminated = true
                gameState.eliminationStandings.insert(gameState.players[index], at: 0)
            }
            gameState.phase = .elimination(eliminatedPlayerName: playerName)

        case .gameOver(_, let winnerName, let standings):
            gameState.eliminationStandings = standings
            gameState.phase = .gameOver(winnerName: winnerName)

        case .returnToLobby(let roster):
            gameState.players = roster
            for i in gameState.players.indices {
                gameState.players[i].isEliminated = false
            }
            gameState.activePlayerID = nil
            gameState.turnStartDate = nil
            gameState.eliminationStandings = []
            gameState.phase = .lobby

        default:
            break
        }
    }
}
