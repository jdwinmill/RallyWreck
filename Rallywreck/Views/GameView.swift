import SwiftUI

struct GameView: View {
    let gameState: GameState
    let gameManager: GameManager
    var multipeerService: MultipeerService?

    @State private var lastCountdown: Int?
    @State private var buttonScale: CGFloat = 1.0

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

                // Status text above button
                statusText

                // Always-visible tap button
                tapButton

                // Timer bar
                if case .playing = gameState.phase,
                   let startDate = gameState.turnStartDate {
                    TimerBarView(duration: gameState.turnDuration, startDate: startDate)
                        .padding(.horizontal, NeonTheme.paddingLarge)
                } else {
                    // Reserve space so layout doesn't shift
                    Color.clear.frame(height: 32)
                        .padding(.horizontal, NeonTheme.paddingLarge)
                }

                Spacer()
            }

            // Elimination overlay
            if case .elimination(let name) = gameState.phase {
                EliminationOverlay(playerName: name)
                    .onAppear {
                        Haptics.elimination()
                    }
            }
        }
        .onChange(of: countdownValue) { _, newValue in
            if let v = newValue {
                lastCountdown = v
                Haptics.countdown()
            }
        }
        .onChange(of: gameState.isMyTurn) { _, isMyTurn in
            if isMyTurn {
                Haptics.yourTurn()
            }
        }
    }

    // MARK: - Status Text

    @ViewBuilder
    private var statusText: some View {
        if case .countdown(let remaining) = gameState.phase {
            Text("\(remaining)")
                .font(.system(size: 100, weight: .black, design: .rounded))
                .foregroundStyle(NeonTheme.neonCyan)
                .shadow(color: NeonTheme.neonCyan.opacity(0.6), radius: 30)
                .contentTransition(.numericText())
                .animation(.easeInOut, value: remaining)
        } else if gameState.isMyTurn {
            Text("YOUR TURN!")
                .font(NeonTheme.headlineFont)
                .foregroundStyle(NeonTheme.neonGreen)
                .shadow(color: NeonTheme.neonGreen.opacity(0.6), radius: 12)
        } else if let activeID = gameState.activePlayerID,
                  let activePlayer = gameState.players.first(where: { $0.id == activeID }) {
            VStack(spacing: 4) {
                Text("\(activePlayer.displayName.uppercased())'S TURN")
                    .font(NeonTheme.bodyFont)
                    .foregroundStyle(NeonTheme.neonPink)
            }
        } else {
            Text(" ")
                .font(NeonTheme.headlineFont)
        }
    }

    // MARK: - Tap Button (always visible)

    private var tapButton: some View {
        let isActive = gameState.isMyTurn && isPlayingPhase

        return Button {
            guard isActive, let localID = gameState.localPlayer?.id else { return }
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.1)) { buttonScale = 0.85 }
            withAnimation(.easeOut(duration: 0.1).delay(0.1)) { buttonScale = 1.0 }

            if gameState.isHost {
                gameManager.handleTap(playerID: localID)
            } else {
                multipeerService?.sendToAll(.tapAction(playerID: localID))
            }
        } label: {
            Circle()
                .fill(
                    RadialGradient(
                        colors: isActive
                            ? [NeonTheme.neonGreen, NeonTheme.neonGreen.opacity(0.3)]
                            : [NeonTheme.surfaceLight, NeonTheme.surfaceDark],
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    Circle()
                        .stroke(
                            isActive ? NeonTheme.neonGreen.opacity(0.8) : NeonTheme.surfaceLight,
                            lineWidth: isActive ? 3 : 1.5
                        )
                )
                .overlay(
                    Text("TAP!")
                        .font(NeonTheme.titleFont)
                        .foregroundStyle(isActive ? .white : .gray.opacity(0.3))
                )
                .shadow(color: isActive ? NeonTheme.neonGreen.opacity(0.6) : .clear, radius: isActive ? 30 : 0)
                .scaleEffect(buttonScale)
        }
        .disabled(!isActive)
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }

    private var isPlayingPhase: Bool {
        if case .playing = gameState.phase { return true }
        return false
    }

    private var countdownValue: Int? {
        if case .countdown(let r) = gameState.phase { return r }
        return nil
    }
}

// MARK: - Haptics

enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func tap() {
        impact.impactOccurred(intensity: 1.0)
    }

    static func yourTurn() {
        notification.notificationOccurred(.warning)
    }

    static func countdown() {
        rigid.impactOccurred(intensity: 0.8)
    }

    static func elimination() {
        notification.notificationOccurred(.error)
        // Double buzz for dramatic effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            impact.impactOccurred(intensity: 1.0)
        }
    }

    static func gameOver() {
        notification.notificationOccurred(.success)
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
