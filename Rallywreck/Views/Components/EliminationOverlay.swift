import SwiftUI

struct EliminationOverlay: View {
    let playerName: String
    let isLocalPlayer: Bool

    @State private var showWrecked = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if !showWrecked {
                Text("TIME'S UP!")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(NeonTheme.neonYellow)
                    .shadow(color: NeonTheme.neonYellow.opacity(0.8), radius: 20)
                    .transition(.opacity)
            } else {
                Text("YOU'RE\nWRECKED!")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NeonTheme.neonRed)
                    .shadow(color: NeonTheme.neonRed.opacity(0.8), radius: 20)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
        .transition(.opacity)
        .onAppear {
            animationTask = Task {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showWrecked = true
                }
            }
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }
}
