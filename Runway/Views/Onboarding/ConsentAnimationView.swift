import SwiftUI

// MARK: - Consent Animation View

struct ConsentAnimationView: View {

    @Binding var permissionDenied: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    // Animation phases
    @State private var titleVisible = false
    @State private var showMic = false
    @State private var showWaveform = false
    @State private var waveformPulsing = false
    @State private var showTranscript = false
    @State private var typedCharCount = 0
    @State private var showAIProcessing = false
    @State private var scanProgress: CGFloat = 0
    @State private var showParsedResult = false
    @State private var robotWorking = false
    @State private var badge1 = false
    @State private var badge2 = false
    @State private var badge3 = false
    @State private var showReassurance = false
    @State private var showButtons = false

    @State private var autoTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let transcriptText = "uh I spent like eight bucks at Starbucks this morning"

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            Text("Here's How We Use AI")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .multilineTextAlignment(.center)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 15)
                .animation(.easeOut(duration: 0.6), value: titleVisible)
                .padding(.bottom, 48)

            // The Story
            VStack(spacing: 24) {

                // Stage 1: Mic + waveform — "You speak a purchase"
                if showMic {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(BudgeteerColors.green.opacity(0.15))
                                .frame(width: 52, height: 52)

                            Image(systemName: "mic.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(BudgeteerColors.green)
                        }

                        if showWaveform {
                            HStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { i in
                                    let heights: [CGFloat] = [10, 20, 14, 24, 12, 18, 8]
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(BudgeteerColors.green.opacity(0.6))
                                        .frame(width: 3, height: waveformPulsing ? heights[i] : 4)
                                        .animation(
                                            .easeInOut(duration: Double.random(in: 0.3...0.5))
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.07),
                                            value: waveformPulsing
                                        )
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }

                        Text("You speak a purchase")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .transition(.opacity.combined(with: .offset(y: 12)))
                }

                // Stage 2: Typewriter transcript
                if showTranscript {
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 52)
                            .overlay(
                                Text(typewriterString)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary.opacity(0.7))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 14)
                            )
                            .overlay(
                                // Scanning highlight over transcript
                                GeometryReader { geo in
                                    if showAIProcessing && !showParsedResult {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        BudgeteerColors.green.opacity(0),
                                                        BudgeteerColors.green.opacity(0.15),
                                                        BudgeteerColors.green.opacity(0)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: 80)
                                            .offset(x: scanProgress * (geo.size.width + 80) - 80)
                                    }
                                }
                                .clipped()
                            )
                    }
                    .transition(.opacity.combined(with: .offset(y: 12)))
                }

                // Stage 3: AI processing → parsed result
                if showAIProcessing {
                    VStack(spacing: 16) {
                        // AI label row
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(BudgeteerColors.green.opacity(0.15))
                                    .frame(width: 44, height: 44)

                                Text("🤖")
                                    .font(.system(size: 22))
                                    .rotationEffect(.degrees(robotWorking ? -12 : 12))
                                    .scaleEffect(robotWorking ? 1.15 : 0.9)
                                    .animation(
                                        showParsedResult
                                            ? .spring(response: 0.3)
                                            : .easeInOut(duration: 0.32).repeatForever(autoreverses: true),
                                        value: robotWorking
                                    )
                            }

                            Text("AI grabs the important parts" + (showParsedResult ? "" : "…"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            Spacer()
                        }

                        // Badges — full width row, staggered appearance
                        if showParsedResult {
                            HStack(spacing: 12) {
                                if badge1 {
                                    parsedBadge("$8.00", highlight: true)
                                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                                }
                                if badge2 {
                                    parsedBadge("Starbucks", highlight: false)
                                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                                }
                                if badge3 {
                                    parsedBadge("Food", highlight: false)
                                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                                }
                                Spacer()
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .transition(.opacity.combined(with: .offset(y: 12)))
                }
            }
            .padding(.horizontal, 8)

            // Permissions preview
            if showReassurance {
                VStack(spacing: 10) {
                    Text("To make this work, we'll need your\npermission to use the microphone\nand speech recognition.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(BudgeteerColors.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your voice stays on your phone.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("Only the text is sent.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.top, 32)
                .transition(.opacity)
            }

            Spacer()
            Spacer()

            // Privacy policy link
            if showButtons {
                Button {
                    if let url = URL(string: "https://wadesellers.github.io/Budgeteer/privacy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Full privacy policy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .transition(.opacity)
                .padding(.bottom, 12)
            }

            // Buttons
            if showButtons {
                VStack(spacing: 12) {
                    continueButton
                    if permissionDenied {
                        permissionDeniedViews
                    }
                    backButton
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .padding(.bottom, 40)
            }
        }
        .padding(.horizontal, 32)
        .onAppear { startSequence() }
        .onDisappear { autoTask?.cancel() }
    }

    // MARK: - Typewriter

    private var typewriterString: String {
        let count = min(typedCharCount, transcriptText.count)
        let index = transcriptText.index(transcriptText.startIndex, offsetBy: count)
        return "\"" + String(transcriptText[..<index]) + (count < transcriptText.count ? "▌" : "\"")
    }

    private func runTypewriter() async {
        for i in 1...transcriptText.count {
            try? await Task.sleep(for: .seconds(Double.random(in: 0.03...0.06)))
            guard !Task.isCancelled else { return }
            typedCharCount = i
        }
    }

    // MARK: - Scan Animation

    private func runScanAnimation() async {
        // Run 2 scan passes
        for _ in 0..<2 {
            guard !Task.isCancelled else { return }
            scanProgress = 0
            withAnimation(.easeInOut(duration: 0.8)) {
                scanProgress = 1
            }
            try? await Task.sleep(for: .seconds(0.9))
        }
    }

    // MARK: - Sequencing

    private func startSequence() {
        // When Reduce Motion is on, show all content immediately without
        // staggered animation delays, keeping the page readable.
        if reduceMotion {
            titleVisible = true
            showMic = true
            showWaveform = true
            showTranscript = true
            typedCharCount = transcriptText.count
            showAIProcessing = true
            showParsedResult = true
            badge1 = true
            badge2 = true
            badge3 = true
            showReassurance = true
            showButtons = true
            return
        }

        autoTask = Task { @MainActor in
            // Title
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.easeOut(duration: 0.5)) { titleVisible = true }

            // Mic appears
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showMic = true }

            // Waveform starts
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showWaveform = true }
            try? await Task.sleep(for: .seconds(0.15))
            waveformPulsing = true

            // Transcript with typewriter effect
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showTranscript = true }
            try? await Task.sleep(for: .seconds(0.3))
            await runTypewriter()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // AI processing with scan + robot animation
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showAIProcessing = true }
            try? await Task.sleep(for: .seconds(0.2))
            robotWorking = true
            try? await Task.sleep(for: .seconds(0.2))
            await runScanAnimation()

            // Stop robot wiggle, show badges
            robotWorking = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { showParsedResult = true }
            try? await Task.sleep(for: .seconds(0.05))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { badge1 = true }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { badge2 = true }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { badge3 = true }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Reassurance
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.easeOut(duration: 0.6)) { showReassurance = true }

            // Buttons
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation(.easeOut(duration: 0.5)) { showButtons = true }
        }
    }

    // MARK: - Parsed Badge

    private func parsedBadge(_ text: String, highlight: Bool) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(highlight ? BudgeteerColors.green.opacity(0.2) : BudgeteerColors.green.opacity(0.12))
            .foregroundStyle(BudgeteerColors.green)
            .clipShape(Capsule())
    }

    // MARK: - Buttons

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(BudgeteerColors.green)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Text("Back")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionDeniedViews: some View {
        Group {
            Text("Microphone access is needed for voice recording. You can enable it in Settings, or skip to use keyboard entry.")
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            Button("Skip — I'll use the keyboard", action: onSkip)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
