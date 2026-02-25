import SwiftUI

@main
struct RallywreckApp: App {
    @State private var gameState = GameState()
    @State private var multipeerService = MultipeerService()
    @State private var gameManager: GameManager?
    @State private var synthEngine = SynthEngine()

    var body: some Scene {
        WindowGroup {
            ContentView(
                gameState: gameState,
                multipeerService: multipeerService,
                gameManager: gameManager ?? GameManager(
                    multipeerService: multipeerService,
                    gameState: gameState
                ),
                synthEngine: synthEngine
            )
            .onAppear {
                if gameManager == nil {
                    gameManager = GameManager(
                        multipeerService: multipeerService,
                        gameState: gameState
                    )
                }
            }
        }
    }
}
