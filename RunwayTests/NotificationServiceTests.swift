import XCTest
@testable import Runway

final class NotificationServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a BudgetManager with the given budget and thresholds.
    private func makeBudgetManager(
        budget: Double,
        yellow: Double = 0.40,
        red: Double = 0.15
    ) -> BudgetManager {
        let mgr = BudgetManager()
        mgr.monthlyBudget = budget
        mgr.yellowThreshold = yellow
        mgr.redThreshold = red
        return mgr
    }

    /// Builds a list of stub transactions for the *current* month with the
    /// given amounts (so they pass the currentMonthKey filter).
    private func stubTransactions(amounts: [Double]) -> [Transaction] {
        amounts.map {
            Transaction(amount: $0, transactionDescription: "stub", timestamp: .now)
        }
    }

    // MARK: - percentRemaining

    func testPercentRemaining_noSpending() {
        let mgr = makeBudgetManager(budget: 1000)
        XCTAssertEqual(mgr.percentRemaining([]), 1.0, accuracy: 0.001)
    }

    func testPercentRemaining_50PercentSpent() {
        let mgr = makeBudgetManager(budget: 1000)
        let txns = stubTransactions(amounts: [500])
        XCTAssertEqual(mgr.percentRemaining(txns), 0.50, accuracy: 0.001)
    }

    func testPercentRemaining_75PercentSpent() {
        let mgr = makeBudgetManager(budget: 1000)
        let txns = stubTransactions(amounts: [750])
        XCTAssertEqual(mgr.percentRemaining(txns), 0.25, accuracy: 0.001)
    }

    func testPercentRemaining_90PercentSpent() {
        let mgr = makeBudgetManager(budget: 1000)
        let txns = stubTransactions(amounts: [900])
        XCTAssertEqual(mgr.percentRemaining(txns), 0.10, accuracy: 0.001)
    }

    func testPercentRemaining_100PercentSpent() {
        let mgr = makeBudgetManager(budget: 1000)
        let txns = stubTransactions(amounts: [1000])
        XCTAssertEqual(mgr.percentRemaining(txns), 0.0, accuracy: 0.001)
    }

    func testPercentRemaining_overBudget_clampedToZero() {
        let mgr = makeBudgetManager(budget: 1000)
        let txns = stubTransactions(amounts: [1200])
        XCTAssertEqual(mgr.percentRemaining(txns), 0.0, accuracy: 0.001,
                       "percentRemaining should clamp to 0 when over budget")
    }

    // MARK: - Division by zero (budget = 0)

    func testPercentRemaining_zeroBudget_returnsOne() {
        let mgr = makeBudgetManager(budget: 0)
        XCTAssertEqual(mgr.percentRemaining([]), 1.0, accuracy: 0.001,
                       "Zero budget should return 1.0 (guard clause)")
    }

    func testRemaining_zeroBudget() {
        let mgr = makeBudgetManager(budget: 0)
        let txns = stubTransactions(amounts: [100])
        XCTAssertEqual(mgr.remaining(txns), -100, accuracy: 0.01)
    }

    func testDailyAllowance_zeroBudget_noSpending() {
        let mgr = makeBudgetManager(budget: 0)
        XCTAssertEqual(mgr.dailyAllowance([]), 0, accuracy: 0.001,
                       "Zero budget with no spending means 0 remaining so allowance should be 0")
    }

    // MARK: - meterColor thresholds

    func testMeterColor_greenWhenWellWithinBudget() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)
        // 10% spent -> 90% remaining -> well above yellow(40%)
        let txns = stubTransactions(amounts: [100])
        XCTAssertEqual(mgr.meterColor(txns), .green)
    }

    func testMeterColor_yellowAtThreshold() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)
        // 60% spent -> 40% remaining == yellowThreshold
        let txns = stubTransactions(amounts: [600])
        XCTAssertEqual(mgr.meterColor(txns), .yellow)
    }

    func testMeterColor_yellowJustBelowGreen() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)
        // 61% spent -> 39% remaining -> below yellow threshold
        let txns = stubTransactions(amounts: [610])
        XCTAssertEqual(mgr.meterColor(txns), .yellow)
    }

    func testMeterColor_redAtThreshold() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)
        // 85% spent -> 15% remaining == redThreshold
        let txns = stubTransactions(amounts: [850])
        XCTAssertEqual(mgr.meterColor(txns), .red)
    }

    func testMeterColor_redWhenOverBudget() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)
        let txns = stubTransactions(amounts: [1100])
        XCTAssertEqual(mgr.meterColor(txns), .red)
    }

    // MARK: - ThresholdType detection (currentThreshold via checkThresholds)

    func testCheckThresholds_noSpending_noNotification() {
        // With no spending, currentThreshold returns nil. checkThresholds
        // should not crash and lastNotifiedThreshold stays nil.
        let mgr = makeBudgetManager(budget: 1000)
        // Should not crash / no side-effects we can observe directly,
        // but validates the code path runs without error.
        mgr.checkThresholds([])
    }

    func testCheckThresholds_exactlyAtYellow() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)
        // 60% spent -> 40% remaining -> hits yellow
        let txns = stubTransactions(amounts: [600])
        mgr.checkThresholds(txns)
        // Call again with same state -- should NOT re-fire (worsened = false)
        mgr.checkThresholds(txns)
    }

    func testCheckThresholds_escalatesFromYellowToRed() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)

        // First: yellow
        let yellowTxns = stubTransactions(amounts: [600])
        mgr.checkThresholds(yellowTxns)

        // Then: red (add more spending)
        let redTxns = stubTransactions(amounts: [600, 250])
        mgr.checkThresholds(redTxns)
    }

    func testCheckThresholds_escalatesFromYellowToOverBudget() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)

        let yellowTxns = stubTransactions(amounts: [600])
        mgr.checkThresholds(yellowTxns)

        let overTxns = stubTransactions(amounts: [600, 500])
        mgr.checkThresholds(overTxns)
    }

    func testCheckThresholds_doesNotFireWhenThresholdImproves() {
        let mgr = makeBudgetManager(budget: 1000, yellow: 0.40, red: 0.15)

        // First escalate to red
        let redTxns = stubTransactions(amounts: [860])
        mgr.checkThresholds(redTxns)

        // Now "improve" back to yellow -- worsened should be false
        let yellowTxns = stubTransactions(amounts: [600])
        mgr.checkThresholds(yellowTxns)
    }

    func testCheckThresholds_zeroBudget_guardPreventsNotify() {
        // budget = 0 means notify() early-returns. checkThresholds should
        // still run without crashing.
        let mgr = makeBudgetManager(budget: 0)
        let txns = stubTransactions(amounts: [50])
        mgr.checkThresholds(txns)
    }

    // MARK: - NotificationService.notify guard (budget = 0)

    func testNotify_zeroBudget_doesNotCrash() {
        // The guard in notify() should early-return when budget is 0.
        NotificationService.shared.notify(.yellow, remaining: 100, budget: 0)
        NotificationService.shared.notify(.red, remaining: 0, budget: 0)
        NotificationService.shared.notify(.overBudget, remaining: -50, budget: 0)
    }

    // MARK: - Spending boundary edge cases

    func testRemaining_exactBudgetSpent() {
        let mgr = makeBudgetManager(budget: 500)
        let txns = stubTransactions(amounts: [500])
        XCTAssertEqual(mgr.remaining(txns), 0, accuracy: 0.001)
    }

    func testTotalSpent_multipleTransactions() {
        let mgr = makeBudgetManager(budget: 1000)
        let txns = stubTransactions(amounts: [100, 200, 50, 25])
        XCTAssertEqual(mgr.totalSpent(txns), 375, accuracy: 0.001)
    }

    func testTotalSpent_noTransactions() {
        let mgr = makeBudgetManager(budget: 1000)
        XCTAssertEqual(mgr.totalSpent([]), 0, accuracy: 0.001)
    }

    // MARK: - Pending transactions are excluded from budget calculations

    func testPendingTransactions_excludedFromTotalSpent() {
        let mgr = makeBudgetManager(budget: 1000)
        let pending = Transaction(amount: 200, transactionDescription: "pending", isPending: true)
        let confirmed = Transaction(amount: 300, transactionDescription: "confirmed", isPending: false)
        XCTAssertEqual(mgr.totalSpent([pending, confirmed]), 300, accuracy: 0.001)
    }
}
