import SwiftUI

struct BudgeteerColors {
    static let green  = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let yellow = Color(red: 1.000, green: 0.624, blue: 0.039)
    static let red    = Color(red: 1.000, green: 0.231, blue: 0.188)

    // Richer, deeper green — used as the "used your full daily allowance" end-stop.
    // Still clearly green, not alarming.
    static let deepGreen = Color(red: 0.13, green: 0.55, blue: 0.23)

    // MARK: - Shared spending-color scale
    //
    // Used by CalendarHeatmapView cells, the mic button, and the recording overlay
    // so the colour always means the same thing everywhere in the app.
    //
    //   0 %          → vivid bright green   (nothing spent today — great)
    //   1 – 100 %    → bright → deep green  (within daily allowance — fine)
    //   100 – 150 %  → deep green → yellow  (over daily limit — take notice)
    //   150 % +      → yellow → red         (well over — alarm)

    static func spendingColor(spent: Double, dailyBudget: Double) -> Color {
        guard dailyBudget > 0 else { return green }
        let ratio = spent / dailyBudget

        if ratio < 0.01 {
            return green
        } else if ratio <= 1.0 {
            return blend(green, deepGreen, t: ratio)
        } else if ratio <= 1.5 {
            return blend(deepGreen, yellow, t: (ratio - 1.0) / 0.5)
        } else {
            return blend(yellow, red, t: min((ratio - 1.5) / 0.5, 1.0))
        }
    }

    // MARK: - Color blending

    static func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        let uiA = UIColor(a), uiB = UIColor(b)
        var rA: CGFloat = 0, gA: CGFloat = 0, bA: CGFloat = 0, xA: CGFloat = 0
        var rB: CGFloat = 0, gB: CGFloat = 0, bB: CGFloat = 0, xB: CGFloat = 0
        uiA.getRed(&rA, green: &gA, blue: &bA, alpha: &xA)
        uiB.getRed(&rB, green: &gB, blue: &bB, alpha: &xB)
        let ct = CGFloat(t)
        return Color(
            red:   Double(rA + (rB - rA) * ct),
            green: Double(gA + (gB - gA) * ct),
            blue:  Double(bA + (bB - bA) * ct)
        )
    }
}

enum BudgeteerThresholdColor {
    case green, yellow, red

    var color: Color {
        switch self {
        case .green:  return BudgeteerColors.green
        case .yellow: return BudgeteerColors.yellow
        case .red:    return BudgeteerColors.red
        }
    }
}
