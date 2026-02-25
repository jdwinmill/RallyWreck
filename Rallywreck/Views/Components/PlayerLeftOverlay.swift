import SwiftUI

struct PlayerLeftOverlay: View {
    let playerName: String

    var body: some View {
        VStack(spacing: 16) {
            Text("LEFT GAME")
                .font(NeonTheme.titleFont)
                .foregroundStyle(NeonTheme.neonYellow)
                .shadow(color: NeonTheme.neonYellow.opacity(0.8), radius: 20)

            Text(playerName.uppercased())
                .font(NeonTheme.headlineFont)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
        .transition(.opacity)
    }
}
