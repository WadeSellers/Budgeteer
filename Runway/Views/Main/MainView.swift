import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(BudgetManager.self)  private var budgetManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(ThemeManager.self)   private var theme
    @Environment(HintManager.self)   private var hintManager
    @Environment(\.modelContext)      private var modelContext
    @Environment(\.scenePhase)        private var scenePhase

    @Query(sort: \Transaction.timestamp, order: .reverse)
    private var transactions: [Transaction]

    // Sheet visibility
    @State private var showManualEntry       = false
    @State private var showTransactions      = false   // full month
    @State private var showTodayTransactions = false   // active day
    @State private var showSettings          = false
    @State private var showPrivacyConsent    = false
    @State private var consentContentVisible = false

    @AppStorage("hasAcceptedPrivacy") private var hasAcceptedPrivacy = false

    // Toast + edit
    @State private var toastTransaction:  Transaction?
    @State private var toastDismissTask:  Task<Void, Never>?
    @State private var editingTransaction: Transaction?

    // Day selection (nil = today mode)
    @State private var selectedDate: Date? = nil

    // Tracks the calendar date when the app was last active, so we can detect
    // a day rollover when the app returns from background.
    @State private var lastActiveDay = Calendar.current.startOfDay(for: Date())

    private var activeDate: Date     { selectedDate ?? Date() }
    private var isViewingToday: Bool { selectedDate == nil }

    // Voice recording state
    @State private var speechService       = SpeechService()
    @State private var isProcessing        = false
    @State private var waitingForFinal     = false   // true between release and isFinal
    @State private var recordingError:     String?
    @State private var holdStartTime:     Date?
    @State private var showHoldHint       = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Recording overlay lifecycle — decoupled so the collapse animation can
    // play out before the view is removed from the hierarchy.
    @State private var showRecordingOverlay = false   // view exists in hierarchy
    @State private var overlayExpanded      = false   // drives the circle animation

    /// Animation helper: returns nil when Reduce Motion is on, so SwiftUI
    /// skips the animated transition.
    private func motionAnimation(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    private var meterColor: Color {
        budgetManager.meterColor(transactions).color
    }

    /// The heatmap colour for the ACTIVE day (today, or the selected past day).
    /// Used by the mic button and recording overlay so they always show the same
    /// "how am I doing on this day?" signal — and update when you tap a new day.
    private var todayRecordingColor: Color {
        let daysInMonth = Double(max(1, Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30))
        let dailyBudget = budgetManager.monthlyBudget > 0 ? budgetManager.monthlyBudget / daysInMonth : 1
        let spent       = budgetManager.totalSpent(for: activeDate, in: transactions)
        return BudgeteerColors.spendingColor(spent: spent, dailyBudget: dailyBudget)
    }

    var body: some View {
        ZStack {

            // ── Layer 1: Background ──────────────────────────────────────────
            theme.appBackground.ignoresSafeArea()

            // ── Layer 2: Main content ────────────────────────────────────────
            // Fades out when the recording overlay takes over
            VStack(spacing: 0) {
                CalendarHeatmapView(
                    transactions: transactions,
                    dailyBudget: {
                        let days = Double(max(1, Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30))
                        return budgetManager.monthlyBudget > 0 ? budgetManager.monthlyBudget / days : 1
                    }(),
                    monthlyBudget: budgetManager.monthlyBudget,
                    selectedDate: selectedDate,
                    onDayTap: { date in selectedDate = date },
                    onBudgetTap: { showSettings = true }
                )
                .padding(.top, 8)

                Spacer()
                meterSection
                Spacer()
                recordingErrorView
                // Reserve space so content never overlaps the mic row
                Color.clear.frame(height: 148)
            }
            .safeAreaPadding(.top)
            .opacity(overlayExpanded ? 0 : 1)

            // ── Layer 3: Recording overlay ───────────────────────────────────
            // Circle grows from mic-button dot to fill the entire screen, then
            // springs back to a dot on release. The view stays in the hierarchy
            // for ~0.55 s after release so the collapse animation can finish.
            if showRecordingOverlay {
                if showPrivacyConsent {
                    // Consent mode: green circle expands but shows consent content
                    // instead of transcript
                    RecordingOverlayView(
                        transcript: "",
                        isWaitingForFinal: false,
                        recordingColor: todayRecordingColor,
                        isExpanded: overlayExpanded,
                        hideTranscript: true
                    )
                    .environment(theme)

                    // Consent content floats on top of the green
                    PrivacyConsentView(onAccept: dismissConsent)
                        .opacity(consentContentVisible ? 1 : 0)
                        .animation(
                            consentContentVisible
                                ? .easeIn(duration: 0.25).delay(0.3)
                                : .easeOut(duration: 0.2),
                            value: consentContentVisible
                        )
                } else {
                    RecordingOverlayView(
                        transcript: speechService.transcript,
                        isWaitingForFinal: waitingForFinal,
                        recordingColor: todayRecordingColor,
                        isExpanded: overlayExpanded,
                        showReleaseHint: true
                    )
                    .environment(theme)
                }
            }

            // ── Layer 4: Mic row ─────────────────────────────────────────────
            // Always on top so the hold gesture is never interrupted by the overlay
            VStack(spacing: 0) {
                Spacer()
                micRow
            }

            // ── Layer 5: Hold hint — always present, driven by opacity ─────
            VStack {
                Spacer()
                Text("Hold the mic to record")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(.bottom, 170)
                    .accessibilityLabel("Hint: Hold the mic button to record")
            }
            .opacity(showHoldHint ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: showHoldHint)
            .accessibilityHidden(!showHoldHint)
            .zIndex(9)

            // ── Layer 6: Toast ──────────────────────────────────────────────
            // Non-blocking "saved" notification — sits near the top of the screen
            if let t = toastTransaction {
                VStack {
                    TransactionToast(transaction: t, onTap: {
                        toastDismissTask?.cancel()
                        withAnimation(.spring(response: 0.3)) { toastTransaction = nil }
                        editingTransaction = t
                    }, onDismiss: {
                        withAnimation(.spring(response: 0.3)) { toastTransaction = nil }
                    })
                    .padding(.top, 12)
                    Spacer()
                }
                .zIndex(10)
            }
        }
        .foregroundStyle(.primary)
        .animation(motionAnimation(.easeInOut(duration: 0.25)), value: overlayExpanded)
        .animation(.easeInOut(duration: 0.2),  value: recordingError)

        // Edit sheet — opened from toast tap or (future) transaction list
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionSheet(transaction: transaction) {
                // onDelete: clear toast if the deleted transaction was showing
                toastDismissTask?.cancel()
                toastTransaction = nil
            }
            .environment(theme)
        }
        // Manual text-entry sheet
        .sheet(isPresented: $showManualEntry) {
            ManualEntrySheet(backdateDate: selectedDate) { amount, desc, cat in
                save(amount: amount, description: desc, category: cat)
            }
            .environment(networkMonitor)
            .environment(theme)
        }
        .sheet(isPresented: $showTransactions) {
            TransactionListSheet()
                .environment(budgetManager)
                .environment(theme)
        }
        .sheet(isPresented: $showTodayTransactions) {
            TransactionListSheet(filterDate: activeDate)
                .environment(budgetManager)
                .environment(theme)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(budgetManager)
                .environment(theme)
                .environment(hintManager)
        }
        // When the recognizer delivers its final result, isRecording flips to false.
        // That's our signal to process — the transcript is now complete.
        .onChange(of: speechService.isRecording) { _, isRecording in
            guard !isRecording, waitingForFinal else { return }
            waitingForFinal = false
            let text = speechService.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            processTranscript(text)
        }
        // Drive the overlay lifecycle separately from the recording flag so the
        // collapse animation has time to finish before the view is removed.
        .onChange(of: activelyRecording) { _, isActive in
            if !isActive && showRecordingOverlay {
                // Collapse the overlay when recording ends
                overlayExpanded = false
                // Keep the view alive until the collapse spring settles (≈ 0.5 s).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    showRecordingOverlay = false
                }
            }
        }
        // When the app comes back to the foreground, check if the calendar date
        // has rolled over. If it has, snap back to today so nothing is stale.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let today = Calendar.current.startOfDay(for: Date())
            if today != lastActiveDay {
                lastActiveDay = today
                selectedDate  = nil
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, connected in
            if connected { processPending() }
        }
        .onChange(of: transactions.count) { _, _ in
            budgetManager.checkThresholds(transactions)
        }
        .onAppear {
            processPending()
            budgetManager.checkThresholds(transactions)
            speechService.prewarm()   // kick off early if permissions already granted
            hintManager.trackAppOpen()
            // Sync purchase count from existing transactions so hints show correctly
            if hintManager.purchaseCount == 0 && !transactions.isEmpty {
                hintManager.purchaseCount = transactions.count
            }
        }
        .task {
            // Permissions are now handled during onboarding.
            // Just ensure speech is prewarmed if permissions were already granted.
            if !speechService.permissionGranted {
                await speechService.requestPermissions()
            }
        }
    }

    // MARK: - Subviews

    private var meterSection: some View {
        let allowance    = budgetManager.dailyAllowance(transactions)
        let rem          = budgetManager.remaining(transactions)
        let isOver       = rem < 0
        let spentOnDay   = budgetManager.totalSpent(for: activeDate, in: transactions)

        let monthName = Date().formatted(.dateTime.month(.wide))
        let daysLeft  = budgetManager.daysRemainingInMonth()

        let heroLabel = isViewingToday
            ? "Today's total spend"
            : "\(activeDate.formatted(.dateTime.month(.abbreviated).day())) spend"

        return VStack(spacing: 20) {

            // Hero — spent on active day (tap to see that day's purchases)
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(heroLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !isViewingToday {
                        Button { selectedDate = nil } label: {
                            Text("Today")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.surfaceMid)
                                .clipShape(Capsule())
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                        .accessibilityLabel("Return to today")
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isViewingToday)

                Button {
                    showTodayTransactions = true
                } label: {
                    Text(String(format: "$%.0f", spentOnDay))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: spentOnDay)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(heroLabel): \(String(format: "$%.0f", spentOnDay))")
                .accessibilityHint("Tap to see purchases for this day")
                .overlay(alignment: .topTrailing) {
                    HintBadge(
                        message: "Tap to see today's purchases",
                        hintType: .totalSpend,
                        anchor: .topTrailing
                    )
                    .offset(x: 14, y: -4)
                }
            }

            // Stat cards
            HStack(spacing: 12) {
                // Left: remaining this month — tap to see full month purchases
                Button {
                    showTransactions = true
                } label: {
                    statCard {
                        Text("$ left in \(monthName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                        Text(isOver
                             ? String(format: "-$%.0f", abs(rem))
                             : String(format: "$%.0f", rem))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .foregroundStyle(isOver ? BudgeteerColors.red : meterColor)
                            .contentTransition(.numericText())
                        Text("\(daysLeft) days left in \(monthName)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(isOver
                    ? "Over budget by \(String(format: "$%.0f", abs(rem))) in \(monthName), \(daysLeft) days left"
                    : "\(String(format: "$%.0f", rem)) left in \(monthName), \(daysLeft) days left")
                .accessibilityHint("Tap to see all purchases this month")
                .overlay(alignment: .topLeading) {
                    HintBadge(
                        message: "Tap to see all your purchases this month",
                        hintType: .monthlyRemaining,
                        anchor: .topLeading
                    )
                    .offset(x: -8, y: -8)
                }

                // Right: daily allowance — informational only, no tap
                statCard {
                    Text("You can spend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(isOver
                         ? "Over budget"
                         : String(format: "$%.0f/day", allowance))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(isOver ? BudgeteerColors.red : meterColor)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("in \(monthName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(isOver
                    ? "Over budget in \(monthName)"
                    : "You can spend \(String(format: "$%.0f", allowance)) per day in \(monthName)")
            }
            .padding(.horizontal, 32)

            // Status badges
            VStack(spacing: 4) {
                if !networkMonitor.isConnected {
                    Label("Offline", systemImage: "wifi.slash")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                let pending = transactions.filter { $0.isPending }.count
                if pending > 0 {
                    Text("\(pending) pending")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func statCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var recordingErrorView: some View {
        if let err = recordingError {
            Text(err)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.bottom, 4)
                .transition(.opacity)
        }
    }

    private var micRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 28) {

                // ── Keyboard button ──────────────────────────────────────────
                Button {
                    showManualEntry = true
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .background(theme.surface)
                        .clipShape(Circle())
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Manual entry")
                .accessibilityHint("Type a purchase with the keyboard")
                .disabled(isProcessing || speechService.isRecording)
                .opacity(overlayExpanded ? 0 : 1)
                .overlay(alignment: .topTrailing) {
                    HintBadge(
                        message: "Add a purchase manually",
                        hintType: .keyboard,
                        anchor: .topTrailing
                    )
                    .offset(x: 8, y: -8)
                }

                // ── Hold-to-record mic button ────────────────────────────────
                //
                // During recording the button's own circle background is hidden —
                // it merges visually with the large red overlay circle behind it.
                // The icon floats cleanly on the red surface.
                Button(action: {}) {
                    ZStack {
                        // Circle background — clear when overlay is expanded so the icon
                        // floats cleanly on the full-screen colour circle behind it.
                        // Uses the active day's spending colour so it updates (with animation)
                        // whenever the selected calendar day changes.
                        Circle()
                            .fill(overlayExpanded ? Color.clear : todayRecordingColor)
                            .frame(width: 112, height: 112)
                            .shadow(
                                color: overlayExpanded ? .clear : todayRecordingColor.opacity(0.5),
                                radius: 20
                            )

                        // Icon
                        if isProcessing {
                            ProgressView().tint(.white).scaleEffect(1.5)
                        } else {
                            Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(.white)
                        }
                    }
                    // Animate colour changes when the selected day changes
                    .animation(.easeInOut(duration: 0.35), value: selectedDate)
                }
                .buttonStyle(HoldButtonStyle(
                    onPress: {
                        guard !isProcessing && !activelyRecording else { return }
                        holdStartTime = Date()
                        // Start recording + overlay immediately
                        startRecording()
                        if !showPrivacyConsent && !showRecordingOverlay {
                            showRecordingOverlay = true
                            DispatchQueue.main.async { overlayExpanded = true }
                        }
                    },
                    onRelease: {
                        let held = Date().timeIntervalSince(holdStartTime ?? Date())
                        if held < 0.4 {
                            // Quick tap — abort recording, collapse overlay, show hint
                            if speechService.isRecording {
                                speechService.stop()
                                waitingForFinal = false
                            }
                            overlayExpanded = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showRecordingOverlay = false
                            }
                            showHoldHint = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                showHoldHint = false
                            }
                        } else if speechService.isRecording {
                            stopAndProcess()
                        }
                    }
                ))
                .accessibilityLabel(isProcessing ? "Processing purchase" : speechService.isRecording ? "Recording, release to finish" : "Record purchase")
                .accessibilityHint(isProcessing ? "" : "Hold to record a purchase with your voice, release when done")
                .disabled(isProcessing)
                .sensoryFeedback(.impact(weight: .medium), trigger: speechService.isRecording)

                // ── Settings button ──────────────────────────────────────────
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .background(theme.surface)
                        .clipShape(Circle())
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Settings")
                .opacity(overlayExpanded ? 0 : 1)
            }

            // Status hint — hidden during recording (overlay handles context)
            Text(statusHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(overlayExpanded ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: statusHint)
        }
        .padding(.bottom, 8)
    }

    private var activelyRecording: Bool { speechService.isRecording || waitingForFinal }

    private var statusHint: String {
        if isProcessing              { return "Thinking…" }
        if waitingForFinal           { return "Got it…" }
        if speechService.isRecording { return "Release to log" }
        if !isViewingToday {
            let label = activeDate.formatted(.dateTime.month(.abbreviated).day())
            return "Hold to log for \(label)"
        }
        return "Hold to speak"
    }

    // MARK: - Recording

    private func startRecording() {
        guard hasAcceptedPrivacy else {
            // Trigger the green circle expansion but don't start recording.
            // The consent content will appear on the green overlay.
            showPrivacyConsent    = true
            showRecordingOverlay  = true
            DispatchQueue.main.async {
                overlayExpanded = true
                consentContentVisible = true
            }
            return
        }
        recordingError = nil
        SoundManager.shared.playRecordingStart()
        do {
            try speechService.start()
            // If recognizer wasn't available, start() sets lastError without throwing
            if let err = speechService.lastError {
                recordingError = err
            }
        } catch {
            recordingError = "Couldn't access microphone"
        }
    }

    private func dismissConsent() {
        hasAcceptedPrivacy    = true
        consentContentVisible = false       // fade text out first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            overlayExpanded = false          // then collapse the circle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                showPrivacyConsent   = false
                showRecordingOverlay = false
            }
        }
    }

    private func stopAndProcess() {
        // Stop audio capture. isRecording stays true until the recognizer
        // fires isFinal — onChange(of: speechService.isRecording) picks it up.
        waitingForFinal = true
        SoundManager.shared.playRecordingCaptured()
        speechService.stop()
    }

    private func processTranscript(_ transcript: String) {
        guard !transcript.isEmpty else {
            recordingError = "No speech detected — try again"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { recordingError = nil }
            return
        }

        isProcessing = true

        Task {
            do {
                let result = try await ClaudeService.shared.parseTransaction(transcript)
                await MainActor.run {
                    let t = save(amount: result.amount, description: result.description, category: result.category)
                    isProcessing = false
                    showToast(for: t)
                }
            } catch ClaudeError.networkUnavailable, ClaudeError.timeout {
                await MainActor.run {
                    savePending(rawInput: transcript)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    recordingError = error.localizedDescription
                    isProcessing   = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { recordingError = nil }
                }
            }
        }
    }

    // MARK: - Saving

    @discardableResult
    private func save(amount: Double, description: String, category: String) -> Transaction {
        let timestamp: Date
        if let sel = selectedDate {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: sel)
            comps.hour = 12; comps.minute = 0; comps.second = 0
            timestamp = Calendar.current.date(from: comps) ?? sel
        } else {
            timestamp = .now
        }
        let t = Transaction(amount: amount, transactionDescription: description,
                            category: category, timestamp: timestamp)
        modelContext.insert(t)
        do {
            try modelContext.save()
        } catch {
            // SwiftData auto-saves on the next event loop; log but don't block the user
            print("[Budgeteer] modelContext.save failed: \(error.localizedDescription)")
        }
        budgetManager.checkThresholds(transactions)
        hintManager.trackPurchase()
        return t
    }

    private func showToast(for transaction: Transaction) {
        SoundManager.shared.playPurchaseSaved()
        toastDismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            toastTransaction = transaction
        }
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3)) { toastTransaction = nil }
        }
    }

    private func savePending(rawInput: String) {
        let t = Transaction(
            amount: 0,
            transactionDescription: "Processing…",
            category: "Other",
            isPending: true,
            rawInput: rawInput
        )
        modelContext.insert(t)
        do {
            try modelContext.save()
        } catch {
            print("[Budgeteer] savePending failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Pending retry

    private func processPending() {
        let pending = transactions.filter { $0.isPending && !$0.rawInput.isEmpty }
        guard !pending.isEmpty, networkMonitor.isConnected else { return }

        Task {
            for t in pending {
                do {
                    let result = try await ClaudeService.shared.parseTransaction(t.rawInput)
                    await MainActor.run {
                        t.amount                 = result.amount
                        t.transactionDescription = result.description
                        t.category               = result.category
                        t.isPending              = false
                    }
                } catch {
                    // Will retry on next app launch or network reconnect
                    print("[Budgeteer] pending retry failed for '\(t.rawInput)': \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                do {
                    try modelContext.save()
                } catch {
                    print("[Budgeteer] processPending save failed: \(error.localizedDescription)")
                }
                budgetManager.checkThresholds(transactions)
            }
        }
    }
}

// MARK: - Hold Button Style
// Uses isPressed (UIKit touch tracking) instead of DragGesture,
// which avoids "gesture gate timed out" errors under rapid taps.

struct HoldButtonStyle: ButtonStyle {
    let onPress:   () -> Void
    let onRelease: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { onPress() } else { onRelease() }
            }
    }
}
