import Foundation

enum GamePhase: Codable, Equatable {
    case lobby
    case countdown(remaining: Int)
    case playing
    case elimination(eliminatedPlayerID: String, eliminatedPlayerName: String)
    case playerLeft(playerName: String)
    case gameOver(winnerName: String)
}
