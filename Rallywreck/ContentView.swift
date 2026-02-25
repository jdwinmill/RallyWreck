import SwiftUI

struct ContentView: View {
    let gameState: GameState
    let multipeerService: MultipeerService
    let gameManager: GameManager
    let synthEngine: SynthEngine

    var body: some View {
        Group {
            switch gameState.phase {
            case .lobby:
                if gameState.localPlayer == nil {
                    HomeView(
                        gameState: gameState,
                        multipeerService: multipeerService,
                        gameManager: gameManager
                    )
                } else {
                    LobbyView(
                        gameState: gameState,
                        gameManager: gameManager,
                        multipeerService: multipeerService
                    )
                }

            case .countdown, .playing, .elimination:
                GameView(
                    gameState: gameState,
                    gameManager: gameManager,
                    multipeerService: multipeerService,
                    synthEngine: synthEngine
                )

            case .gameOver(let winnerName):
                GameOverView(
                    gameState: gameState,
                    gameManager: gameManager,
                    winnerName: winnerName,
                    synthEngine: synthEngine
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phaseCategory)
        .preferredColorScheme(.dark)
    }

    private var phaseCategory: String {
        switch gameState.phase {
        case .lobby: return gameState.localPlayer == nil ? "home" : "lobby"
        case .countdown: return "game"
        case .playing: return "game"
        case .elimination: return "game"
        case .gameOver: return "gameOver"
        }
    }
}
