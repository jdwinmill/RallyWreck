import SwiftUI

struct GameOverView: View {
    let gameState: GameState
    let gameManager: GameManager
    let winnerName: String

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Winner announcement
            VStack(spacing: 12) {
                Text("WINNER!")
                    .font(NeonTheme.titleFont)
                    .foregroundStyle(NeonTheme.neonGreen)
                    .shadow(color: NeonTheme.neonGreen.opacity(0.8), radius: 24)

                Text(winnerName.uppercased())
                    .font(NeonTheme.headlineFont)
                    .foregroundStyle(.white)
            }

            // Standings
            VStack(spacing: 4) {
                Text("STANDINGS")
                    .font(NeonTheme.captionFont)
                    .foregroundStyle(.gray)
                    .tracking(2)
                    .padding(.bottom, 8)

                let standings = gameState.eliminationStandings
                ForEach(Array(standings.reversed().enumerated()), id: \.element.id) { index, player in
                    HStack {
                        Text("#\(index + 1)")
                            .font(NeonTheme.bodyFont)
                            .foregroundStyle(index == 0 ? NeonTheme.neonGreen : .gray)
                            .frame(width: 40)

                        Text(player.displayName)
                            .font(NeonTheme.bodyFont)
                            .foregroundStyle(index == 0 ? .white : .gray)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, NeonTheme.paddingMedium)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // Actions
            if gameState.isHost {
                VStack(spacing: 12) {
                    Button("PLAY AGAIN") {
                        gameManager.returnToLobby()
                    }
                    .buttonStyle(NeonButtonStyle(color: NeonTheme.neonGreen))
                }
                .padding(.bottom, 40)
            } else {
                Text("Waiting for host...")
                    .font(NeonTheme.captionFont)
                    .foregroundStyle(.gray)
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeonTheme.background)
    }
}
