import SwiftUI
import SwiftData
import UIKit

@main
struct BudgeteerApp: App {
    let modelContainer: ModelContainer

    init() {
        // Print device ID for Town Hall admin setup — remove after configuring
        print("[Budgeteer] Device ID: \(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")")

        // Keep SwiftData local-only — CloudKit is used manually by TownHallService,
        // not through SwiftData's built-in sync.
        let config = ModelConfiguration(cloudKitDatabase: .none)
        modelContainer = try! ModelContainer(for: Transaction.self, configurations: config)
    }

    @State private var budgetManager  = BudgetManager()
    @State private var networkMonitor = NetworkMonitor()
    @State private var themeManager   = ThemeManager()
    @State private var hintManager    = HintManager()

    var body: some Scene {
        WindowGroup {
            SystemSchemeCapture()
                .modelContainer(modelContainer)
                .environment(budgetManager)
                .environment(networkMonitor)
                .environment(themeManager)
                .environment(hintManager)
        }
    }
}

/// Reads the real iOS system color scheme BEFORE `.preferredColorScheme` is applied,
/// stores it in ThemeManager, then overrides the scheme based on the user's appearance
/// preference (light, dark, dim, or system passthrough).
private struct SystemSchemeCapture: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ContentView()
            .preferredColorScheme(themeManager.resolvedColorScheme)
            .onChange(of: colorScheme, initial: true) { _, scheme in
                themeManager.systemColorScheme = scheme
            }
    }
}
