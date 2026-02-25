import SwiftUI

struct GameView: View {
    let gameState: GameState
    let gameManager: GameManager
    var multipeerService: MultipeerService?

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                // Player list (compact)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(gameState.players.enumerated()), id: \.element.id) { index, player in
                            CompactPlayerBadge(
                                player: player,
                                color: NeonTheme.playerColor(for: index),
                                isActive: player.id == gameState.activePlayerID
                            )
                        }
                    }
                    .padding(.horizontal, NeonTheme.paddingMedium)
                }
                .padding(.top, 20)

                Spacer()

                // Main game area
                if case .countdown(let remaining) = gameState.phase {
                    countdownView(remaining: remaining)
                } else if gameState.isMyTurn {
                    activeTurnView
                } else if let activeID = gameState.activePlayerID,
                          let activePlayer = gameState.players.first(where: { $0.id == activeID }) {
                    spectatorView(watching: activePlayer)
                }

                // Timer bar
                if case .playing = gameState.phase,
                   let startDate = gameState.turnStartDate {
                    TimerBarView(duration: gameState.turnDuration, startDate: startDate)
                        .padding(.horizontal, NeonTheme.paddingLarge)
                }

                Spacer()
            }

            // Elimination overlay
            if case .elimination(let name) = gameState.phase {
                EliminationOverlay(playerName: name)
            }
        }
    }

    // MARK: - Subviews

    private func countdownView(remaining: Int) -> some View {
        Text("\(remaining)")
            .font(.system(size: 120, weight: .black, design: .rounded))
            .foregroundStyle(NeonTheme.neonCyan)
            .shadow(color: NeonTheme.neonCyan.opacity(0.6), radius: 30)
            .contentTransition(.numericText())
            .animation(.easeInOut, value: remaining)
    }

    private var activeTurnView: some View {
        VStack(spacing: 16) {
            Text("YOUR TURN!")
                .font(NeonTheme.headlineFont)
                .foregroundStyle(NeonTheme.neonGreen)
                .shadow(color: NeonTheme.neonGreen.opacity(0.6), radius: 12)

            Button {
                if let localID = gameState.localPlayer?.id {
                    if gameState.isHost {
                        gameManager.handleTap(playerID: localID)
                    } else {
                        multipeerService?.sendToAll(.tapAction(playerID: localID))
                    }
                }
            } label: {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NeonTheme.neonGreen, NeonTheme.neonGreen.opacity(0.3)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .overlay(
                        Text("TAP!")
                            .font(NeonTheme.titleFont)
                            .foregroundStyle(.white)
                    )
                    .shadow(color: NeonTheme.neonGreen.opacity(0.6), radius: 30)
            }
        }
    }

    private func spectatorView(watching player: Player) -> some View {
        VStack(spacing: 16) {
            Text("WAITING...")
                .font(NeonTheme.headlineFont)
                .foregroundStyle(.gray)

            Text("\(player.displayName.uppercased())'S TURN")
                .font(NeonTheme.bodyFont)
                .foregroundStyle(NeonTheme.neonPink)
        }
    }
}

// MARK: - Compact Player Badge

private struct CompactPlayerBadge: View {
    let player: Player
    let color: Color
    var isActive: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(player.isEliminated ? Color.gray.opacity(0.2) : color.opacity(0.3))
                .overlay(
                    Circle().stroke(
                        player.isEliminated ? Color.gray :
                            isActive ? color : color.opacity(0.5),
                        lineWidth: isActive ? 3 : 1.5
                    )
                )
                .overlay(
                    Text(String(player.displayName.prefix(1)).uppercased())
                        .font(NeonTheme.captionFont)
                        .foregroundStyle(player.isEliminated ? .gray : color)
                )
                .frame(width: 40, height: 40)
                .shadow(color: isActive ? color.opacity(0.8) : .clear, radius: isActive ? 10 : 0)

            Text(player.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(player.isEliminated ? .gray : .white)
                .lineLimit(1)
        }
        .frame(width: 60)
        .opacity(player.isEliminated ? 0.5 : 1.0)
    }
}
