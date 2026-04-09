import SwiftUI

enum HintType: String, CaseIterable {
    case budget           = "hintBudgetSeen"
    case totalSpend       = "hintTotalSpendSeen"
    case keyboard         = "hintKeyboardSeen"
    case monthlyRemaining = "hintMonthlyRemainingSeen"
}

@Observable
final class HintManager {

    // MARK: - Stored properties (tracked by @Observable)

    var hintBudgetSeen: Bool
    var hintTotalSpendSeen: Bool
    var hintKeyboardSeen: Bool
    var hintMonthlyRemainingSeen: Bool
    var purchaseCount: Int
    var appOpenCount: Int

    private var defaults: UserDefaults { .standard }

    init() {
        let d = UserDefaults.standard
        hintBudgetSeen           = d.bool(forKey: HintType.budget.rawValue)
        hintTotalSpendSeen       = d.bool(forKey: HintType.totalSpend.rawValue)
        hintKeyboardSeen         = d.bool(forKey: HintType.keyboard.rawValue)
        hintMonthlyRemainingSeen = d.bool(forKey: HintType.monthlyRemaining.rawValue)
        purchaseCount            = d.integer(forKey: "hintPurchaseCount")
        appOpenCount             = d.integer(forKey: "hintAppOpenCount")
    }

    // MARK: - Public API

    func trackAppOpen() {
        appOpenCount += 1
        defaults.set(appOpenCount, forKey: "hintAppOpenCount")
    }

    func trackPurchase() {
        purchaseCount += 1
        defaults.set(purchaseCount, forKey: "hintPurchaseCount")
    }

    func markSeen(_ hint: HintType) {
        switch hint {
        case .budget:           hintBudgetSeen = true
        case .totalSpend:       hintTotalSpendSeen = true
        case .keyboard:         hintKeyboardSeen = true
        case .monthlyRemaining: hintMonthlyRemainingSeen = true
        }
        defaults.set(true, forKey: hint.rawValue)
    }

    func resetAllHints() {
        for hint in HintType.allCases {
            defaults.removeObject(forKey: hint.rawValue)
        }
        hintBudgetSeen = false
        hintTotalSpendSeen = false
        hintKeyboardSeen = false
        hintMonthlyRemainingSeen = false
        purchaseCount = 0
        appOpenCount = 0
        defaults.removeObject(forKey: "hintPurchaseCount")
        defaults.removeObject(forKey: "hintAppOpenCount")
    }

    func shouldShow(_ hint: HintType) -> Bool {
        switch hint {
        case .budget:
            return !hintBudgetSeen && appOpenCount >= 2

        case .totalSpend:
            return !hintTotalSpendSeen && purchaseCount >= 1

        case .keyboard:
            return !hintKeyboardSeen && purchaseCount >= 1

        case .monthlyRemaining:
            return !hintMonthlyRemainingSeen && purchaseCount >= 1
        }
    }
}
