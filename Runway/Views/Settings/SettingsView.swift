import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self)  private var theme

    @State private var budgetText   = ""
    @State private var wasCancelled = false
    @State private var devTapCount  = 0
    @State private var showDevMenu  = false

    @FocusState private var budgetFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.25), value: theme.isLight)

                List {
                    // Appearance
                    Section {
                        Picker("Theme", selection: Bindable(theme).appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(theme.card)
                    } header: {
                        Text("Appearance").foregroundStyle(.secondary)
                    }

                    // Budget
                    Section {
                        HStack {
                            Text("Monthly Budget").foregroundStyle(.primary)
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("$").foregroundStyle(.secondary)
                                TextField("0", text: $budgetText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(.primary)
                                    .fixedSize()
                                    .focused($budgetFocused)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { budgetFocused = true }
                        .listRowBackground(theme.card)
                        .onChange(of: budgetFocused) { _, focused in
                            if focused { budgetText = "" }
                        }
                    } header: {
                        Text("Budget").foregroundStyle(.secondary)
                    }
                    // Privacy
                    Section {
                        Button {
                            if let url = URL(string: "https://wadesellers.github.io/Budgeteer/privacy") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Text("Privacy Policy").foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .listRowBackground(theme.card)
                    } header: {
                        Text("Legal").foregroundStyle(.secondary)
                    }

                    // Developer menu (hidden — tap version 5 times to reveal)
                    if showDevMenu {
                        Section {
                            Button("Reset Privacy Consent") {
                                UserDefaults.standard.removeObject(forKey: "hasAcceptedPrivacy")
                            }
                            .foregroundStyle(.orange)
                            .listRowBackground(theme.card)

                            Button("Reset Onboarding") {
                                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                            }
                            .foregroundStyle(.orange)
                            .listRowBackground(theme.card)

                            Button("Delete All Transactions") {
                                // Handled by caller — placeholder for now
                            }
                            .foregroundStyle(.red)
                            .listRowBackground(theme.card)
                        } header: {
                            Text("Developer").foregroundStyle(.orange)
                        }
                    }

                    // Version footer — tap 5 times to toggle dev menu
                    Section {
                        HStack {
                            Spacer()
                            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                            Text("Budgeteer v\(version) (\(build))")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            devTapCount += 1
                            if devTapCount >= 5 {
                                withAnimation { showDevMenu.toggle() }
                                devTapCount = 0
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
            .foregroundStyle(.primary)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { wasCancelled = true; dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.foregroundStyle(BudgeteerColors.green)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Button("Clear") { budgetText = "" }
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Done") { budgetFocused = false }
                            .foregroundStyle(BudgeteerColors.green)
                    }
                }
            }
            .onAppear {
                budgetText = String(Int(budgetManager.monthlyBudget))
            }
            .onDisappear {
                if !wasCancelled { applyChanges() }
            }
            .preferredColorScheme(theme.resolvedColorScheme)
        }
    }

    // MARK: - Save

    private func applyChanges() {
        if let amount = Double(budgetText), amount > 0 {
            budgetManager.monthlyBudget = amount
        }
    }

    private func save() {
        applyChanges()
        dismiss()
    }
}
