import Foundation

enum GameMessage: Codable {
    // Client -> Host
    case joinRequest(playerName: String, playerID: String)
    case tapAction(playerID: String)

    // Host -> One
    case joinAccepted(yourPlayer: Player, roster: [Player])
    case joinRejected(reason: String)

    // Host -> All
    case lobbyUpdate(roster: [Player])
    case gameCountdown(remaining: Int)
    case turnStart(activePlayerID: String, duration: TimeInterval)
    case playerEliminated(playerID: String, playerName: String)
    case gameOver(winnerID: String, winnerName: String, standings: [Player])
    case returnToLobby(roster: [Player])
}
