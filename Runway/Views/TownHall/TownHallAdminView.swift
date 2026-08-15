import SwiftUI

/// Developer-only admin view for managing Town Hall posts and recording voice replies.
/// Accessed from the developer menu (5-tap Easter egg in Settings).
struct TownHallAdminView: View {

    let townHallService: TownHallService

    @Environment(ThemeManager.self) private var theme
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPost: PostRecord?
    @State private var showReplySheet = false
    @State private var audioPlayer = AudioPlayerService()

    var isAdmin: Bool {
        townHallService.deviceID == Secrets.adminDeviceID
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                if townHallService.posts.isEmpty {
                    VStack(spacing: 12) {
                        Text("No posts yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(townHallService.posts) { post in
                            adminPostRow(post)
                                .listRowBackground(theme.card)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Town Hall Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await townHallService.fetchPosts() }
        .sheet(isPresented: $showReplySheet) {
            if let post = selectedPost {
                AdminReplySheet(
                    post: post,
                    townHallService: townHallService,
                    onReplied: { selectedPost = nil }
                )
                .environment(theme)
                .environment(networkMonitor)
            }
        }
    }

    private func adminPostRow(_ post: PostRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: post.type.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(post.type.color)

                Text(post.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Text(post.status.rawValue)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(post.status).opacity(0.15))
                    .foregroundStyle(statusColor(post.status))
                    .clipShape(Capsule())
            }

            // Summary
            Text(post.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Reaction counts
            HStack(spacing: 12) {
                Text("🙋 \(post.reactions.meToo)")
                Text("💡 \(post.reactions.greatIdea)")
                Text("🔧 \(post.reactions.pleaseFix)")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            // Actions
            HStack(spacing: 16) {
                // Reply
                if post.status != .replied {
                    Button {
                        selectedPost = post
                        showReplySheet = true
                    } label: {
                        Label("Reply", systemImage: "mic.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BudgeteerColors.green)
                    }
                }

                // Hide/show
                Button {
                    Task {
                        let newStatus: PostStatus = post.status == .hidden ? .active : .hidden
                        try? await townHallService.setPostStatus(post, status: newStatus)
                    }
                } label: {
                    Label(
                        post.status == .hidden ? "Unhide" : "Hide",
                        systemImage: post.status == .hidden ? "eye" : "eye.slash"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                }

                Spacer()

                // Play
                Button {
                    playAdminPost(post)
                } label: {
                    Image(systemName: audioPlayer.currentPostID == post.id && audioPlayer.isPlaying
                        ? "stop.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: PostStatus) -> Color {
        switch status {
        case .active:  return BudgeteerColors.green
        case .replied: return .blue
        case .hidden:  return .orange
        }
    }

    private func playAdminPost(_ post: PostRecord) {
        if audioPlayer.currentPostID == post.id && audioPlayer.isPlaying {
            audioPlayer.stop()
            return
        }
        Task {
            if let url = await townHallService.downloadAudio(for: post) {
                audioPlayer.play(url: url, postID: post.id)
            }
        }
    }
}

// MARK: - Admin Reply Sheet

private struct AdminReplySheet: View {

    let post: PostRecord
    let townHallService: TownHallService
    let onReplied: () -> Void

    @Environment(ThemeManager.self) private var theme
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var speechService = SpeechService()
    @State private var phase: ReplyPhase = .ready
    @State private var showOverlay = false
    @State private var overlayExpanded = false
    @State private var holdStartTime: Date?
    @State private var secondsRemaining = 15
    @State private var countdownTask: Task<Void, Never>?
    @State private var generatedTitle = ""
    @State private var waveformSamples: [Float] = []
    @State private var isPosting = false

    private enum ReplyPhase { case ready, recording, confirming }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Original post context
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Replying to:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tertiary)
                        Text(post.title)
                            .font(.subheadline.weight(.semibold))
                        Text(post.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer()

                    // Record / confirm
                    switch phase {
                    case .ready, .recording:
                        VStack(spacing: 16) {
                            Text("Hold to record your reply")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button(action: {}) {
                                ZStack {
                                    Circle()
                                        .fill(overlayExpanded ? .clear : BudgeteerColors.green)
                                        .frame(width: 80, height: 80)
                                        .shadow(color: BudgeteerColors.green.opacity(0.4), radius: 15)

                                    Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(HoldButtonStyle(
                                onPress: {
                                    holdStartTime = Date()
                                    startReplyRecording()
                                },
                                onRelease: {
                                    let held = Date().timeIntervalSince(holdStartTime ?? Date())
                                    guard held >= 0.4, speechService.isRecording else {
                                        if speechService.isRecording { speechService.stop() }
                                        return
                                    }
                                    SoundManager.shared.playRecordingCaptured()
                                    speechService.stop()
                                }
                            ))
                        }
                        .opacity(overlayExpanded ? 0 : 1)

                    case .confirming:
                        VStack(spacing: 16) {
                            Text(generatedTitle.isEmpty ? "Reply recorded" : generatedTitle)
                                .font(.headline)
                            Text(speechService.transcript)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            if !waveformSamples.isEmpty {
                                WaveformView(
                                    samples: waveformSamples,
                                    barColor: BudgeteerColors.green.opacity(0.3),
                                    height: 24
                                )
                                .padding(.horizontal, 20)
                            }

                            Button {
                                postReply()
                            } label: {
                                HStack {
                                    if isPosting { ProgressView().tint(.black) }
                                    Text(isPosting ? "Posting..." : "Post Reply")
                                        .font(.headline.weight(.bold))
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(BudgeteerColors.green)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .disabled(isPosting)
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer()
                }

                if showOverlay {
                    RecordingOverlayView(
                        transcript: speechService.transcript,
                        isWaitingForFinal: false,
                        recordingColor: BudgeteerColors.green,
                        isExpanded: overlayExpanded,
                        showReleaseHint: true,
                        showQuestionPrompt: false,
                        micCenterFraction: 0.7
                    )
                    .environment(theme)
                    .overlay(alignment: .top) {
                        if overlayExpanded {
                            Text("\(secondsRemaining)s")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.3))
                                .padding(.top, 60)
                        }
                    }
                }
            }
            .navigationTitle("Reply")
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
        .onDisappear { countdownTask?.cancel() }
        .onChange(of: speechService.isRecording) { _, isRecording in
            guard !isRecording, phase == .recording else { return }
            finishReplyRecording()
        }
    }

    private func startReplyRecording() {
        SoundManager.shared.playRecordingStart()
        secondsRemaining = 15
        phase = .recording
        showOverlay = true
        overlayExpanded = true

        do {
            try speechService.start()
            countdownTask = Task { @MainActor in
                for remaining in stride(from: 14, through: 0, by: -1) {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    secondsRemaining = remaining
                    if remaining <= 3 && remaining > 0 { SoundManager.shared.playCountdownTick() }
                }
                if speechService.isRecording {
                    SoundManager.shared.playRecordingCaptured()
                    speechService.stop()
                }
            }
        } catch {
            phase = .ready
            overlayExpanded = false
            showOverlay = false
        }
    }

    private func finishReplyRecording() {
        countdownTask?.cancel()
        overlayExpanded = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { showOverlay = false }

        guard !speechService.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .ready
            return
        }

        if let url = speechService.audioFileURL {
            waveformSamples = SpeechService.extractWaveform(from: url)
        }

        // Generate title
        Task {
            if let result = try? await ClaudeService.shared.generatePostSummary(
                transcript: speechService.transcript,
                type: "developer reply"
            ) {
                await MainActor.run { generatedTitle = result.title }
            }
        }

        phase = .confirming
    }

    private func postReply() {
        guard let audioURL = speechService.audioFileURL else { return }
        isPosting = true

        Task {
            do {
                try await townHallService.createReply(
                    for: post,
                    audioURL: audioURL,
                    transcript: speechService.transcript,
                    title: generatedTitle,
                    waveformSamples: waveformSamples
                )
                await MainActor.run {
                    SoundManager.shared.playPostSubmitted()
                    speechService.clearAudioFile()
                    onReplied()
                    dismiss()
                }
            } catch {
                await MainActor.run { isPosting = false }
            }
        }
    }
}
