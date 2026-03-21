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
    @State private var displayedAmount: Int = 0
    @State private var animationTimer: Timer?
    @State private var showButtons = false
    @State private var buttonRevealTask: Task<Void, Never>?

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
            let W = geo.size.width
            let H = geo.size.height

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

                // Main content
                VStack(spacing: 0) {
                    Spacer()

                    // Title
                    VStack(spacing: 12) {
                        Text("Set Your Budget")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
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
                        Text("\(displayedAmount)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: Double(displayedAmount)))
                            .animation(.snappy(duration: 0.2), value: displayedAmount)
                    }
                    .padding(.bottom, 4)

                    Text("You can change this anytime in Settings.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    // Clear button — fades in when amount > 0
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            amount = 0
                        }
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
                    .padding(.top, 10)
                    .opacity(amount > 0 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: amount > 0)

                    Spacer()

                    // Bill buttons
                    HStack(spacing: 8) {
                        ForEach(denominations, id: \.self) { denom in
                            BillButton(
                                denomination: denom,
                                color: billColor(for: denom)
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
        .onChange(of: amount) { _, newValue in
            displayedAmount = newValue
        }
    }

    // MARK: - Add Bill

    private func addBill(denomination: Int, from buttonFrame: CGRect, in geo: GeometryProxy) {
        amount += denomination

        // Haptic
        let generator = UIImpactFeedbackGenerator(style: denomination >= 50 ? .medium : .light)
        generator.impactOccurred()

        // Hide buttons while tapping, reveal after a pause
        if showButtons {
            withAnimation(.easeOut(duration: 0.15)) { showButtons = false }
        }
        buttonRevealTask?.cancel()
        buttonRevealTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
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
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(.spring(response: 0.15), value: isPressed)
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
