import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showOnboardingComplete") private var showOnboardingComplete = false
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self) private var theme

    // Green curtain that drops to reveal MainView
    @State private var showCurtain = false
    @State private var curtainVisible = false

    // Welcome toast
    @State private var showWelcomeToast = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                MainView()

                // Green curtain — covers the screen, then drops away
                if showCurtain {
                    BudgeteerColors.green
                        .ignoresSafeArea()
                        .opacity(curtainVisible ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: curtainVisible)
                        .zIndex(100)
                }

                // Welcome toast
                if showWelcomeToast {
                    VStack {
                        welcomeToast
                            .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(99)
                }
            } else {
                OnboardingView()
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed && showOnboardingComplete {
                curtainReveal()
            }
        }
    }

    // MARK: - Curtain Reveal

    private func curtainReveal() {
        // Show the green curtain immediately (matches the recording overlay color)
        showCurtain = true
        curtainVisible = true

        // Give MainView a moment to render behind the curtain
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            SoundManager.shared.playCurtainReveal()
            // Drop the curtain — fade out the green to reveal MainView
            curtainVisible = false
        }

        // Remove curtain from hierarchy after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            showCurtain = false
        }

        // Toast slides in after curtain drops
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showWelcomeToast = true
            }

            dismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.3)) {
                    showWelcomeToast = false
                }
                showOnboardingComplete = false
            }
        }
    }

    // MARK: - Welcome Toast

    private var welcomeToast: some View {
        Button {
            dismissTask?.cancel()
            withAnimation(.spring(response: 0.3)) {
                showWelcomeToast = false
            }
            showOnboardingComplete = false
        } label: {
            HStack(spacing: 12) {
                Text("✅")
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(BudgeteerColors.green.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Purchase Saved")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("Your first purchase is on the board!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}
