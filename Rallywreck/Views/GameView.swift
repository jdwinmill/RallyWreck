import SwiftUI

struct GameView: View {
    let gameState: GameState
    let gameManager: GameManager
    var multipeerService: MultipeerService?
    let synthEngine: SynthEngine

    @State private var lastCountdown: Int?
    @State private var buttonScale: CGFloat = 1.0
    @State private var buttonPosition: CGPoint = .zero
    @State private var playAreaSize: CGSize = .zero
    @State private var currentButtonSize: CGFloat = 200
    @State private var showExitConfirmation: Bool = false

    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
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
                .overlay(alignment: .trailing) {
                    Button {
                        showExitConfirmation = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.gray)
                            .frame(width: 32, height: 32)
                            .background(NeonTheme.surfaceDark.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, NeonTheme.paddingMedium)
                }

                // Status text
                statusText

                // Play area with moving button
                GeometryReader { geo in
                    ZStack {
                        // Tap button positioned randomly
                        tapButton
                            .position(buttonPosition)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: buttonPosition)

                        // Timer bar at bottom
                        VStack {
                            Spacer()
                            if case .playing = gameState.phase,
                               gameState.isMyTurn,
                               let startDate = gameState.turnStartDate {
                                TimerBarView(duration: gameState.turnDuration, startDate: startDate)
                                    .padding(.horizontal, NeonTheme.paddingLarge)
                            } else {
                                Color.clear.frame(height: 32)
                                    .padding(.horizontal, NeonTheme.paddingLarge)
                            }
                        }
                    }
                    .onAppear {
                        playAreaSize = geo.size
                        buttonPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .onChange(of: geo.size) { _, newSize in
                        playAreaSize = newSize
                    }
                }
            }

            // Elimination overlay
            if case .elimination(let name) = gameState.phase {
                EliminationOverlay(playerName: name)
                    .onAppear {
                        Haptics.elimination()
                        synthEngine.playElimination()
                    }
            }

            // Player left overlay
            if case .playerLeft(let name) = gameState.phase {
                PlayerLeftOverlay(playerName: name)
                    .onAppear {
                        Haptics.elimination()
                    }
            }
        }
        .onAppear {
            synthEngine.start()
        }
        .onChange(of: countdownValue) { _, newValue in
            if let v = newValue {
                lastCountdown = v
                Haptics.countdown()
                synthEngine.playCountdown(remaining: v)
            }
        }
        .onChange(of: gameState.activePlayerID) { _, _ in
            currentButtonSize = gameState.difficulty.buttonSize()
            randomizeButtonPosition()
        }
        .onChange(of: gameState.isMyTurn) { _, isMyTurn in
            if isMyTurn {
                Haptics.yourTurn()
                synthEngine.playYourTurn()
            }
        }
        .alert("Leave Game?", isPresented: $showExitConfirmation) {
            Button("Leave", role: .destructive) {
                exitGame()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(gameState.isHost ? "This will end the game for everyone." : "You will be removed from the game.")
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
            synthEngine.playTap()
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
                        startRadius: currentButtonSize * 0.1,
                        endRadius: currentButtonSize * 0.5
                    )
                )
                .frame(width: currentButtonSize, height: currentButtonSize)
                .overlay(
                    Circle()
                        .stroke(
                            isActive ? NeonTheme.neonGreen.opacity(0.8) : NeonTheme.surfaceLight,
                            lineWidth: isActive ? 3 : 1.5
                        )
                )
                .overlay(
                    Group {
                        if isActive {
                            Text("TAP!")
                                .font(.system(size: currentButtonSize * 0.2, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                )
                .shadow(color: isActive ? NeonTheme.neonGreen.opacity(0.6) : .clear, radius: isActive ? 30 : 0)
                .scaleEffect(buttonScale)
        }
        .disabled(!isActive)
        .opacity((!isActive && gameState.difficulty.hidesInactiveButton) ? 0 : 1)
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }

    private func exitGame() {
        if gameState.isHost {
            gameManager.returnToLobby()
            // Delay disconnect so returnToLobby message can be delivered
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                multipeerService?.stop()
                gameState.localPlayer = nil
                gameState.phase = .lobby
            }
        } else {
            multipeerService?.stop()
            gameState.localPlayer = nil
            gameState.players = []
            gameState.activePlayerID = nil
            gameState.turnStartDate = nil
            gameState.eliminationStandings = []
            gameState.phase = .lobby
        }
    }

    private func randomizeButtonPosition() {
        let margin: CGFloat = 120
        let minX = margin
        let maxX = max(margin, playAreaSize.width - margin)
        let minY = margin
        let maxY = max(margin, playAreaSize.height - margin)
        buttonPosition = CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )
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
