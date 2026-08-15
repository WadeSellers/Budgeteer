import SwiftUI

struct TownHallRecordSheet: View {

    let townHallService: TownHallService
    let onPosted: () -> Void

    @Environment(ThemeManager.self) private var theme
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var speechService = SpeechService()
    @State private var selectedType: PostType?
    @State private var step = 0                     // 0=category, 1=recording, 2=confirm
    @State private var secondsRemaining = 15
    @State private var generatedTitle = ""
    @State private var generatedSummary = ""
    @State private var isGeneratingTitle = false
    @State private var isPosting = false
    @State private var postError: String?

    // Recording state
    @State private var showOverlay = false
    @State private var overlayExpanded = false
    @State private var holdStartTime: Date?
    @State private var countdownTask: Task<Void, Never>?
    @State private var waveformSamples: [Float] = []
    @State private var showHoldHintToast = false
    @State private var intentToRecord = false   // true from press until explicit release

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                Group {
                    switch step {
                    case 0:  categoryStep
                    case 1:  recordingStep
                    default: confirmStep
                    }
                }

                // Recording overlay
                if showOverlay {
                    RecordingOverlayView(
                        transcript: speechService.transcript,
                        isWaitingForFinal: false,
                        recordingColor: selectedType?.color ?? BudgeteerColors.green,
                        isExpanded: overlayExpanded,
                        showReleaseHint: true,
                        showQuestionPrompt: false,
                        micCenterFraction: 0.86
                    )
                    .environment(theme)
                    .overlay(alignment: .top) {
                        // Countdown timer
                        if overlayExpanded {
                            Text("\(secondsRemaining)s")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.3))
                                .padding(.top, 60)
                        }
                    }
                }

                // Hold hint toast
                VStack {
                    Spacer()
                    Text("Hold the mic button to record")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                        .padding(.bottom, 170)
                }
                .opacity(showHoldHintToast ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: showHoldHintToast)
                .zIndex(20)
            }
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            speechService.saveAudioToFile = true
            Task { await speechService.requestPermissions() }
        }
        .onDisappear {
            countdownTask?.cancel()
            if speechService.isRecording { speechService.stop() }
        }
        .onChange(of: speechService.isRecording) { _, isRecording in
            guard !isRecording, step == 1 else { return }
            finishRecording()
        }
    }

    // MARK: - Step 0: Category Selection

    private var categoryStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("What's this about?")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            VStack(spacing: 16) {
                ForEach(PostType.allCases, id: \.self) { type in
                    categoryCard(type)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    private func categoryCard(_ type: PostType) -> some View {
        Button {
            selectedType = type
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                step = 1
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(type.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: type.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(type.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(type.prompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(type.label): \(type.prompt)")
    }

    // MARK: - Step 1: Recording

    private var recordingStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                if let type = selectedType {
                    ZStack {
                        Circle()
                            .fill(type.color.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: type.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(type.color)
                    }
                    .accessibilityHidden(true)

                    Text(type.prompt)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .multilineTextAlignment(.center)
                }

                Text("Hold the mic and speak (15 seconds max)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(overlayExpanded ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: overlayExpanded)

            Spacer()

            // Mic button
            VStack(spacing: 16) {
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(overlayExpanded ? .clear : (selectedType?.color ?? BudgeteerColors.green))
                            .frame(width: 112, height: 112)
                            .shadow(color: overlayExpanded
                                ? .clear
                                : (selectedType?.color ?? BudgeteerColors.green).opacity(0.5),
                                radius: 20)

                        if speechService.isRecording {
                            Image(systemName: "waveform")
                                .font(.system(size: 38))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(HoldButtonStyle(
                    onPress: {
                        holdStartTime = Date()
                        intentToRecord = true
                        showOverlay = true
                        overlayExpanded = true
                        // Defer heavy audio work so the gesture system doesn't time out
                        DispatchQueue.main.async {
                            guard intentToRecord else { return }
                            startRecording()
                        }
                    },
                    onRelease: {
                        let held = Date().timeIntervalSince(holdStartTime ?? Date())
                        intentToRecord = false
                        if held < 0.4 {
                            // Quick tap — abort
                            if speechService.isRecording { speechService.stop() }
                            overlayExpanded = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showOverlay = false
                            }
                            showHoldHintToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                showHoldHintToast = false
                            }
                        } else if speechService.isRecording {
                            SoundManager.shared.playRecordingCaptured()
                            speechService.stop()
                        }
                    }
                ))
                .disabled(!speechService.permissionGranted)
                .accessibilityLabel("Record your voice")
                .accessibilityHint("Hold to record, release when done")
            }
            .opacity(overlayExpanded ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: overlayExpanded)
            .padding(.bottom, 60)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Step 2: Confirm

    private var confirmStep: some View {
        VStack(spacing: 24) {
            Spacer()

            if isGeneratingTitle {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Generating summary...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Preview card
                VStack(alignment: .leading, spacing: 16) {
                    // Type + title
                    HStack(spacing: 12) {
                        if let type = selectedType {
                            ZStack {
                                Circle()
                                    .fill(type.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: type.icon)
                                    .font(.system(size: 15))
                                    .foregroundStyle(type.color)
                            }
                        }

                        Text(generatedTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }

                    // Summary
                    Text(generatedSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Waveform preview
                    if !waveformSamples.isEmpty {
                        WaveformView(
                            samples: waveformSamples,
                            barColor: (selectedType?.color ?? BudgeteerColors.green).opacity(0.3),
                            activeColor: (selectedType?.color ?? BudgeteerColors.green).opacity(0.6),
                            height: 24
                        )
                    }
                }
                .padding(20)
                .background(theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)

                if let error = postError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            Spacer()

            // Action buttons
            if !isGeneratingTitle {
                VStack(spacing: 12) {
                    // Post button
                    Button {
                        postRecording()
                    } label: {
                        HStack {
                            if isPosting {
                                ProgressView().tint(.black)
                            }
                            Text(isPosting ? "Posting..." : "Post")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedType?.color ?? BudgeteerColors.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isPosting)

                    // Re-record
                    Button {
                        speechService.clearAudioFile()
                        speechService.saveAudioToFile = true
                        waveformSamples = []
                        generatedTitle = ""
                        generatedSummary = ""
                        postError = nil
                        step = 1
                    } label: {
                        Text("Re-record")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Recording Logic

    private func startRecording() {
        SoundManager.shared.playRecordingStart()
        secondsRemaining = 15

        do {
            try speechService.start()
            if speechService.lastError != nil { return }
            startCountdown()
        } catch {
            print("[Budgeteer] Town Hall recording start failed: \(error.localizedDescription)")
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            for remaining in stride(from: 14, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsRemaining = remaining
                if remaining <= 3 && remaining > 0 {
                    SoundManager.shared.playCountdownTick()
                }
            }
            // Auto-stop at 0
            if speechService.isRecording {
                SoundManager.shared.playRecordingCaptured()
                speechService.stop()
            }
        }
    }

    private func finishRecording() {
        countdownTask?.cancel()
        overlayExpanded = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            showOverlay = false
        }

        let transcript = speechService.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            step = 1
            return
        }

        // Extract waveform from saved audio
        if let url = speechService.audioFileURL {
            waveformSamples = SpeechService.extractWaveform(from: url)
        }

        // Generate title + summary
        step = 2
        isGeneratingTitle = true

        Task {
            do {
                let result = try await ClaudeService.shared.generatePostSummary(
                    transcript: transcript,
                    type: selectedType?.rawValue ?? "feedback"
                )
                await MainActor.run {
                    generatedTitle = result.title
                    generatedSummary = result.summary
                    isGeneratingTitle = false
                }
            } catch {
                await MainActor.run {
                    // Fallback: use raw transcript
                    generatedTitle = String(transcript.prefix(40))
                    generatedSummary = transcript
                    isGeneratingTitle = false
                }
            }
        }
    }

    private func postRecording() {
        guard let audioURL = speechService.audioFileURL,
              let type = selectedType else { return }

        isPosting = true
        postError = nil

        Task {
            do {
                try await townHallService.createPost(
                    audioURL: audioURL,
                    transcript: speechService.transcript,
                    title: generatedTitle,
                    summary: generatedSummary,
                    type: type,
                    waveformSamples: waveformSamples
                )
                await MainActor.run {
                    SoundManager.shared.playPostSubmitted()
                    speechService.clearAudioFile()
                    onPosted()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    if !networkMonitor.isConnected {
                        postError = "Queued for upload — will post when you're back online."
                        SoundManager.shared.playPostSubmitted()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            speechService.clearAudioFile()
                            onPosted()
                            dismiss()
                        }
                    } else {
                        postError = "Couldn't post. Try again."
                        isPosting = false
                    }
                }
            }
        }
    }
}
