import SwiftUI

struct EliminationOverlay: View {
    let playerName: String

    var body: some View {
        VStack(spacing: 16) {
            Text("WRECKED!")
                .font(NeonTheme.titleFont)
                .foregroundStyle(NeonTheme.neonRed)
                .shadow(color: NeonTheme.neonRed.opacity(0.8), radius: 20)

            Text("\(playerName.uppercased()) IS OUT")
                .font(NeonTheme.headlineFont)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
        .transition(.opacity)
    }
}
