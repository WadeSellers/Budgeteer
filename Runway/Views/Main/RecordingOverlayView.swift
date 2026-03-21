import SwiftUI

/// Full-screen overlay shown while the user is recording.
///
/// The parent controls expansion via `isExpanded`:
///   true  → circle springs from a tiny dot (mic-button size) at the bottom
///            of the screen to fill every pixel of the display.
///   false → circle springs back to that same tiny dot, fully retreating.
///
/// The parent keeps this view in the hierarchy during the collapse animation
/// (≈ 0.5 s) and only removes it once the spring has settled.
struct RecordingOverlayView: View {

    let transcript:        String
    let isWaitingForFinal: Bool
    let recordingColor:    Color
    /// Toggled by the parent to drive the expand / collapse animation.
    let isExpanded:        Bool
    /// When true, transcript text is hidden (used during privacy consent).
    var hideTranscript:    Bool = false

    @Environment(ThemeManager.self) private var theme

    @State private var renderedWordCount = 0

    private var isListening: Bool {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // ── Body ─────────────────────────────────────────────────────────────────

    var body: some View {
        GeometryReader { proxy in
            let W = proxy.size.width
            let H = proxy.size.height

            // Circle originates from the mic button's approximate centre.
            // H * 0.86 lands close to the mic button centre on all current
            // iPhones when the view covers the full screen (ignoresSafeArea).
            let micCenterY: CGFloat = H * 0.86

            // Radius sized so a circle centred at (W/2, micCenterY) covers
            // every corner of the screen, plus a small safety margin.
            let radius: CGFloat = sqrt(pow(W / 2, 2) + pow(micCenterY, 2)) + 20

            // At this scale the circle diameter equals the mic button (112 pt),
            // so it looks like the button itself is expanding / contracting.
            let collapsedScale: CGFloat = 56 / radius

            ZStack {

                // ── Full-screen colour circle ─────────────────────────────────
                //
                // Expand:   slower, slightly under-damped spring → the circle
                //           overshoots a touch before settling, feeling dramatic.
                // Collapse: tighter spring → snaps decisively back to the
                //           mic-button dot.
                // IMPORTANT: .scaleEffect must come BEFORE .position().
                // .position() expands the resulting view to fill the parent, so
                // any .scaleEffect applied after it anchors to the screen centre,
                // not the mic button. Scaling first, then placing, keeps the
                // scale origin pinned exactly at the mic button's centre.
                Circle()
                    .fill(recordingColor)
                    .frame(width: radius * 2, height: radius * 2)
                    .scaleEffect(isExpanded ? 1.0 : collapsedScale)
                    .animation(
                        isExpanded
                            ? .spring(response: 0.58, dampingFraction: 0.66)
                            : .spring(response: 0.40, dampingFraction: 0.84),
                        value: isExpanded
                    )
                    .position(x: W / 2, y: micCenterY)

                // ── Transcript text ───────────────────────────────────────────
                //
                // Fades in after the circle finishes expanding (delay: 0.25 s).
                // On collapse it fades out quickly so the retreating circle
                // is the dominant visual, not competing text.
                // Text is centred within the zone above the mic button.
                // Capping maxHeight at H * 0.72 keeps it well clear of the
                // button while using all the open space above it.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    if isWaitingForFinal {
                        stageText(
                            transcript.isEmpty ? "Got it…" : transcript,
                            opacity: 0.5
                        )
                    } else if isListening {
                        Text("Listening…")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.28))
                            .multilineTextAlignment(.center)
                    } else {
                        stageText(transcript, opacity: 1)
                            .id(renderedWordCount)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 10)),
                                removal:   .opacity
                            ))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 36)
                .frame(maxWidth: .infinity, maxHeight: H * 0.72)
                .opacity(isExpanded && !hideTranscript ? 1 : 0)
                .animation(
                    isExpanded
                        ? .easeIn(duration: 0.20).delay(0.25)
                        : .easeOut(duration: 0.13),
                    value: isExpanded
                )
            }
        }
        .ignoresSafeArea()
        .onChange(of: transcript) { _, newValue in
            let count = newValue.split(separator: " ").count
            guard count > renderedWordCount else { return }
            withAnimation(.easeOut(duration: 0.18)) { renderedWordCount = count }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    @ViewBuilder
    private func stageText(_ text: String, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 32, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(opacity))
            .shadow(color: .black.opacity(0.3), radius: 4)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }
}
