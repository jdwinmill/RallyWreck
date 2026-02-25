import SwiftUI

struct TimerBarView: View {
    let duration: TimeInterval
    let startDate: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let progress = max(0, min(1, 1.0 - elapsed / duration))
            let barColor = timerColor(for: progress)

            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(NeonTheme.surfaceDark)

                        // Filled portion
                        RoundedRectangle(cornerRadius: 6)
                            .fill(barColor)
                            .frame(width: geo.size.width * progress)
                            .shadow(color: barColor.opacity(0.6), radius: 8)
                    }
                }
                .frame(height: 12)

                Text(String(format: "%.1f", max(0, duration - elapsed)))
                    .font(NeonTheme.captionFont)
                    .foregroundStyle(barColor)
                    .monospacedDigit()
            }
        }
    }

    private func timerColor(for progress: Double) -> Color {
        if progress > 0.5 {
            return NeonTheme.neonGreen
        } else if progress > 0.25 {
            return NeonTheme.neonYellow
        } else {
            return NeonTheme.neonRed
        }
    }
}
