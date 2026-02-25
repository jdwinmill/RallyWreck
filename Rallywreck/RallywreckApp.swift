import SwiftUI

@main
struct RallywreckApp: App {
    @State private var gameState = GameState()
    @State private var multipeerService = MultipeerService()
    @State private var gameManager: GameManager
    @State private var synthEngine = SynthEngine()

    init() {
        let gs = GameState()
        let ms = MultipeerService()
        _gameState = State(initialValue: gs)
        _multipeerService = State(initialValue: ms)
        _gameManager = State(initialValue: GameManager(multipeerService: ms, gameState: gs))
        _synthEngine = State(initialValue: SynthEngine())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                gameState: gameState,
                multipeerService: multipeerService,
                gameManager: gameManager,
                synthEngine: synthEngine
            )
        }
    }
}
