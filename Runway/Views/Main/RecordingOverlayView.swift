import SwiftUI

/// Full-screen overlay shown while the user is recording.
struct RecordingOverlayView: View {

    let transcript:        String
    let isWaitingForFinal: Bool
    let recordingColor:    Color
    let isExpanded:        Bool
    var hideTranscript:    Bool = false
    var showReleaseHint:   Bool = false
    var showQuestionPrompt: Bool = false
    var micCenterFraction: CGFloat = 0.86

    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isListening: Bool {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var wordCount: Int {
        transcript.split(separator: " ").count
    }

    private var transcriptFontSize: CGFloat {
        switch wordCount {
        case 0...8:   return 32
        case 9...15:  return 26
        case 16...25: return 22
        case 26...40: return 18
        default:      return 15
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let W = proxy.size.width
            let H = proxy.size.height
            let micCenterY: CGFloat = H * micCenterFraction
            let radius: CGFloat = sqrt(pow(W / 2, 2) + pow(micCenterY, 2)) + 20
            let collapsedScale: CGFloat = 56 / radius

            // The top label sits at ~5% from top, the bottom label sits ~12% from bottom.
            // Transcript fills everything in between.
            let topZoneEnd:    CGFloat = H * 0.10   // below question prompt
            let bottomZoneStart: CGFloat = H * 0.82 // above "Release when done"

            ZStack {
                // ── Full-screen colour circle ───────────────────────────���────
                Circle()
                    .fill(recordingColor)
                    .frame(width: radius * 2, height: radius * 2)
                    .scaleEffect(isExpanded ? 1.0 : collapsedScale)
                    .animation(
                        reduceMotion ? .none : (isExpanded
                            ? .spring(response: 0.58, dampingFraction: 0.66)
                            : .spring(response: 0.40, dampingFraction: 0.84)),
                        value: isExpanded
                    )
                    .position(x: W / 2, y: micCenterY)

                // ── Question prompt (top) ────────────────────────────────────
                if showQuestionPrompt {
                    Text("What was your last purchase?")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .position(x: W / 2, y: H * 0.06)
                }

                // ── Transcript (centre zone) ─────────────────────────────────
                if !hideTranscript {
                    transcriptContent
                        .frame(width: W - 48) // 24pt padding each side
                        .frame(height: bottomZoneStart - topZoneEnd)
                        .position(
                            x: W / 2,
                            y: topZoneEnd + (bottomZoneStart - topZoneEnd) / 2
                        )
                }

                // ── Release hint (bottom) ────────────────────────────────────
                if showReleaseHint {
                    Text("Release when done")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .position(x: W / 2, y: H * 0.85)
                }
            }
            .opacity(isExpanded ? 1 : 0)
            .animation(
                isExpanded
                    ? .easeIn(duration: 0.25)
                    : .easeOut(duration: 0.13),
                value: isExpanded
            )
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isExpanded ? (isListening ? "Recording. Listening for speech." : "Recording. Transcript: \(transcript)") : "")
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if isWaitingForFinal {
            Text(transcript.isEmpty ? "Got it…" : transcript)
                .font(.system(size: transcriptFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .shadow(color: .black.opacity(0.3), radius: 4)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .minimumScaleFactor(0.3)
        } else if isListening {
            Text("Listening…")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.28))
        } else {
            Text(transcript)
                .font(.system(size: transcriptFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .minimumScaleFactor(0.3)
                .animation(.easeOut(duration: 0.15), value: transcript)
        }
    }
}
