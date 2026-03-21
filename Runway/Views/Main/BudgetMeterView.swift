import SwiftUI

struct BudgetMeterView: View {
    let percentRemaining: Double   // 0.0 – 1.0
    let color: Color

    @Environment(ThemeManager.self) private var theme

    // 270° arc (0.75 of a full circle) with the 90° gap sitting at the bottom.
    // Rotating by 135° moves the arc start from 12 o'clock to the 7:30 position,
    // so the filled end begins bottom-left and the empty end trails off bottom-right.
    private let arcSpan: CGFloat = 0.75
    private let rotation: Double = 135

    var body: some View {
        ZStack {
            // Background track — full 270° ghost arc
            Circle()
                .trim(from: 0, to: arcSpan)
                .stroke(
                    theme.subtleOverlay,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))

            // Live fill — shrinks from the right (4:30 end) as budget drains
            let fill = CGFloat(percentRemaining) * arcSpan
            Circle()
                .trim(from: 0, to: fill)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percentRemaining)

            // Glow dot at the tip of the fill
            Circle()
                .trim(from: max(0, fill - 0.015), to: max(0, fill))
                .stroke(color, style: StrokeStyle(lineWidth: 28, lineCap: .round))
                .rotationEffect(.degrees(rotation))
                .blur(radius: 6)
                .opacity(fill > 0.015 ? 0.45 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percentRemaining)
        }
    }
}
