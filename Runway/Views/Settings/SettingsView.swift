import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self)  private var theme

    @State private var budgetText        = ""
    @State private var wasCancelled      = false
    @State private var devTapCount       = 0
    @State private var showDevMenu       = false
    @State private var devConfirmation:  String?
    @State private var alertsEnabled     = false
    @State private var alertsDenied      = false

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
                    // Notifications
                    Section {
                        Toggle("Budget Alerts", isOn: $alertsEnabled)
                            .tint(BudgeteerColors.green)
                            .listRowBackground(theme.card)
                            .onChange(of: alertsEnabled) { _, enabled in
                                if enabled {
                                    Task {
                                        let granted = await NotificationService.shared.requestPermissions()
                                        if !granted {
                                            alertsEnabled = false
                                            alertsDenied  = true
                                        }
                                    }
                                }
                            }

                        if alertsDenied {
                            Text("Notifications are disabled in system Settings. Tap below to open Settings and enable them.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .listRowBackground(theme.card)

                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(BudgeteerColors.green)
                            .listRowBackground(theme.card)
                        }
                    } header: {
                        Text("Notifications").foregroundStyle(.secondary)
                    } footer: {
                        Text("Get notified when you're approaching your budget limit.")
                            .foregroundStyle(.tertiary)
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
                            devButton("Reset Privacy Consent") {
                                UserDefaults.standard.removeObject(forKey: "hasAcceptedPrivacy")
                            }
                            devButton("Reset Onboarding") {
                                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                            }
                            devButton("Delete All Transactions", destructive: true) {
                                // Placeholder
                            }

                            if let msg = devConfirmation {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(msg)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .listRowBackground(theme.card)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
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
                Task {
                    let center = UNUserNotificationCenter.current()
                    let settings = await center.notificationSettings()
                    alertsEnabled = settings.authorizationStatus == .authorized
                }
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

    private func devButton(_ label: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(label) {
            action()
            withAnimation(.spring(response: 0.3)) {
                devConfirmation = "\(label) — done"
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                withAnimation { devConfirmation = nil }
            }
        }
        .foregroundStyle(destructive ? .red : .orange)
        .listRowBackground(theme.card)
    }
}
