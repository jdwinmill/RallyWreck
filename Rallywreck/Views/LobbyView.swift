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

            if let name = gameState.localPlayer?.displayName {
                Button {
                    gameState.localPlayer = nil
                } label: {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(NeonTheme.captionFont)
                            .foregroundStyle(.white)
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                }
            }

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
                    // Bot controls
                    HStack(spacing: 12) {
                        Button("ADD BOT") {
                            gameManager.addBot()
                        }
                        .buttonStyle(NeonButtonStyle(color: NeonTheme.neonYellow))
                        .disabled(gameState.players.count >= 5)

                        Button("REMOVE BOT") {
                            gameManager.removeBot()
                        }
                        .buttonStyle(NeonButtonStyle(color: NeonTheme.neonPink))
                        .disabled(gameManager.botPlayers.isEmpty)
                    }

                    Button("MODE: \(gameState.difficulty.label)") {
                        gameState.difficulty = gameState.difficulty == .standard ? .hard : .standard
                    }
                    .buttonStyle(NeonButtonStyle(color: gameState.difficulty == .hard ? NeonTheme.neonPink : .gray))

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
