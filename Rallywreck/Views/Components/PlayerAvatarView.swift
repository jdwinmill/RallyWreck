import SwiftUI

struct PlayerAvatarView: View {
    let player: Player
    let color: Color
    var isActive: Bool = false
    var showEliminated: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(player.isEliminated ? Color.gray.opacity(0.3) : color.opacity(0.3))
                .overlay(
                    Circle().stroke(player.isEliminated ? Color.gray : color, lineWidth: 2)
                )
                .overlay(
                    Text(String(player.displayName.prefix(1)).uppercased())
                        .font(NeonTheme.bodyFont)
                        .foregroundStyle(player.isEliminated ? .gray : color)
                )
                .frame(width: 44, height: 44)
                .shadow(color: isActive ? color.opacity(0.8) : .clear, radius: isActive ? 12 : 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(NeonTheme.bodyFont)
                    .foregroundStyle(player.isEliminated ? .gray : .white)

                if player.isHost {
                    Text("HOST")
                        .font(NeonTheme.captionFont)
                        .foregroundStyle(NeonTheme.neonYellow)
                }
            }

            Spacer()

            if player.isEliminated && showEliminated {
                Text("OUT")
                    .font(NeonTheme.captionFont)
                    .foregroundStyle(NeonTheme.neonRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(NeonTheme.neonRed.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, NeonTheme.paddingMedium)
        .padding(.vertical, NeonTheme.paddingSmall)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? color.opacity(0.1) : Color.clear)
        )
    }
}
