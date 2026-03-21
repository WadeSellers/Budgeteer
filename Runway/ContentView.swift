import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(BudgetManager.self) private var budgetManager

    var body: some View {
        if hasCompletedOnboarding {
            MainView()
        } else {
            OnboardingView()
        }
    }
}
