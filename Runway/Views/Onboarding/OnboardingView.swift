import SwiftUI

struct OnboardingView: View {
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self) private var theme
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step      = 0
    @State private var budget    = ""

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            switch step {
            case 0:  welcomeStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            default: budgetStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .foregroundStyle(.primary)
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 80))
                .foregroundStyle(RunwayColors.green)

            VStack(spacing: 12) {
                Text("Spendometer")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Text("Track your monthly spending\nwith a quick voice command.")
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

    // MARK: - Step 2: Budget

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
                Text("Enter your monthly spending limit")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(spacing: 12) {
                let isValid = (Double(budget) ?? 0) > 0
                primaryButton("Start Using Spendometer", enabled: isValid) {
                    if let amount = Double(budget), amount > 0 {
                        budgetManager.monthlyBudget = amount
                        hasCompletedOnboarding = true
                    }
                }
                backButton { step = 0 }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Reusable buttons

    private func primaryButton(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(enabled ? RunwayColors.green : Color.gray.opacity(0.4))
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
