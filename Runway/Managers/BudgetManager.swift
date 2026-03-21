import Foundation
import SwiftUI
import Observation

@Observable
final class BudgetManager {

    // MARK: - Persisted settings (stored props + didSet for UserDefaults sync)

    var monthlyBudget: Double {
        didSet { UserDefaults.standard.set(monthlyBudget, forKey: "monthlyBudget") }
    }

    var yellowThreshold: Double {
        didSet { UserDefaults.standard.set(yellowThreshold, forKey: "yellowThreshold") }
    }

    var redThreshold: Double {
        didSet { UserDefaults.standard.set(redThreshold, forKey: "redThreshold") }
    }

    // MARK: - Threshold notification state

    private var lastNotifiedThreshold: ThresholdType?

    // MARK: - Init

    init() {
        monthlyBudget   = UserDefaults.standard.double(forKey: "monthlyBudget")

        let y = UserDefaults.standard.double(forKey: "yellowThreshold")
        yellowThreshold = y == 0 ? 0.40 : y

        let r = UserDefaults.standard.double(forKey: "redThreshold")
        redThreshold    = r == 0 ? 0.15 : r
    }

    // MARK: - Computed values

    func totalSpent(_ transactions: [Transaction]) -> Double {
        currentMonthTransactions(transactions).reduce(0) { $0 + $1.amount }
    }

    func remaining(_ transactions: [Transaction]) -> Double {
        monthlyBudget - totalSpent(transactions)
    }

    func percentRemaining(_ transactions: [Transaction]) -> Double {
        guard monthlyBudget > 0 else { return 1.0 }
        return max(0, min(1, remaining(transactions) / monthlyBudget))
    }

    func dailyAllowance(_ transactions: [Transaction]) -> Double {
        let rem = remaining(transactions)
        guard rem > 0 else { return 0 }
        return rem / Double(daysRemainingInMonth())
    }

    func daysRemainingInMonth() -> Int {
        let cal = Calendar.current
        let now = Date()
        guard let range = cal.range(of: .day, in: .month, for: now) else { return 1 }
        let today = cal.component(.day, from: now)
        return max(1, range.count - today + 1)
    }

    func meterColor(_ transactions: [Transaction]) -> BudgeteerThresholdColor {
        if remaining(transactions) < 0           { return .red }
        let pct = percentRemaining(transactions)
        if pct <= redThreshold                   { return .red }
        if pct <= yellowThreshold                { return .yellow }
        return .green
    }

    // MARK: - Threshold notifications

    func checkThresholds(_ transactions: [Transaction]) {
        let current = currentThreshold(transactions)

        let worsened: Bool
        switch (lastNotifiedThreshold, current) {
        case (nil, .some):
            worsened = true
        case (.yellow, .red), (.yellow, .overBudget), (.red, .overBudget):
            worsened = true
        default:
            worsened = false
        }

        if worsened, let type = current {
            NotificationService.shared.notify(
                type,
                remaining: remaining(transactions),
                budget: monthlyBudget
            )
        }
        lastNotifiedThreshold = current
    }

    private func currentThreshold(_ transactions: [Transaction]) -> ThresholdType? {
        if remaining(transactions) < 0          { return .overBudget }
        let pct = percentRemaining(transactions)
        if pct <= redThreshold                  { return .red }
        if pct <= yellowThreshold               { return .yellow }
        return nil
    }

    // MARK: - Today helpers

    func todayTransactions(_ transactions: [Transaction]) -> [Transaction] {
        let cal = Calendar.current
        return transactions.filter { cal.isDateInToday($0.timestamp) && !$0.isPending }
    }

    func totalSpentToday(_ transactions: [Transaction]) -> Double {
        todayTransactions(transactions).reduce(0) { $0 + $1.amount }
    }

    func todayTransactionCount(_ transactions: [Transaction]) -> Int {
        todayTransactions(transactions).count
    }

    func transactions(for date: Date, in all: [Transaction]) -> [Transaction] {
        let cal = Calendar.current
        return all.filter { cal.isDate($0.timestamp, inSameDayAs: date) && !$0.isPending }
    }

    func totalSpent(for date: Date, in all: [Transaction]) -> Double {
        transactions(for: date, in: all).reduce(0) { $0 + $1.amount }
    }

    // MARK: - Transaction helpers

    func currentMonthTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { $0.monthKey == Transaction.currentMonthKey && !$0.isPending }
    }

    func sortedCurrentMonth(_ transactions: [Transaction]) -> [Transaction] {
        currentMonthTransactions(transactions).sorted { $0.timestamp > $1.timestamp }
    }

    func availableMonths(_ transactions: [Transaction]) -> [String] {
        Array(Set(transactions.map { $0.monthKey }))
            .sorted()
            .reversed()
            .filter { $0 != Transaction.currentMonthKey }
    }

    func transactions(for monthKey: String, in all: [Transaction]) -> [Transaction] {
        all.filter { $0.monthKey == monthKey && !$0.isPending }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func totalSpent(for monthKey: String, in all: [Transaction]) -> Double {
        all.filter { $0.monthKey == monthKey && !$0.isPending }
            .reduce(0) { $0 + $1.amount }
    }

    func displayMonth(_ monthKey: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: monthKey) else { return monthKey }
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
