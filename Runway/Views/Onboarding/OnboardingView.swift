import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self)  private var theme
    @Environment(\.modelContext)     private var modelContext

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasAcceptedPrivacy")     private var hasAcceptedPrivacy     = false

    @State private var step   = 0
    @State private var budgetAmount = 0
    @State private var contentVisible = true
    @State private var isTransitioning = false

    // Practice recording
    @State private var speechService      = SpeechService()
    @State private var practiceState:      PracticeState = .ready
    @State private var showOverlay        = false
    @State private var overlayExpanded    = false
    @State private var permissionDenied   = false
    @State private var pileHeight: CGFloat = 0
    @State private var micPulsing         = false
    @State private var idlePulseTask:     Task<Void, Never>?
    @State private var holdStartTime:     Date?
    @State private var showHoldHintToast  = false

    private enum PracticeState {
        case ready, recording, processing, done
    }

    // Success overlay handled by ContentView

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            // Money rain animation — persists across steps 0 and 1
            if step < 2 {
                MoneyRainView(pileHeight: $pileHeight)
            }

            Group {
                switch step {
                case 0:  welcomeStep
                case 1:  budgetStep
                case 2:  consentStep
                default: practiceStep
                }
            }
            .opacity(contentVisible ? 1 : 0)
            .scaleEffect(contentVisible ? 1 : 0.82)
            .offset(y: contentVisible ? 0 : -20)
            .animation(.easeInOut(duration: 0.35), value: contentVisible)
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 80))
                .foregroundStyle(BudgeteerColors.green)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Budgeteer")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                Text("Track your spending\nwith your voice.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            primaryButton("Get Started") { goToStep(1) }
                .padding(.bottom, 16 + pileHeight)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Step 1: Budget

    private var budgetStep: some View {
        BillCounterView(amount: $budgetAmount, pileHeight: pileHeight) {
            VStack(spacing: 12) {
                primaryButton("Continue", enabled: budgetAmount > 0) {
                    budgetManager.monthlyBudget = Double(budgetAmount)
                    goToStep(2)
                }
                backButton {
                    budgetAmount = 0
                    goToStep(0)
                }
            }
        }
        .coordinateSpace(name: "billCounter")
    }

    // MARK: - Step 2: Consent + Permissions

    private var consentStep: some View {
        ConsentAnimationView(
            permissionDenied: $permissionDenied,
            onContinue: {
                hasAcceptedPrivacy = true
                Task {
                    await speechService.requestPermissions()
                    if speechService.permissionGranted {
                        goToStep(3)
                    } else {
                        permissionDenied = true
                    }
                }
            },
            onSkip: { hasCompletedOnboarding = true },
            onBack: { goToStep(1) }
        )
    }

    // MARK: - Step 3: Practice Recording

    private var practiceStep: some View {
        ZStack {
            // Main content — always present, hidden behind overlay when recording
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Text("🎤")
                        .font(.system(size: 48))
                        .accessibilityHidden(true)

                    Text("Let's capture your\nfirst purchase!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .multilineTextAlignment(.center)

                    Text("Think about the last thing you bought.\nHold the mic and say it out loud.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("e.g. \"I spent twelve bucks at Chipotle\"")
                        .font(.body.weight(.medium).italic())
                        .foregroundStyle(BudgeteerColors.green)
                        .padding(.top, 4)
                }

                Spacer()

                // Mic button
                if practiceState != .done {
                    VStack(spacing: 16) {
                        Text(practiceHint)
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(overlayExpanded ? .clear : BudgeteerColors.green)
                                    .frame(width: 112, height: 112)
                                    .shadow(color: overlayExpanded ? .clear : BudgeteerColors.green.opacity(0.5), radius: micPulsing ? 30 : 20)
                                    .scaleEffect(micPulsing ? 1.08 : 1.0)
                                    .animation(
                                        micPulsing
                                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                            : .easeOut(duration: 0.3),
                                        value: micPulsing
                                    )

                                if practiceState == .processing {
                                    ProgressView().tint(.white).scaleEffect(1.5)
                                } else {
                                    Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                                        .font(.system(size: 38))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(HoldButtonStyle(
                            onPress: {
                                guard practiceState == .ready else { return }
                                micPulsing = false
                                idlePulseTask?.cancel()
                                holdStartTime = Date()
                                // Start recording + overlay immediately (synchronous to avoid ghost circle)
                                startPractice()
                                showOverlay = true
                                overlayExpanded = true
                            },
                            onRelease: {
                                let held = Date().timeIntervalSince(holdStartTime ?? Date())
                                if held < 0.4 {
                                    // Quick tap — abort recording, collapse overlay, show hint
                                    if speechService.isRecording {
                                        speechService.stop()
                                    }
                                    practiceState = .ready
                                    overlayExpanded = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showOverlay = false
                                    }
                                    showHoldHint()
                                } else if speechService.isRecording {
                                    stopPractice()
                                }
                            }
                        ))
                        .accessibilityLabel(practiceState == .processing ? "Processing your purchase" : practiceState == .recording ? "Recording, release to finish" : "Record a practice purchase")
                        .accessibilityHint("Hold to record a purchase with your voice, release when done")
                        .disabled(practiceState == .processing || practiceState == .done)
                    }
                    .padding(.bottom, 50)
                    .onAppear { startIdlePulse() }
                }
            }
            .opacity(overlayExpanded ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: overlayExpanded)

            // Recording overlay
            if showOverlay {
                RecordingOverlayView(
                    transcript: speechService.transcript,
                    isWaitingForFinal: false,
                    recordingColor: BudgeteerColors.green,
                    isExpanded: overlayExpanded,
                    showReleaseHint: true,
                    showQuestionPrompt: true,
                    micCenterFraction: 0.88
                )
                .environment(theme)
            }

            // Hold hint toast — always present, driven by opacity
            Text("Hold the mic button to record")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
                .opacity(showHoldHintToast ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: showHoldHintToast)
                .accessibilityHidden(!showHoldHintToast)
                .zIndex(20)
        }
        .onChange(of: speechService.isRecording) { _, isRecording in
            guard !isRecording, practiceState == .recording else { return }
            let text = speechService.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            processPractice(text)
        }
    }

    private var practiceHint: String {
        switch practiceState {
        case .ready:      "Hold to record, release when done"
        case .recording:  "Release when done"
        default:          ""
        }
    }

    private func showHoldHint() {
        showHoldHintToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showHoldHintToast = false
        }
        startIdlePulse()
    }

    private func startIdlePulse() {
        idlePulseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, practiceState == .ready else { return }
            micPulsing = true
        }
    }

    private func startPractice() {
        guard practiceState == .ready else { return }
        SoundManager.shared.playRecordingStart()
        do {
            try speechService.start()
            // If recognizer wasn't available, start() returns without throwing
            // but sets lastError — check for that
            if let err = speechService.lastError {
                print("[Budgeteer] speech start issue: \(err)")
                practiceState = .ready
                return
            }
            practiceState = .recording
        } catch {
            print("[Budgeteer] speech start failed: \(error.localizedDescription)")
            practiceState = .ready
        }
    }

    private func stopPractice() {
        guard speechService.isRecording else { return }
        SoundManager.shared.playRecordingCaptured()
        speechService.stop()
    }

    private func processPractice(_ transcript: String) {
        guard !transcript.isEmpty else {
            practiceState = .ready
            // Collapse overlay since nothing was said
            overlayExpanded = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                showOverlay = false
            }
            return
        }

        practiceState = .processing

        Task {
            do {
                let result = try await ClaudeService.shared.parseTransaction(transcript)
                await MainActor.run {
                    // Save the real transaction
                    let t = Transaction(
                        amount: result.amount,
                        transactionDescription: result.description,
                        category: result.category,
                        timestamp: .now
                    )
                    modelContext.insert(t)
                    do {
                        try modelContext.save()
                    } catch {
                        print("[Budgeteer] onboarding save failed: \(error.localizedDescription)")
                    }

                    practiceState = .done
                    SoundManager.shared.playPurchaseSaved()

                    // Keep the green overlay expanded — it's the curtain.
                    // Signal ContentView to swap to MainView behind it, then drop the curtain.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UserDefaults.standard.set(true, forKey: "showOnboardingComplete")
                        hasCompletedOnboarding = true
                    }
                }
            } catch {
                await MainActor.run {
                    // If API fails, still proceed to main screen
                    practiceState = .done
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UserDefaults.standard.set(true, forKey: "showOnboardingComplete")
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }

    // MARK: - Reusable Buttons

    private func primaryButton(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(enabled ? BudgeteerColors.green : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!enabled)
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Back")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Cinematic Step Transition

    /// Fades out current content, changes step, then fades in new content.
    private func goToStep(_ newStep: Int) {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Phase 1: fade out current content
        withAnimation(.easeIn(duration: 0.3)) {
            contentVisible = false
        }

        // Phase 2: change step while invisible, then fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            step = newStep

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.4)) {
                    contentVisible = true
                }
                isTransitioning = false
            }
        }
    }
}
