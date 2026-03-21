import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self)  private var theme
    @Environment(\.modelContext)     private var modelContext

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasAcceptedPrivacy")     private var hasAcceptedPrivacy     = false

    @State private var step   = 0
    @State private var budget = ""

    // Practice recording
    @State private var speechService      = SpeechService()
    @State private var practiceState:      PracticeState = .ready
    @State private var isProcessing       = false
    @State private var showOverlay        = false
    @State private var overlayExpanded    = false
    @State private var practiceResult:    PracticeResult?
    @State private var permissionDenied   = false

    private enum PracticeState {
        case ready, recording, processing, done
    }

    private struct PracticeResult {
        let amount: Double
        let description: String
        let category: String
    }

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            switch step {
            case 0:  welcomeStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 1:  budgetStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 2:  consentStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case 3:  practiceStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            default: successStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .foregroundStyle(.primary)
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 80))
                .foregroundStyle(BudgeteerColors.green)

            VStack(spacing: 12) {
                Text("Budgeteer")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Text("Track your spending\nwith your voice.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            primaryButton("Get Started") { step = 1 }
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Step 1: Budget

    private var budgetStep: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Set Your Budget")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("How much do you want to spend\nthis month?")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $budget)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }

                // Quick-pick chips
                HStack(spacing: 10) {
                    ForEach([1000, 2000, 3000, 5000], id: \.self) { amount in
                        Button {
                            budget = String(amount)
                        } label: {
                            Text("$\(amount / 1000)k")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Int(budget) == amount
                                        ? BudgeteerColors.green.opacity(0.2)
                                        : theme.card
                                )
                                .foregroundStyle(
                                    Int(budget) == amount
                                        ? BudgeteerColors.green
                                        : .secondary
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 8)

                Text("You can change this anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }

            Spacer()

            VStack(spacing: 12) {
                let isValid = (Double(budget) ?? 0) > 0
                primaryButton("Continue", enabled: isValid) {
                    if let amount = Double(budget), amount > 0 {
                        budgetManager.monthlyBudget = amount
                        step = 2
                    }
                }
                backButton { step = 0 }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Step 2: Consent + Permissions

    private var consentStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Before You Record")
                .font(.title2.weight(.bold))
                .padding(.bottom, 32)

            VStack(spacing: 24) {
                consentPoint(
                    icon: "waveform",
                    text: "Your voice is converted to text **on your device**. No audio is saved or sent."
                )
                consentPoint(
                    icon: "cpu",
                    text: "The text is sent to AI to extract the **amount and category**. Nothing else."
                )
                consentPoint(
                    icon: "lock.shield",
                    text: "Your purchases **stay on your phone**. We don't have an account or a server."
                )
            }
            .padding(.horizontal, 8)

            Spacer()

            if permissionDenied {
                Text("Microphone access is needed for voice recording. You can enable it in Settings, or skip to use keyboard entry.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
            }

            VStack(spacing: 12) {
                primaryButton("Continue") {
                    hasAcceptedPrivacy = true
                    Task {
                        await speechService.requestPermissions()
                        if speechService.permissionGranted {
                            step = 3
                        } else {
                            permissionDenied = true
                        }
                    }
                }

                if permissionDenied {
                    Button("Skip — I'll use the keyboard") {
                        hasCompletedOnboarding = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                backButton { step = 1 }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
    }

    private func consentPoint(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(BudgeteerColors.green)
                .frame(width: 38, height: 38)
                .background(BudgeteerColors.green.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Step 3: Practice Recording

    private var practiceStep: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                Spacer()

                if practiceState == .ready || practiceState == .recording {
                    VStack(spacing: 16) {
                        Text("Let's Try It")
                            .font(.title2.weight(.bold))
                        Text("Hold the button and say something like:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\"twelve dollars at Starbucks\"")
                            .font(.body.weight(.medium).italic())
                            .foregroundStyle(BudgeteerColors.green)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(overlayExpanded ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: overlayExpanded)
                }

                if practiceState == .processing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(BudgeteerColors.green)
                        Text("Processing…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Mic button
                if practiceState != .done {
                    VStack(spacing: 10) {
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(overlayExpanded ? .clear : BudgeteerColors.green)
                                    .frame(width: 112, height: 112)
                                    .shadow(color: overlayExpanded ? .clear : BudgeteerColors.green.opacity(0.5), radius: 20)

                                if isProcessing {
                                    ProgressView().tint(.white).scaleEffect(1.5)
                                } else {
                                    Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                                        .font(.system(size: 38))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(HoldButtonStyle(
                            onPress: { startPractice() },
                            onRelease: { stopPractice() }
                        ))
                        .disabled(isProcessing || practiceState == .done)

                        Text(practiceHint)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .opacity(overlayExpanded ? 0 : 1)
                    }
                    .padding(.bottom, 50)
                }
            }

            // Recording overlay
            if showOverlay {
                RecordingOverlayView(
                    transcript: speechService.transcript,
                    isWaitingForFinal: false,
                    recordingColor: BudgeteerColors.green,
                    isExpanded: overlayExpanded
                )
                .environment(theme)
            }
        }
        .onChange(of: speechService.isRecording) { _, isRecording in
            guard !isRecording, practiceState == .recording else { return }
            let text = speechService.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            processPractice(text)
        }
        .onChange(of: practiceState) { _, state in
            if state == .recording {
                showOverlay = true
                DispatchQueue.main.async { overlayExpanded = true }
            } else if state != .recording && showOverlay {
                overlayExpanded = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    showOverlay = false
                }
            }
        }
    }

    private var practiceHint: String {
        switch practiceState {
        case .ready:      "Hold to speak"
        case .recording:  "Release when done"
        case .processing: "Thinking…"
        case .done:       ""
        }
    }

    private func startPractice() {
        guard practiceState == .ready else { return }
        do {
            try speechService.start()
            practiceState = .recording
        } catch {
            // Permission denied — shouldn't happen since we checked in step 2
        }
    }

    private func stopPractice() {
        guard speechService.isRecording else { return }
        speechService.stop()
    }

    private func processPractice(_ transcript: String) {
        guard !transcript.isEmpty else {
            practiceState = .ready
            return
        }

        practiceState = .processing
        isProcessing  = true

        Task {
            do {
                let result = try await ClaudeService.shared.parseTransaction(transcript)
                await MainActor.run {
                    // Save the practice transaction for real
                    let t = Transaction(
                        amount: result.amount,
                        transactionDescription: result.description,
                        category: result.category,
                        timestamp: .now
                    )
                    modelContext.insert(t)
                    try? modelContext.save()

                    practiceResult = PracticeResult(
                        amount: result.amount,
                        description: result.description,
                        category: result.category
                    )
                    isProcessing  = false
                    practiceState = .done

                    // Auto-advance to success step
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { step = 4 }
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing  = false
                    practiceState = .ready
                }
            }
        }
    }

    // MARK: - Step 4: Success

    private var successStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(BudgeteerColors.green)

            VStack(spacing: 12) {
                Text("You're All Set")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                if let result = practiceResult {
                    VStack(spacing: 4) {
                        Text(String(format: "$%.2f", result.amount))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(BudgeteerColors.green)
                        Text(result.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                Text("That's it. Hold to record,\ncheck your budget anytime.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

            Spacer()

            primaryButton("Start Using Budgeteer") {
                hasCompletedOnboarding = true
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
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
}
