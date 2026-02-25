import SwiftUI

struct LobbyView: View {
    let gameState: GameState
    let gameManager: GameManager
    let multipeerService: MultipeerService

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("LOBBY")
                .font(NeonTheme.headlineFont)
                .foregroundStyle(NeonTheme.neonCyan)
                .shadow(color: NeonTheme.neonCyan.opacity(0.4), radius: 8)
                .padding(.top, 40)

            Text("\(gameState.players.count) PLAYER\(gameState.players.count == 1 ? "" : "S")")
                .font(NeonTheme.captionFont)
                .foregroundStyle(.gray)
                .tracking(2)

            // Player list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(gameState.players.enumerated()), id: \.element.id) { index, player in
                        PlayerAvatarView(
                            player: player,
                            color: NeonTheme.playerColor(for: index),
                            showEliminated: false
                        )
                    }
                }
                .padding(.horizontal, NeonTheme.paddingMedium)
            }

            Spacer()

            // Host controls
            if gameState.isHost {
                VStack(spacing: 12) {
                    // Bot toggle for testing
                    Button(gameManager.botEnabled ? "REMOVE BOT" : "ADD BOT") {
                        if gameManager.botEnabled {
                            gameManager.disableBot()
                        } else {
                            gameManager.enableBot()
                        }
                    }
                    .buttonStyle(NeonButtonStyle(color: NeonTheme.neonYellow))

                    Button("START GAME") {
                        gameManager.startGame()
                    }
                    .buttonStyle(NeonButtonStyle(color: NeonTheme.neonGreen))
                    .disabled(gameState.players.count < 2)
                }
                .padding(.bottom, 40)
            } else {
                Text("Waiting for host to start...")
                    .font(NeonTheme.captionFont)
                    .foregroundStyle(.gray)
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeonTheme.background)
    }
}
