import SwiftUI

// MARK: - Flying Bill

private struct FlyingBill: Identifiable {
    let id = UUID()
    let denomination: Int
    let startX: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let drift: CGFloat
    let rotation: Double
}

// MARK: - Bill Counter View

struct BillCounterView<Buttons: View>: View {
    @Binding var amount: Int
    let pileHeight: CGFloat
    @ViewBuilder let buttons: Buttons

    @State private var flyingBills: [FlyingBill] = []
    @State private var displayedAmount: Int = -1  // sentinel; set from binding on appear
    @State private var animationTimer: Timer?
    @State private var showButtons = false
    @State private var buttonRevealTask: Task<Void, Never>?
    @State private var demoPlayed = false
    @State private var demoHighlightIndex: Int? = nil  // which bill button to highlight
    @State private var demoTask: Task<Void, Never>?
    @State private var buttonFrames: [Int: CGRect] = [:]  // index → frame for demo use

    private let denominations = [5, 10, 20, 50, 100]

    // Bill colors — darker for bigger bills
    private func billColor(for denomination: Int) -> Color {
        switch denomination {
        case 5:   return Color(red: 0.2, green: 0.55, blue: 0.3)
        case 10:  return Color(red: 0.18, green: 0.5, blue: 0.35)
        case 20:  return Color(red: 0.15, green: 0.48, blue: 0.3)
        case 50:  return Color(red: 0.12, green: 0.44, blue: 0.28)
        case 100: return Color(red: 0.1, green: 0.4, blue: 0.25)
        default:  return Color.green
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Flying bills layer
                ForEach(flyingBills) { bill in
                    Text("$\(bill.denomination)")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(billColor(for: bill.denomination).opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .rotationEffect(.degrees(bill.rotation))
                        .modifier(FlyingBillModifier(
                            startX: bill.startX,
                            startY: bill.startY,
                            endY: bill.endY,
                            drift: bill.drift
                        ))
                }
                .accessibilityHidden(true)

                // Main content
                VStack(spacing: 0) {
                    Spacer()

                    // Title
                    VStack(spacing: 12) {
                        Text("Set Your Budget")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        Text("How much do you want to spend\nthis month?")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // Amount display
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("$")
                            .font(.system(size: 44, weight: .light, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("\(max(0, displayedAmount))")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: Double(displayedAmount)))
                            .animation(.snappy(duration: 0.2), value: displayedAmount)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Budget amount: $\(max(0, displayedAmount))")
                    .padding(.bottom, 4)

                    Text("You can change this anytime in Settings.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    // Clear button — fades in when amount > 0
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            amount = 0
                        }
                        SoundManager.shared.playBudgetCleared()
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Clear budget amount")
                    .padding(.top, 10)
                    .opacity(amount > 0 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: amount > 0)

                    Spacer()

                    // Bill buttons
                    HStack(spacing: 8) {
                        ForEach(Array(denominations.enumerated()), id: \.element) { index, denom in
                            BillButton(
                                denomination: denom,
                                color: billColor(for: denom),
                                isHighlighted: demoHighlightIndex == index,
                                onFrameChange: { frame in buttonFrames[index] = frame }
                            ) { buttonFrame in
                                addBill(denomination: denom, from: buttonFrame, in: geo)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)

                    // Continue / Back buttons — fade in after user pauses
                    buttons
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16 + pileHeight)
                        .opacity(showButtons ? 1 : 0)
                        .animation(.easeInOut(duration: 0.6), value: showButtons)
                }
            }
        }
        .onAppear {
            if displayedAmount == -1 {
                displayedAmount = amount
            }
            // If returning with a budget already set, show buttons immediately
            if amount > 0 {
                showButtons = true
            }
            // Play demo animation on first appearance (only if budget is 0)
            if !demoPlayed && amount == 0 {
                demoPlayed = true
                playDemo()
            }
        }
        .onChange(of: amount) { _, newValue in
            displayedAmount = newValue
        }
    }

    // MARK: - Demo Animation

    private func playDemo() {
        demoTask = Task { @MainActor in
            // Start almost immediately
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }

            // Demo sequence: (buttonIndex, holdDuration)
            // All holds are longer / more bills to make it exciting
            let sequence: [(index: Int, holdDuration: Double)] = [
                (2, 0.8),   // $20 — several bills
                (0, 0.6),   // $5 — a few bills
                (4, 2.0),   // $100 — long rapid fire
                (1, 0.7),   // $10 — several bills
                (3, 1.5),   // $50 — long hold
            ]

            for step in sequence {
                guard !Task.isCancelled else { return }

                // Press down
                withAnimation(.easeInOut(duration: 0.15)) {
                    demoHighlightIndex = step.index
                }

                // Spawn flying bills during the hold — fast ticks for lots of bills
                let denom = denominations[step.index]
                let tickInterval: Double = 0.12
                let tickCount = max(2, Int(step.holdDuration / tickInterval))

                for tick in 0..<tickCount {
                    guard !Task.isCancelled else { return }
                    if tick > 0 {
                        try? await Task.sleep(for: .seconds(tickInterval))
                        guard !Task.isCancelled else { return }
                    }
                    // Spawn a demo flying bill (no amount added)
                    if let frame = buttonFrames[step.index] {
                        spawnDemoBill(denomination: denom, from: frame)
                    }
                }

                // If hold is short, wait for remaining duration
                let elapsed = Double(tickCount) * tickInterval
                if elapsed < step.holdDuration {
                    try? await Task.sleep(for: .seconds(step.holdDuration - elapsed))
                }

                // Release
                withAnimation(.easeOut(duration: 0.2)) {
                    demoHighlightIndex = nil
                }

                // Pause between presses
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
    }

    private func spawnDemoBill(denomination: Int, from frame: CGRect) {
        SoundManager.shared.playBillTap()
        let bill = FlyingBill(
            denomination: denomination,
            startX: frame.midX,
            startY: frame.minY,
            endY: frame.minY - 200,
            drift: CGFloat.random(in: -30...30),
            rotation: Double.random(in: -20...20)
        )
        flyingBills.append(bill)
        let billId = bill.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            flyingBills.removeAll { $0.id == billId }
        }
    }

    private func stopDemo() {
        demoTask?.cancel()
        demoTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            demoHighlightIndex = nil
        }
    }

    // MARK: - Add Bill

    private func addBill(denomination: Int, from buttonFrame: CGRect, in geo: GeometryProxy) {
        // Stop demo on first real user interaction
        if demoTask != nil { stopDemo() }

        amount += denomination
        SoundManager.shared.playBillTap()

        // Haptic
        let generator = UIImpactFeedbackGenerator(style: denomination >= 50 ? .medium : .light)
        generator.impactOccurred()

        // Hide buttons while tapping, reveal after a pause
        if showButtons {
            withAnimation(.easeOut(duration: 0.15)) { showButtons = false }
        }
        buttonRevealTask?.cancel()
        buttonRevealTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.6)) { showButtons = true }
        }

        // Spawn a flying bill
        let startX = buttonFrame.midX
        let startY = buttonFrame.minY
        let endY = geo.size.height * 0.3  // fly up toward the amount display

        let bill = FlyingBill(
            denomination: denomination,
            startX: startX,
            startY: startY,
            endY: endY,
            drift: CGFloat.random(in: -30...30),
            rotation: Double.random(in: -20...20)
        )

        flyingBills.append(bill)

        // Remove after animation
        let billId = bill.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            flyingBills.removeAll { $0.id == billId }
        }
    }
}

// MARK: - Flying Bill Animation Modifier

private struct FlyingBillModifier: ViewModifier {
    let startX: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let drift: CGFloat

    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .position(
                x: startX + drift * progress,
                y: startY + (endY - startY) * progress
            )
            .opacity(1.0 - Double(progress) * 1.5)  // fade out before reaching top
            .scaleEffect(1.0 - progress * 0.3)
            .onAppear {
                withAnimation(.easeOut(duration: 0.55)) {
                    progress = 1.0
                }
            }
    }
}

// MARK: - Bill Button

private struct BillButton: View {
    let denomination: Int
    let color: Color
    var isHighlighted: Bool = false
    var onFrameChange: ((CGRect) -> Void)? = nil
    let onTap: (CGRect) -> Void

    @State private var isPressed = false
    @State private var holdTimer: Timer?
    @State private var tickRate: TimeInterval = 0.25
    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        ZStack {
            // Bill background
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .shadow(color: color.opacity(0.4), radius: isPressed ? 2 : 6, y: isPressed ? 1 : 3)

            // Inner border — like a real bill's printed border
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                .padding(3)

            // Content
            VStack(spacing: 1) {
                Text("$\(denomination)")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add $\(denomination)")
        .accessibilityHint("Tap to add $\(denomination) to your budget. Hold for rapid entry.")
        .accessibilityAddTraits(.isButton)
        .scaleEffect(isPressed ? 0.93 : (isHighlighted ? 0.93 : 1.0))
        .animation(.spring(response: 0.15), value: isPressed)
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ButtonFrameKey.self,
                        value: geo.frame(in: .named("billCounter"))
                    )
                }
            )
            .onPreferenceChange(ButtonFrameKey.self) { frame in
                buttonFrame = frame
                onFrameChange?(frame)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onTap(buttonFrame)
                        startHoldTimer()
                    }
                    .onEnded { _ in
                        isPressed = false
                        stopHoldTimer()
                    }
            )
    }

    private func startHoldTimer() {
        tickRate = 0.22
        holdTimer = Timer.scheduledTimer(withTimeInterval: tickRate, repeats: false) { _ in
            Task { @MainActor in
                guard isPressed else { return }
                onTap(buttonFrame)
                accelerate()
            }
        }
    }

    private func accelerate() {
        // Speed up: 0.22 → 0.15 → 0.10 → 0.06 (min)
        tickRate = max(0.06, tickRate * 0.78)
        holdTimer = Timer.scheduledTimer(withTimeInterval: tickRate, repeats: false) { _ in
            Task { @MainActor in
                guard isPressed else { return }
                onTap(buttonFrame)
                accelerate()
            }
        }
    }

    private func stopHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        tickRate = 0.22
    }
}

// MARK: - Preference Key

private struct ButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
