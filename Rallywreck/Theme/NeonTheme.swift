import SwiftUI

enum NeonTheme {
    // MARK: - Colors
    static let background = Color(red: 0.05, green: 0.02, blue: 0.12)
    static let neonPink = Color(red: 1.0, green: 0.0, blue: 0.6)
    static let neonCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    static let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.4)
    static let neonYellow = Color(red: 1.0, green: 0.95, blue: 0.0)
    static let neonOrange = Color(red: 1.0, green: 0.5, blue: 0.0)
    static let neonRed = Color(red: 1.0, green: 0.15, blue: 0.15)
    static let surfaceDark = Color(red: 0.1, green: 0.06, blue: 0.18)
    static let surfaceLight = Color(red: 0.15, green: 0.1, blue: 0.25)

    static let playerColors: [Color] = [neonCyan, neonPink, neonGreen, neonYellow, neonOrange]

    static func playerColor(for index: Int) -> Color {
        playerColors[index % playerColors.count]
    }

    // MARK: - Fonts
    static let titleFont: Font = .system(size: 48, weight: .black, design: .rounded)
    static let headlineFont: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let bodyFont: Font = .system(size: 18, weight: .semibold, design: .rounded)
    static let captionFont: Font = .system(size: 14, weight: .medium, design: .rounded)

    // MARK: - Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let cornerRadius: CGFloat = 16
}
