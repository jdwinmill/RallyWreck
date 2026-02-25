import SwiftUI

struct LobbyView: View {
    let gameState: GameState
    let gameManager: GameManager
    let multipeerService: MultipeerService

    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("LOBBY")
                .font(NeonTheme.headlineFont)
                .foregroundStyle(NeonTheme.neonCyan)
                .shadow(color: NeonTheme.neonCyan.opacity(0.4), radius: 8)
                .padding(.top, 40)

            HStack(spacing: 8) {
                Text("\(gameState.players.count) PLAYER\(gameState.players.count == 1 ? "" : "S")")
                    .font(NeonTheme.captionFont)
                    .foregroundStyle(.gray)
                    .tracking(2)

                if !gameState.isHost {
                    Text("·")
                        .foregroundStyle(.gray)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(multipeerService.isConnected ? NeonTheme.neonGreen : NeonTheme.neonPink)
                            .frame(width: 6, height: 6)
                        Text(multipeerService.isConnected ? "CONNECTED" : "DISCONNECTED")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(multipeerService.isConnected ? NeonTheme.neonGreen : NeonTheme.neonPink)
                    }
                }
            }

            // Player list with pull-to-refresh
            List {
                ForEach(Array(gameState.players.enumerated()), id: \.element.id) { index, player in
                    PlayerAvatarView(
                        player: player,
                        color: NeonTheme.playerColor(for: index),
                        showEliminated: false
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable {
                await refreshLobby()
            }

            Spacer()

            // Host controls
            if gameState.isHost {
                VStack(spacing: 12) {
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
                        gameState.difficulty = gameState.difficulty.next()
                    }
                    .buttonStyle(NeonButtonStyle(color: difficultyColor))

                    Button("START GAME") {
                        gameManager.startGame()
                    }
                    .buttonStyle(NeonButtonStyle(color: NeonTheme.neonGreen))
                    .disabled(gameState.players.count < 2)
                }
                .padding(.bottom, 40)
            } else {
                VStack(spacing: 8) {
                    Text("Waiting for host to start...")
                        .font(NeonTheme.captionFont)
                        .foregroundStyle(.gray)

                    Text("Pull down to refresh")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeonTheme.background)
    }

    private var difficultyColor: Color {
        switch gameState.difficulty {
        case .easy: NeonTheme.neonGreen
        case .standard: .gray
        case .medium: NeonTheme.neonYellow
        case .hard: NeonTheme.neonPink
        }
    }

    private func refreshLobby() async {
        isRefreshing = true
        if gameState.isHost {
            // Host: nothing specific to refresh, roster is authoritative
        } else {
            // Client: restart browsing to find host again if disconnected
            if !multipeerService.isConnected {
                multipeerService.restartBrowsing()
            }
        }
        // Small delay for visual feedback
        try? await Task.sleep(for: .milliseconds(800))
        isRefreshing = false
    }
}
