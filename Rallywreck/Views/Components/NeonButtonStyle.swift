import SwiftUI

struct NeonButtonStyle: ButtonStyle {
    var color: Color = NeonTheme.neonCyan
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NeonTheme.bodyFont)
            .foregroundStyle(isEnabled ? .white : .gray.opacity(0.4))
            .padding(.horizontal, NeonTheme.paddingLarge)
            .padding(.vertical, NeonTheme.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: NeonTheme.cornerRadius)
                    .fill(color.opacity(isEnabled ? (configuration.isPressed ? 0.4 : 0.2) : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerRadius)
                    .stroke(isEnabled ? color : color.opacity(0.2), lineWidth: 2)
            )
            .shadow(color: isEnabled ? color.opacity(configuration.isPressed ? 0.3 : 0.6) : .clear, radius: 12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
