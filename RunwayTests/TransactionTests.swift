import XCTest
@testable import Runway

final class TransactionTests: XCTestCase {

    // MARK: - Default initialisation

    func testDefaultInit_setsAllFields() {
        let txn = Transaction(amount: 42.50, transactionDescription: "Coffee")
        XCTAssertEqual(txn.amount, 42.50, accuracy: 0.001)
        XCTAssertEqual(txn.transactionDescription, "Coffee")
        XCTAssertEqual(txn.category, "Other", "Default category should be 'Other'")
        XCTAssertFalse(txn.isPending, "Default isPending should be false")
        XCTAssertEqual(txn.rawInput, "", "Default rawInput should be empty string")
        XCTAssertFalse(txn.id.uuidString.isEmpty, "UUID should be generated")
    }

    func testInit_customCategory() {
        let txn = Transaction(amount: 10, transactionDescription: "Lunch", category: "Food")
        XCTAssertEqual(txn.category, "Food")
    }

    func testInit_eachInstanceGetsUniqueID() {
        let a = Transaction(amount: 1, transactionDescription: "A")
        let b = Transaction(amount: 2, transactionDescription: "B")
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - Pending state

    func testPendingTrue() {
        let txn = Transaction(amount: 99, transactionDescription: "Hold", isPending: true)
        XCTAssertTrue(txn.isPending)
    }

    func testPendingDefaultFalse() {
        let txn = Transaction(amount: 10, transactionDescription: "Done")
        XCTAssertFalse(txn.isPending)
    }

    // MARK: - Timestamp & monthKey

    func testMonthKey_matchesTimestamp() {
        let components = DateComponents(year: 2025, month: 7, day: 15)
        let date = Calendar.current.date(from: components)!
        let txn = Transaction(amount: 5, transactionDescription: "Test", timestamp: date)
        XCTAssertEqual(txn.monthKey, "2025-07")
    }

    func testMonthKey_januaryEdge() {
        let components = DateComponents(year: 2026, month: 1, day: 1)
        let date = Calendar.current.date(from: components)!
        let txn = Transaction(amount: 5, transactionDescription: "New Year", timestamp: date)
        XCTAssertEqual(txn.monthKey, "2026-01")
    }

    func testMonthKey_decemberEdge() {
        let components = DateComponents(year: 2025, month: 12, day: 31)
        let date = Calendar.current.date(from: components)!
        let txn = Transaction(amount: 5, transactionDescription: "NYE", timestamp: date)
        XCTAssertEqual(txn.monthKey, "2025-12")
    }

    func testMakeMonthKey_staticHelper() {
        let components = DateComponents(year: 2024, month: 3, day: 10)
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(Transaction.makeMonthKey(from: date), "2024-03")
    }

    func testCurrentMonthKey_matchesNow() {
        let expected = Transaction.makeMonthKey(from: .now)
        XCTAssertEqual(Transaction.currentMonthKey, expected)
    }

    // MARK: - Category defaults

    func testDefaultCategory_isOther() {
        let txn = Transaction(amount: 1, transactionDescription: "x")
        XCTAssertEqual(txn.category, "Other")
    }

    func testExplicitCategory_overridesDefault() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "Food")
        XCTAssertEqual(txn.category, "Food")
    }

    // MARK: - categoryEmoji

    func testCategoryEmoji_food() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "Food")
        XCTAssertEqual(txn.categoryEmoji, "\u{1F37D}\u{FE0F}")  // plate emoji
    }

    func testCategoryEmoji_transport() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "Transport")
        XCTAssertEqual(txn.categoryEmoji, "\u{1F697}")  // car emoji
    }

    func testCategoryEmoji_entertainment() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "Entertainment")
        XCTAssertEqual(txn.categoryEmoji, "\u{1F3AC}")  // clapper board
    }

    func testCategoryEmoji_shopping() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "Shopping")
        XCTAssertEqual(txn.categoryEmoji, "\u{1F6CD}\u{FE0F}")  // shopping bags
    }

    func testCategoryEmoji_health() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "Health")
        XCTAssertEqual(txn.categoryEmoji, "\u{1F48A}")  // pill
    }

    func testCategoryEmoji_bills() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "Bills")
        XCTAssertEqual(txn.categoryEmoji, "\u{1F4C4}")  // document
    }

    func testCategoryEmoji_unknownFallsBackToDefault() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "RandomStuff")
        XCTAssertEqual(txn.categoryEmoji, "\u{1F4B3}")  // credit card
    }

    func testCategoryEmoji_otherCategory() {
        let txn = Transaction(amount: 1, transactionDescription: "x", category: "Other")
        XCTAssertEqual(txn.categoryEmoji, "\u{1F4B3}")  // credit card (default)
    }

    // MARK: - formattedAmount

    func testFormattedAmount_wholeDollar() {
        let txn = Transaction(amount: 50, transactionDescription: "x")
        XCTAssertEqual(txn.formattedAmount, "$50.00")
    }

    func testFormattedAmount_withCents() {
        let txn = Transaction(amount: 9.99, transactionDescription: "x")
        XCTAssertEqual(txn.formattedAmount, "$9.99")
    }

    func testFormattedAmount_zero() {
        let txn = Transaction(amount: 0, transactionDescription: "x")
        XCTAssertEqual(txn.formattedAmount, "$0.00")
    }

    func testFormattedAmount_largeAmount() {
        let txn = Transaction(amount: 12345.67, transactionDescription: "x")
        XCTAssertEqual(txn.formattedAmount, "$12345.67")
    }

    // MARK: - formattedDate

    func testFormattedDate_isNotEmpty() {
        let txn = Transaction(amount: 1, transactionDescription: "x")
        XCTAssertFalse(txn.formattedDate.isEmpty, "Formatted date should not be empty")
    }

    // MARK: - rawInput

    func testRawInput_default() {
        let txn = Transaction(amount: 1, transactionDescription: "x")
        XCTAssertEqual(txn.rawInput, "")
    }

    func testRawInput_custom() {
        let txn = Transaction(amount: 1, transactionDescription: "x", rawInput: "coffee 5 bucks")
        XCTAssertEqual(txn.rawInput, "coffee 5 bucks")
    }
}
