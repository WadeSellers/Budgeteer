import XCTest
@testable import Runway

final class BudgetManagerTests: XCTestCase {

    private var sut: BudgetManager!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // Clear UserDefaults keys so each test starts fresh
        UserDefaults.standard.removeObject(forKey: "monthlyBudget")
        UserDefaults.standard.removeObject(forKey: "yellowThreshold")
        UserDefaults.standard.removeObject(forKey: "redThreshold")
        sut = BudgetManager()
    }

    override func tearDown() {
        sut = nil
        UserDefaults.standard.removeObject(forKey: "monthlyBudget")
        UserDefaults.standard.removeObject(forKey: "yellowThreshold")
        UserDefaults.standard.removeObject(forKey: "redThreshold")
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a Transaction dated in the current month (so it passes the currentMonthKey filter).
    private func makeTransaction(
        amount: Double,
        daysAgo: Int = 0,
        isPending: Bool = false
    ) -> Transaction {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Transaction(
            amount: amount,
            transactionDescription: "Test",
            category: "Other",
            timestamp: date,
            isPending: isPending
        )
    }

    /// Creates a Transaction for a specific date.
    private func makeTransaction(
        amount: Double,
        on date: Date,
        isPending: Bool = false
    ) -> Transaction {
        return Transaction(
            amount: amount,
            transactionDescription: "Test",
            category: "Other",
            timestamp: date,
            isPending: isPending
        )
    }

    /// Returns a date in a previous month so the transaction will NOT be in currentMonthKey.
    private var lastMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    }

    // MARK: - Default init values

    func testDefaultThresholds() {
        XCTAssertEqual(sut.monthlyBudget, 0)
        XCTAssertEqual(sut.yellowThreshold, 0.40,
                       "Yellow threshold should default to 0.40 when UserDefaults is empty")
        XCTAssertEqual(sut.redThreshold, 0.15,
                       "Red threshold should default to 0.15 when UserDefaults is empty")
    }

    func testInitReadsUserDefaults() {
        UserDefaults.standard.set(3000.0, forKey: "monthlyBudget")
        UserDefaults.standard.set(0.50, forKey: "yellowThreshold")
        UserDefaults.standard.set(0.20, forKey: "redThreshold")

        let manager = BudgetManager()
        XCTAssertEqual(manager.monthlyBudget, 3000.0)
        XCTAssertEqual(manager.yellowThreshold, 0.50)
        XCTAssertEqual(manager.redThreshold, 0.20)
    }

    // MARK: - Total spent

    func testTotalSpentNoTransactions() {
        sut.monthlyBudget = 1000
        XCTAssertEqual(sut.totalSpent([]), 0)
    }

    func testTotalSpentSumsCurrentMonth() {
        sut.monthlyBudget = 1000
        let txns = [makeTransaction(amount: 50), makeTransaction(amount: 75)]
        XCTAssertEqual(sut.totalSpent(txns), 125, accuracy: 0.001)
    }

    func testTotalSpentIgnoresLastMonth() {
        sut.monthlyBudget = 1000
        let current = makeTransaction(amount: 100)
        let old = makeTransaction(amount: 200, on: lastMonthDate)
        XCTAssertEqual(sut.totalSpent([current, old]), 100, accuracy: 0.001)
    }

    func testTotalSpentIgnoresPendingTransactions() {
        sut.monthlyBudget = 1000
        let confirmed = makeTransaction(amount: 40)
        let pending = makeTransaction(amount: 60, isPending: true)
        XCTAssertEqual(sut.totalSpent([confirmed, pending]), 40, accuracy: 0.001)
    }

    // MARK: - Remaining budget

    func testRemainingNoTransactions() {
        sut.monthlyBudget = 2000
        XCTAssertEqual(sut.remaining([]), 2000, accuracy: 0.001)
    }

    func testRemainingAfterSomeSpending() {
        sut.monthlyBudget = 2000
        let txns = [makeTransaction(amount: 300), makeTransaction(amount: 200)]
        XCTAssertEqual(sut.remaining(txns), 1500, accuracy: 0.001)
    }

    func testRemainingExactlyAtBudget() {
        sut.monthlyBudget = 500
        let txns = [makeTransaction(amount: 500)]
        XCTAssertEqual(sut.remaining(txns), 0, accuracy: 0.001)
    }

    func testRemainingOverBudget() {
        sut.monthlyBudget = 500
        let txns = [makeTransaction(amount: 700)]
        XCTAssertEqual(sut.remaining(txns), -200, accuracy: 0.001,
                       "Remaining should be negative when over budget")
    }

    // MARK: - Percent remaining

    func testPercentRemainingFullBudget() {
        sut.monthlyBudget = 1000
        XCTAssertEqual(sut.percentRemaining([]), 1.0, accuracy: 0.001)
    }

    func testPercentRemainingHalfSpent() {
        sut.monthlyBudget = 1000
        let txns = [makeTransaction(amount: 500)]
        XCTAssertEqual(sut.percentRemaining(txns), 0.5, accuracy: 0.001)
    }

    func testPercentRemainingOverBudgetClampsToZero() {
        sut.monthlyBudget = 100
        let txns = [makeTransaction(amount: 200)]
        XCTAssertEqual(sut.percentRemaining(txns), 0,
                       "Should be clamped to 0 when over budget")
    }

    func testPercentRemainingZeroBudgetReturnsOne() {
        sut.monthlyBudget = 0
        XCTAssertEqual(sut.percentRemaining([]), 1.0,
                       "Zero budget guard should return 1.0")
    }

    // MARK: - Monthly budget = 0 (division-by-zero protection)

    func testDailyAllowanceZeroBudget() {
        sut.monthlyBudget = 0
        // remaining is 0, so guard rem > 0 returns 0
        XCTAssertEqual(sut.dailyAllowance([]), 0)
    }

    func testMeterColorZeroBudget() {
        sut.monthlyBudget = 0
        // remaining is 0, which is NOT < 0, so the first guard doesn't fire.
        // percentRemaining returns 1.0 for zero budget.
        XCTAssertEqual(sut.meterColor([]), .green)
    }

    // MARK: - Daily allowance

    func testDailyAllowanceNormalCase() {
        sut.monthlyBudget = 3000
        let daysLeft = sut.daysRemainingInMonth()
        let expected = 3000.0 / Double(daysLeft)
        XCTAssertEqual(sut.dailyAllowance([]), expected, accuracy: 0.01)
    }

    func testDailyAllowanceAfterSpending() {
        sut.monthlyBudget = 3000
        let txns = [makeTransaction(amount: 1000)]
        let daysLeft = sut.daysRemainingInMonth()
        let expected = 2000.0 / Double(daysLeft)
        XCTAssertEqual(sut.dailyAllowance(txns), expected, accuracy: 0.01)
    }

    func testDailyAllowanceOverBudgetReturnsZero() {
        sut.monthlyBudget = 500
        let txns = [makeTransaction(amount: 600)]
        XCTAssertEqual(sut.dailyAllowance(txns), 0,
                       "Should return 0 when remaining is negative")
    }

    func testDailyAllowanceExactlyAtBudgetReturnsZero() {
        sut.monthlyBudget = 500
        let txns = [makeTransaction(amount: 500)]
        XCTAssertEqual(sut.dailyAllowance(txns), 0,
                       "Should return 0 when remaining is exactly 0")
    }

    // MARK: - Days remaining in month

    func testDaysRemainingReturnsAtLeastOne() {
        let days = sut.daysRemainingInMonth()
        XCTAssertGreaterThanOrEqual(days, 1,
            "daysRemainingInMonth should always be at least 1")
    }

    func testDaysRemainingDoesNotExceedMonthLength() {
        let days = sut.daysRemainingInMonth()
        XCTAssertLessThanOrEqual(days, 31,
            "daysRemainingInMonth should never exceed 31")
    }

    // MARK: - Meter color

    func testMeterColorGreenWhenWellUnderBudget() {
        sut.monthlyBudget = 1000
        // No spending -- 100% remaining, well above yellow threshold (40%)
        XCTAssertEqual(sut.meterColor([]), .green)
    }

    func testMeterColorYellowApproachingLimit() {
        sut.monthlyBudget = 1000
        // Spend 700 -> 30% remaining, which is <= 40% (yellow) but > 15% (red)
        let txns = [makeTransaction(amount: 700)]
        XCTAssertEqual(sut.meterColor(txns), .yellow)
    }

    func testMeterColorRedWhenLow() {
        sut.monthlyBudget = 1000
        // Spend 900 -> 10% remaining, which is <= 15% (red)
        let txns = [makeTransaction(amount: 900)]
        XCTAssertEqual(sut.meterColor(txns), .red)
    }

    func testMeterColorRedWhenOverBudget() {
        sut.monthlyBudget = 1000
        let txns = [makeTransaction(amount: 1100)]
        XCTAssertEqual(sut.meterColor(txns), .red)
    }

    func testMeterColorExactlyAtYellowBoundary() {
        sut.monthlyBudget = 1000
        // Spend 600 -> 40% remaining, exactly at yellowThreshold (0.40)
        // pct <= yellowThreshold => yellow
        let txns = [makeTransaction(amount: 600)]
        XCTAssertEqual(sut.meterColor(txns), .yellow)
    }

    func testMeterColorExactlyAtRedBoundary() {
        sut.monthlyBudget = 1000
        // Spend 850 -> 15% remaining, exactly at redThreshold (0.15)
        // pct <= redThreshold => red
        let txns = [makeTransaction(amount: 850)]
        XCTAssertEqual(sut.meterColor(txns), .red)
    }

    func testMeterColorJustAboveYellow() {
        sut.monthlyBudget = 1000
        // Spend 590 -> 41% remaining, just above yellow (0.40)
        let txns = [makeTransaction(amount: 590)]
        XCTAssertEqual(sut.meterColor(txns), .green)
    }

    // MARK: - Meter color with custom thresholds

    func testMeterColorCustomThresholds() {
        sut.monthlyBudget = 1000
        sut.yellowThreshold = 0.50
        sut.redThreshold = 0.25

        // Spend 600 -> 40% remaining, which is <= 50% (yellow) but > 25% (red)
        let txns = [makeTransaction(amount: 600)]
        XCTAssertEqual(sut.meterColor(txns), .yellow)
    }

    // MARK: - Total spent for a specific date

    func testTotalSpentForSpecificDate() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let t1 = makeTransaction(amount: 20, on: today)
        let t2 = makeTransaction(amount: 30, on: today)
        let t3 = makeTransaction(amount: 50, on: yesterday)

        let totalToday = sut.totalSpent(for: today, in: [t1, t2, t3])
        XCTAssertEqual(totalToday, 50, accuracy: 0.001)

        let totalYesterday = sut.totalSpent(for: yesterday, in: [t1, t2, t3])
        XCTAssertEqual(totalYesterday, 50, accuracy: 0.001)
    }

    func testTotalSpentForEmptyDay() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let t1 = makeTransaction(amount: 100, on: yesterday)

        XCTAssertEqual(sut.totalSpent(for: today, in: [t1]), 0)
    }

    func testTotalSpentForDateExcludesPending() {
        let today = Date()
        let confirmed = makeTransaction(amount: 25, on: today)
        let pending = makeTransaction(amount: 75, on: today, isPending: true)

        XCTAssertEqual(sut.totalSpent(for: today, in: [confirmed, pending]), 25, accuracy: 0.001)
    }

    // MARK: - Today helpers

    func testTodayTransactionsFiltersCorrectly() {
        let todayTxn = makeTransaction(amount: 10, daysAgo: 0)
        let yesterdayTxn = makeTransaction(amount: 20, daysAgo: 1)
        let pendingTxn = makeTransaction(amount: 5, daysAgo: 0, isPending: true)

        let result = sut.todayTransactions([todayTxn, yesterdayTxn, pendingTxn])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.amount, 10)
    }

    func testTotalSpentTodayIgnoresPending() {
        let txn = makeTransaction(amount: 42, daysAgo: 0)
        let pending = makeTransaction(amount: 100, daysAgo: 0, isPending: true)
        XCTAssertEqual(sut.totalSpentToday([txn, pending]), 42, accuracy: 0.001)
    }

    func testTodayTransactionCount() {
        let t1 = makeTransaction(amount: 10, daysAgo: 0)
        let t2 = makeTransaction(amount: 20, daysAgo: 0)
        let t3 = makeTransaction(amount: 30, daysAgo: 1)
        XCTAssertEqual(sut.todayTransactionCount([t1, t2, t3]), 2)
    }

    // MARK: - Current month transaction helpers

    func testCurrentMonthTransactionsFilter() {
        let current = makeTransaction(amount: 100)
        let old = makeTransaction(amount: 200, on: lastMonthDate)
        let pending = makeTransaction(amount: 50, isPending: true)

        let result = sut.currentMonthTransactions([current, old, pending])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.amount, 100)
    }

    func testSortedCurrentMonthOrdersMostRecentFirst() {
        let earlier = makeTransaction(amount: 10, daysAgo: 2)
        let later = makeTransaction(amount: 20, daysAgo: 0)

        let sorted = sut.sortedCurrentMonth([earlier, later])
        XCTAssertEqual(sorted.first?.amount, 20,
                       "Most recent transaction should come first")
    }

    // MARK: - Transactions by monthKey

    func testTransactionsForMonthKey() {
        let current = makeTransaction(amount: 100)
        let old = makeTransaction(amount: 200, on: lastMonthDate)

        let lastKey = Transaction.makeMonthKey(from: lastMonthDate)
        let result = sut.transactions(for: lastKey, in: [current, old])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.amount, 200)
    }

    func testTotalSpentForMonthKey() {
        let t1 = makeTransaction(amount: 100, on: lastMonthDate)
        let t2 = makeTransaction(amount: 50, on: lastMonthDate)

        let key = Transaction.makeMonthKey(from: lastMonthDate)
        XCTAssertEqual(sut.totalSpent(for: key, in: [t1, t2]), 150, accuracy: 0.001)
    }

    func testAvailableMonthsExcludesCurrent() {
        let current = makeTransaction(amount: 100)
        let old = makeTransaction(amount: 200, on: lastMonthDate)

        let months = sut.availableMonths([current, old])
        XCTAssertFalse(months.contains(Transaction.currentMonthKey))
        XCTAssertTrue(months.contains(Transaction.makeMonthKey(from: lastMonthDate)))
    }

    // MARK: - Display month

    func testDisplayMonthFormatsCorrectly() {
        let result = sut.displayMonth("2026-01")
        XCTAssertEqual(result, "January 2026")
    }

    func testDisplayMonthInvalidKeyReturnsRaw() {
        let result = sut.displayMonth("not-a-date")
        XCTAssertEqual(result, "not-a-date")
    }

    // MARK: - Threshold checking (currentThreshold via meterColor + checkThresholds)

    func testCurrentThresholdNilWhenHealthy() {
        sut.monthlyBudget = 1000
        // No spending -> 100% remaining -> no threshold crossed
        XCTAssertEqual(sut.meterColor([]), .green)
    }

    func testThresholdProgressionYellowThenRed() {
        sut.monthlyBudget = 1000

        // 30% remaining -> yellow zone
        let yellowTxns = [makeTransaction(amount: 700)]
        XCTAssertEqual(sut.meterColor(yellowTxns), .yellow)

        // 10% remaining -> red zone
        let redTxns = [makeTransaction(amount: 900)]
        XCTAssertEqual(sut.meterColor(redTxns), .red)
    }

    func testThresholdAt50Percent() {
        sut.monthlyBudget = 1000
        sut.yellowThreshold = 0.50
        let txns = [makeTransaction(amount: 500)]
        // 50% remaining, exactly at yellow threshold -> yellow
        XCTAssertEqual(sut.meterColor(txns), .yellow)
    }

    func testThresholdAt75Percent() {
        sut.monthlyBudget = 1000
        sut.yellowThreshold = 0.75
        sut.redThreshold = 0.50
        // Spend 400 -> 60% remaining, <= 75% yellow
        let txns = [makeTransaction(amount: 400)]
        XCTAssertEqual(sut.meterColor(txns), .yellow)
    }

    func testThresholdAt90Percent() {
        sut.monthlyBudget = 1000
        sut.yellowThreshold = 0.90
        sut.redThreshold = 0.50
        // Spend 200 -> 80% remaining, <= 90% yellow
        let txns = [makeTransaction(amount: 200)]
        XCTAssertEqual(sut.meterColor(txns), .yellow)
    }

    func testThresholdAt100PercentOverBudget() {
        sut.monthlyBudget = 1000
        let txns = [makeTransaction(amount: 1000)]
        // remaining = 0, percentRemaining = 0, pct <= redThreshold -> red
        XCTAssertEqual(sut.meterColor(txns), .red)
    }

    // MARK: - UserDefaults persistence

    func testSettingMonthlyBudgetPersists() {
        sut.monthlyBudget = 4500
        XCTAssertEqual(UserDefaults.standard.double(forKey: "monthlyBudget"), 4500)
    }

    func testSettingThresholdsPersists() {
        sut.yellowThreshold = 0.55
        sut.redThreshold = 0.20
        XCTAssertEqual(UserDefaults.standard.double(forKey: "yellowThreshold"), 0.55)
        XCTAssertEqual(UserDefaults.standard.double(forKey: "redThreshold"), 0.20)
    }
}
