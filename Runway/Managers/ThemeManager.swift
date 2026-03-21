import SwiftUI
import Observation

enum AppearanceMode: String, CaseIterable {
    case system, light, dark, dim

    var label: String {
        switch self {
        case .system: return "Auto"
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .dim:    return "Dim"
        }
    }
}

@Observable
final class ThemeManager {

    // MARK: - Stored preference

    var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
    }

    /// Updated by the root SystemSchemeCapture view before .preferredColorScheme is applied,
    /// so it always reflects the real iOS system preference (not our override).
    var systemColorScheme: ColorScheme = .dark

    // MARK: - Init

    init() {
        let raw = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        appearanceMode = AppearanceMode(rawValue: raw) ?? .system
    }

    // MARK: - Resolved state

    var isLight: Bool {
        switch appearanceMode {
        case .light:  return true
        case .dark, .dim: return false
        case .system: return systemColorScheme == .light
        }
    }

    var isDim: Bool {
        switch appearanceMode {
        case .dim:    return true
        case .dark, .light: return false
        case .system: return false
        }
    }

    /// Used by SystemSchemeCapture to set the preferred color scheme.
    /// nil = follow system, .light/.dark = explicit override.
    var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        case .dim:    return .dark
        }
    }

    // MARK: - Semantic color tokens

    /// Main screen / sheet background.
    var appBackground: Color {
        if isLight { return Color(red: 0.95, green: 0.95, blue: 0.97) }
        return isDim ? Color(red: 0.11, green: 0.11, blue: 0.118) : .black
    }

    /// Subtle card / list row background (lowest elevation).
    var card: Color {
        if isLight { return .white }
        return .white.opacity(isDim ? 0.09 : 0.06)
    }

    /// Input field / transcript bubble background (mid elevation).
    var surface: Color {
        if isLight { return Color(red: 0.92, green: 0.92, blue: 0.94) }
        return .white.opacity(isDim ? 0.12 : 0.08)
    }

    /// Icon button circle / "Today" pill background (highest elevation).
    var surfaceMid: Color {
        if isLight { return Color(red: 0.88, green: 0.88, blue: 0.90) }
        return .white.opacity(isDim ? 0.16 : 0.12)
    }

    /// Subtle overlay for emoji circles, meter tracks, etc.
    var subtleOverlay: Color {
        isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.08)
    }
}
