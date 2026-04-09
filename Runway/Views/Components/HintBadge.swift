import SwiftUI

struct HintBadge: View {
    let message: String
    let hintType: HintType
    let anchor: UnitPoint       // where the tooltip appears relative to badge

    @Environment(HintManager.self) private var hintManager
    @State private var showTooltip = false
    @State private var dismissed = false
    @State private var pulseOpacity: Double = 1.0
    @State private var sparkleScale: CGFloat = 1.0

    /// Whether the badge should be visible. Combines the HintManager's
    /// observable state with a local `dismissed` flag so the badge hides
    /// immediately when the user taps "Got it" — even if SwiftUI hasn't
    /// re-evaluated the @Observable dependency yet.
    private var isVisible: Bool {
        !dismissed && hintManager.shouldShow(hintType)
    }

    var body: some View {
        if isVisible {
            badgeCircle
                .accessibilityLabel("Hint")
                .accessibilityHint(message)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35)) { showTooltip = true }
                }
                .fullScreenCover(isPresented: $showTooltip) {
                    tooltipOverlay
                        .background(ClearBackground())
                }
        }
    }

    // MARK: - Badge

    private var badgeCircle: some View {
        ZStack {
            // Sparkle ring
            Circle()
                .stroke(Color.yellow.opacity(0.4), lineWidth: 2)
                .frame(width: 28, height: 28)
                .scaleEffect(sparkleScale)
                .opacity(2.0 - Double(sparkleScale))

            Circle()
                .fill(Color.yellow)
                .frame(width: 20, height: 20)

            Text("i")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
        }
        .opacity(pulseOpacity)
        .shadow(color: .yellow.opacity(0.6), radius: 6)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 0.7
            }
            withAnimation(
                .easeOut(duration: 1.8)
                .repeatForever(autoreverses: false)
            ) {
                sparkleScale = 2.0
            }
        }
    }

    // MARK: - Tooltip Overlay

    private var tooltipOverlay: some View {
        ZStack {
            // Dim background — tap to close tooltip without marking seen
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { showTooltip = false }

            // Tooltip card — centered on screen
            VStack(spacing: 12) {
                // Yellow "i" icon
                ZStack {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 32, height: 32)
                    Text("i")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                }

                Text(message)
                    .font(.body)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    dismissHint()
                } label: {
                    Text("Got it")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 260)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private func dismissHint() {
        showTooltip = false
        dismissed = true
        hintManager.markSeen(hintType)
    }
}

// Allows fullScreenCover to have a transparent background
private struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = InnerView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private class InnerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            superview?.superview?.backgroundColor = .clear
        }
    }
}
