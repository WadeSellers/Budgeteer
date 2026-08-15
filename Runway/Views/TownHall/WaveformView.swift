import SwiftUI

/// Renders an audio waveform from amplitude samples with an optional playback progress ball.
struct WaveformView: View {

    let samples: [Float]
    var progress: CGFloat = 0           // 0.0 – 1.0 during playback
    var isPlaying: Bool = false
    var barColor: Color = BudgeteerColors.green.opacity(0.3)
    var activeColor: Color = BudgeteerColors.green
    var ballColor: Color = BudgeteerColors.green
    var height: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = max(samples.count, 1)
            let barWidth: CGFloat = max(2, (w / CGFloat(count)) * 0.6)
            let spacing = w / CGFloat(count)

            ZStack(alignment: .leading) {
                // Waveform bars
                HStack(spacing: 0) {
                    ForEach(0..<samples.count, id: \.self) { i in
                        let fraction = CGFloat(i) / CGFloat(count)
                        let amplitude = CGFloat(samples[i])
                        let barH = max(2, amplitude * h)
                        let isPast = isPlaying && fraction <= progress

                        RoundedRectangle(cornerRadius: 1)
                            .fill(isPast ? activeColor : barColor)
                            .frame(width: barWidth, height: barH)
                            .frame(width: spacing, height: h)
                    }
                }

                // Playback ball
                if isPlaying {
                    let ballX = progress * w
                    let sampleIndex = min(Int(progress * CGFloat(samples.count)), samples.count - 1)
                    let amplitude = sampleIndex >= 0 && sampleIndex < samples.count
                        ? CGFloat(samples[sampleIndex])
                        : 0.5
                    let ballY = h / 2 - (amplitude * h / 2) + 3

                    Circle()
                        .fill(ballColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: ballColor.opacity(0.5), radius: 3)
                        .position(x: ballX, y: ballY)
                        .animation(.linear(duration: 0.05), value: progress)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Static placeholder waveform for empty state

extension WaveformView {
    static func placeholder(count: Int = 50) -> [Float] {
        (0..<count).map { i in
            let base = sin(Float(i) * 0.3) * 0.5 + 0.5
            return base * Float.random(in: 0.3...1.0)
        }
    }
}
