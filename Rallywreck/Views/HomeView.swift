import SwiftUI

struct HomeView: View {
    let gameState: GameState
    let multipeerService: MultipeerService
    let gameManager: GameManager

    @AppStorage("playerName") private var playerName: String = ""
    @State private var isJoining: Bool = false

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
                .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("JOIN GAME") {
                    joinGame()
                }
                .buttonStyle(NeonButtonStyle(color: NeonTheme.neonPink))
                .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if isJoining {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(NeonTheme.neonPink)
                    Text("Searching for host...")
                        .font(NeonTheme.captionFont)
                        .foregroundStyle(.gray)
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
        let localPlayer = Player(displayName: name)
        gameState.localPlayer = localPlayer
        gameState.isHost = false
        multipeerService.start(displayName: name, asHost: false)

        // Set up client-side message handling
        let clientHandler = ClientMessageHandler(
            gameState: gameState,
            multipeerService: multipeerService
        )
        clientHandler.setupMessageHandling()

        // When connected, send join request
        multipeerService.onPeerConnected = { _ in
            multipeerService.sendToAll(.joinRequest(
                playerName: localPlayer.displayName,
                playerID: localPlayer.id
            ))
        }
    }
}
