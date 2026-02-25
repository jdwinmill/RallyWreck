import SwiftUI

struct HomeView: View {
    let gameState: GameState
    let multipeerService: MultipeerService
    let gameManager: GameManager

    @AppStorage("playerName") private var playerName: String = ""
    @State private var isJoining: Bool = false
    @State private var joinTimeoutTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Text("RALLY")
                    .font(NeonTheme.titleFont)
                    .foregroundStyle(NeonTheme.neonCyan)
                    .shadow(color: NeonTheme.neonCyan.opacity(0.6), radius: 20)

                Text("WRECK")
                    .font(NeonTheme.titleFont)
                    .foregroundStyle(NeonTheme.neonPink)
                    .shadow(color: NeonTheme.neonPink.opacity(0.6), radius: 20)
            }

            // Name entry
            VStack(spacing: 12) {
                Text("ENTER YOUR NAME")
                    .font(NeonTheme.captionFont)
                    .foregroundStyle(.gray)
                    .tracking(2)

                TextField("", text: $playerName, prompt: Text("Player").foregroundStyle(.gray))
                    .font(NeonTheme.bodyFont)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: NeonTheme.cornerRadius)
                            .fill(NeonTheme.surfaceDark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NeonTheme.cornerRadius)
                            .stroke(NeonTheme.surfaceLight, lineWidth: 1)
                    )
                    .padding(.horizontal, 40)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }

            Spacer()

            // Buttons
            VStack(spacing: 16) {
                Button("HOST GAME") {
                    hostGame()
                }
                .buttonStyle(NeonButtonStyle(color: NeonTheme.neonCyan))
                .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)

                if isJoining {
                    Button("CANCEL") {
                        cancelJoin()
                    }
                    .buttonStyle(NeonButtonStyle(color: NeonTheme.neonYellow))
                } else {
                    Button("JOIN GAME") {
                        joinGame()
                    }
                    .buttonStyle(NeonButtonStyle(color: NeonTheme.neonPink))
                    .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if isJoining {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(NeonTheme.neonPink)
                    Text("Waiting for a host to add you...")
                        .font(NeonTheme.captionFont)
                        .foregroundStyle(.gray)
                }
            }

            if let error = gameState.errorMessage {
                Text(error)
                    .font(NeonTheme.captionFont)
                    .foregroundStyle(NeonTheme.neonPink)
                    .onAppear {
                        isJoining = false
                        // Auto-dismiss after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if gameState.errorMessage == error {
                                gameState.errorMessage = nil
                            }
                        }
                    }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeonTheme.background)
    }

    private func hostGame() {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let localPlayer = Player(displayName: name, isHost: true)
        multipeerService.start(displayName: name, asHost: true)
        gameManager.setupAsHost(localPlayer: localPlayer)
    }

    private func joinGame() {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isJoining = true
        gameState.errorMessage = nil
        gameState.isHost = false

        // Create a local player reference for the join request.
        // Do NOT set gameState.localPlayer yet — that triggers navigation
        // to LobbyView. We stay on HomeView until the host sends joinAccepted.
        let localPlayer = Player(displayName: name)

        multipeerService.start(displayName: name, asHost: false)

        // Set up client-side message handling.
        // ClientMessageHandler.joinAccepted will set gameState.localPlayer,
        // which triggers the transition from HomeView → LobbyView.
        let clientHandler = ClientMessageHandler(
            gameState: gameState,
            multipeerService: multipeerService
        )
        clientHandler.setupMessageHandling()

        // When connected to host, send the join request ONCE.
        // MCSession is a mesh — onPeerConnected fires for every peer (host + other clients).
        // We must only send the joinRequest once, then clear the callback so that:
        // 1. We don't re-send when meshing with other clients
        // 2. Other clients' stale callbacks don't re-fire when we mesh with them
        var joinRequestSent = false
        multipeerService.onPeerConnected = { peer in
            guard !joinRequestSent else { return }
            joinRequestSent = true
            isJoining = false
            // Send directly to this peer (the host) — not sendToAll,
            // which would also hit other clients in the mesh.
            multipeerService.send(.joinRequest(
                playerName: localPlayer.displayName,
                playerID: localPlayer.id
            ), to: [peer])
            // Remember the host peer so we only react to HOST disconnects
            multipeerService.hostPeerID = peer
        }

        // Only react to the HOST disconnecting — not other clients in the mesh.
        multipeerService.onPeerDisconnected = { [gameState, multipeerService] peer in
            guard peer == multipeerService.hostPeerID else { return }
            multipeerService.stop()
            gameState.errorMessage = "Host disconnected"
            gameState.localPlayer = nil
            gameState.players = []
            gameState.isHost = false
            gameState.activePlayerID = nil
            gameState.turnStartDate = nil
            gameState.eliminationStandings = []
            gameState.phase = .lobby
        }

        // Timeout after 30 seconds if no host adds us
        joinTimeoutTask?.cancel()
        joinTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            if isJoining {
                multipeerService.stop()
                resetClientState(errorMessage: "No host found. Try again.")
            }
        }
    }

    private func cancelJoin() {
        joinTimeoutTask?.cancel()
        joinTimeoutTask = nil
        multipeerService.stop()
        resetClientState(errorMessage: nil)
    }

    private func resetClientState(errorMessage: String?) {
        isJoining = false
        joinTimeoutTask?.cancel()
        joinTimeoutTask = nil
        gameState.errorMessage = errorMessage
        gameState.localPlayer = nil
        gameState.phase = .lobby
        gameState.players = []
        gameState.isHost = false
        gameState.activePlayerID = nil
        gameState.turnStartDate = nil
        gameState.eliminationStandings = []
    }
}
