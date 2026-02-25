import Foundation

enum GamePhase: Codable, Equatable {
    case lobby
    case countdown(remaining: Int)
    case playing
    case elimination(eliminatedPlayerName: String)
    case playerLeft(playerName: String)
    case gameOver(winnerName: String)
}
