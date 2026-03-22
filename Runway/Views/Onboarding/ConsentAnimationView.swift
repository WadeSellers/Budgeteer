import SwiftUI

// MARK: - Consent Phase

private enum ConsentPhase: Int, Comparable {
    case waiting = -1
    case voice = 0
    case ai = 1
    case ready = 2
    case done = 3

    static func < (lhs: ConsentPhase, rhs: ConsentPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Consent Animation View

struct ConsentAnimationView: View {

    @Binding var permissionDenied: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: ConsentPhase = .waiting
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var showButtons = false

    var body: some View {
        if reduceMotion {
            staticFallback
        } else {
            animatedFlow
        }
    }

    // MARK: - Animated Flow

    private var animatedFlow: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            Text("Before You Record")
                .font(.title2.weight(.bold))
                .opacity(phase >= .voice ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: phase)
                .padding(.bottom, 52)

            // Three phase rows
            VStack(spacing: 44) {
                VoicePhaseRow(isActive: phase >= .voice)
                AIPhaseRow(isActive: phase >= .ai)
                ReadyPhaseRow(isActive: phase >= .ready)
            }
            .padding(.horizontal, 8)

            Spacer()
            Spacer()

            // Privacy policy link
            if phase == .done {
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
        .contentShape(Rectangle())
        .onTapGesture { advancePhase() }
        .onAppear { startSequence() }
        .onDisappear { autoAdvanceTask?.cancel() }
    }

    // MARK: - Sequencing

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                phase = .voice
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            scheduleAutoAdvance(delay: 3.5)
        }
    }

    private func scheduleAutoAdvance(delay: Double) {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            advancePhase()
        }
    }

    private func advancePhase() {
        autoAdvanceTask?.cancel()

        switch phase {
        case .waiting:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                phase = .voice
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            scheduleAutoAdvance(delay: 3.5)

        case .voice:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                phase = .ai
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            scheduleAutoAdvance(delay: 3.5)

        case .ai:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                phase = .ready
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            scheduleAutoAdvance(delay: 3.0)

        case .ready:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .done
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeOut(duration: 0.6)) {
                    showButtons = true
                }
            }

        case .done:
            break
        }
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

    // MARK: - Static Fallback (Reduce Motion)

    private var staticFallback: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Before You Record")
                .font(.title2.weight(.bold))
                .padding(.bottom, 36)

            VStack(spacing: 28) {
                staticRow(leftIcon: "waveform", text: "Voice stays here", rightIcon: "iphone")
                staticRow(leftIcon: "cpu", text: "AI finds the details", rightIcon: "sparkles")
                staticRow(leftIcon: "mic.fill", text: "Ready? Hold to speak", rightIcon: "circle.fill")
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 12) {
                continueButton
                if permissionDenied {
                    permissionDeniedViews
                }
                backButton
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
    }

    private func staticRow(leftIcon: String, text: String, rightIcon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: leftIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(BudgeteerColors.green)
                .frame(width: 48, height: 48)
                .background(BudgeteerColors.green.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 0)

            Image(systemName: rightIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(BudgeteerColors.green)
                .frame(width: 48, height: 48)
                .background(BudgeteerColors.green.opacity(0.12))
                .clipShape(Circle())
        }
    }
}

// MARK: - Phase 1: Voice stays on-device

private struct VoicePhaseRow: View {
    let isActive: Bool

    @State private var waveformPulsing = false
    @State private var waveformCollapsed = false
    @State private var textVisible = false
    @State private var rightIconVisible = false
    @State private var waveformInPhone = false

    private let barHeights: [CGFloat] = [16, 26, 12, 22, 14]

    var body: some View {
        HStack(spacing: 16) {
            // LEFT: Waveform → morphs to "Aa"
            ZStack {
                Circle()
                    .fill(BudgeteerColors.green.opacity(0.12))
                    .frame(width: 48, height: 48)

                if !waveformCollapsed {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(BudgeteerColors.green)
                                .frame(width: 3, height: waveformPulsing ? barHeights[i] : 4)
                                .animation(
                                    .easeInOut(duration: Double.random(in: 0.25...0.35))
                                    .repeatCount(7, autoreverses: true)
                                    .delay(Double(i) * 0.06),
                                    value: waveformPulsing
                                )
                        }
                    }
                    .transition(.opacity)
                } else {
                    Text("Aa")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BudgeteerColors.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isActive ? 1 : 0.5)
            .opacity(isActive ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)

            // CENTER: Label
            Text("Voice stays here")
                .font(.subheadline.weight(.semibold))
                .opacity(textVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: textVisible)

            Spacer(minLength: 0)

            // RIGHT: Phone with waveform contained inside
            ZStack {
                Circle()
                    .fill(BudgeteerColors.green.opacity(0.12))
                    .frame(width: 48, height: 48)

                // Phone outline
                Image(systemName: "iphone")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(BudgeteerColors.green.opacity(0.5))

                // Mini waveform inside the phone
                if waveformInPhone {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(BudgeteerColors.green)
                                .frame(width: 2, height: CGFloat([6, 10, 7][i]))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(rightIconVisible ? 1 : 0.5)
            .opacity(rightIconVisible ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: rightIconVisible)
        }
        .frame(height: 52)
        .opacity(isActive ? 1 : 0)
        .onChange(of: isActive) { _, active in
            guard active else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                waveformPulsing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                textVisible = true
            }
            // Right icon appears after a beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                rightIconVisible = true
            }
            // Waveform appears inside phone
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    waveformInPhone = true
                }
            }
            // Left waveform collapses to "Aa"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    waveformCollapsed = true
                }
            }
        }
    }
}

// MARK: - Phase 2: AI extracts details

private struct AIPhaseRow: View {
    let isActive: Bool

    @State private var iconState: Int = 0  // 0=text.quote, 1=processing, 2=done
    @State private var textVisible = false
    @State private var showBadges = false

    var body: some View {
        HStack(spacing: 16) {
            // LEFT: Text → CPU processing
            ZStack {
                Circle()
                    .fill(BudgeteerColors.green.opacity(0.12))
                    .frame(width: 48, height: 48)

                if iconState == 0 {
                    Image(systemName: "text.quote")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(BudgeteerColors.green)
                        .transition(.opacity)
                } else {
                    Image(systemName: "cpu")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(BudgeteerColors.green)
                        .rotationEffect(.degrees(iconState == 1 ? 360 : 0))
                        .animation(.easeInOut(duration: 0.7), value: iconState)
                        .transition(.opacity)
                }
            }
            .scaleEffect(isActive ? 1 : 0.5)
            .opacity(isActive ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)

            // CENTER: Label
            Text("AI finds the details")
                .font(.subheadline.weight(.semibold))
                .opacity(textVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: textVisible)

            Spacer(minLength: 0)

            // RIGHT: Parsed result badges
            ZStack {
                Circle()
                    .fill(BudgeteerColors.green.opacity(showBadges ? 0.2 : 0.12))
                    .frame(width: 48, height: 48)
                    .animation(.easeOut(duration: 0.3), value: showBadges)

                if !showBadges {
                    Image(systemName: "sparkles")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(BudgeteerColors.green.opacity(0.4))
                        .transition(.opacity)
                } else {
                    VStack(spacing: 2) {
                        Text("$12")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text("☕️")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(BudgeteerColors.green)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isActive ? 1 : 0.5)
            .opacity(isActive ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)
        }
        .frame(height: 52)
        .opacity(isActive ? 1 : 0)
        .onChange(of: isActive) { _, active in
            guard active else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    iconState = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                textVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    iconState = 2
                }
            }
            // Badges appear on right
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    showBadges = true
                }
            }
        }
    }
}

// MARK: - Phase 3: Ready to record

private struct ReadyPhaseRow: View {
    let isActive: Bool

    @State private var textVisible = false
    @State private var rightPulsing = false
    @State private var micBounced = false

    var body: some View {
        HStack(spacing: 16) {
            // LEFT: Mic icon
            ZStack {
                Circle()
                    .fill(BudgeteerColors.green.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(BudgeteerColors.green)
                    .scaleEffect(micBounced ? 1.0 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: micBounced)
            }
            .scaleEffect(isActive ? 1 : 0.5)
            .opacity(isActive ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)

            // CENTER: Label
            Text("Ready? Hold to speak")
                .font(.subheadline.weight(.semibold))
                .opacity(textVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: textVisible)

            Spacer(minLength: 0)

            // RIGHT: Pulsing green circle (preview of recording)
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(BudgeteerColors.green.opacity(0.2), lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .scaleEffect(rightPulsing ? 1.3 : 1.0)
                    .opacity(rightPulsing ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.2)
                        .repeatForever(autoreverses: false),
                        value: rightPulsing
                    )

                Circle()
                    .fill(BudgeteerColors.green.opacity(0.15))
                    .frame(width: 48, height: 48)

                Circle()
                    .fill(BudgeteerColors.green)
                    .frame(width: 20, height: 20)
            }
            .scaleEffect(isActive ? 1 : 0.5)
            .opacity(isActive ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)
        }
        .frame(height: 52)
        .opacity(isActive ? 1 : 0)
        .onChange(of: isActive) { _, active in
            guard active else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                micBounced = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                textVisible = true
            }
            // Start the pulse ring
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                rightPulsing = true
            }
        }
    }
}
