import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self)  private var theme

    @State private var budgetText   = ""
    @State private var wasCancelled = false

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
                    Button("Save") { save() }.foregroundStyle(RunwayColors.green)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Button("Clear") { budgetText = "" }
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Done") { budgetFocused = false }
                            .foregroundStyle(RunwayColors.green)
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
