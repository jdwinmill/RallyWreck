import SwiftUI

struct NeonButtonStyle: ButtonStyle {
    var color: Color = NeonTheme.neonCyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NeonTheme.bodyFont)
            .foregroundStyle(.white)
            .padding(.horizontal, NeonTheme.paddingLarge)
            .padding(.vertical, NeonTheme.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: NeonTheme.cornerRadius)
                    .fill(color.opacity(configuration.isPressed ? 0.4 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerRadius)
                    .stroke(color, lineWidth: 2)
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.3 : 0.6), radius: 12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
