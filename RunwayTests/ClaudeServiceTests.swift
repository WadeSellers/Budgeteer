import XCTest
@testable import Runway

final class ClaudeServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Build a Claude API response envelope wrapping the given inner JSON text.
    private func makeAPIResponse(_ innerJSON: String) -> Data {
        let envelope: [String: Any] = [
            "id": "msg_test",
            "type": "message",
            "role": "assistant",
            "content": [
                ["type": "text", "text": innerJSON]
            ],
            "model": "claude-haiku-4-5-20251001",
            "stop_reason": "end_turn"
        ]
        return try! JSONSerialization.data(withJSONObject: envelope)
    }

    // MARK: - Normal response

    func testNormalResponse_StarbucksCoffee() throws {
        let json = """
        {"amount": 8, "description": "Starbucks", "category": "Food"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "$8 at Starbucks")
        XCTAssertEqual(result.amount, 8.0, accuracy: 0.001)
        XCTAssertEqual(result.description, "Starbucks")
        XCTAssertEqual(result.category, "Food")
    }

    func testNormalResponse_DecimalAmount() throws {
        let json = """
        {"amount": 25.62, "description": "Target Run", "category": "Shopping"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "target run 25 62")
        XCTAssertEqual(result.amount, 25.62, accuracy: 0.001)
        XCTAssertEqual(result.description, "Target Run")
        XCTAssertEqual(result.category, "Shopping")
    }

    func testNormalResponse_AmountAsString() throws {
        // Claude occasionally returns the amount as a string instead of a number
        let json = """
        {"amount": "12.50", "description": "Lunch", "category": "Food"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "lunch twelve fifty")
        XCTAssertEqual(result.amount, 12.50, accuracy: 0.001)
        XCTAssertEqual(result.description, "Lunch")
        XCTAssertEqual(result.category, "Food")
    }

    // MARK: - Missing fields

    func testMissingCategory_DefaultsToOther() throws {
        let json = """
        {"amount": 15, "description": "Haircut"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "haircut 15 dollars")
        XCTAssertEqual(result.amount, 15.0, accuracy: 0.001)
        XCTAssertEqual(result.description, "Haircut")
        XCTAssertEqual(result.category, "Other")
    }

    func testMissingDescription_FallsBackToInput() throws {
        let json = """
        {"amount": 5.99, "category": "Food"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "5 99 coffee")
        XCTAssertEqual(result.amount, 5.99, accuracy: 0.001)
        XCTAssertEqual(result.description, "5 99 coffee")
        XCTAssertEqual(result.category, "Food")
    }

    func testMissingBothDescriptionAndCategory() throws {
        let json = """
        {"amount": 20}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "twenty bucks")
        XCTAssertEqual(result.amount, 20.0, accuracy: 0.001)
        XCTAssertEqual(result.description, "twenty bucks")
        XCTAssertEqual(result.category, "Other")
    }

    // MARK: - Malformed JSON / garbage

    func testMalformedJSON_ThrowsParsingFailed() {
        let garbage = "this is not json at all"
        let data = makeAPIResponse(garbage)
        XCTAssertThrowsError(try ClaudeService.parseResponse(data, fallbackDescription: "test")) { error in
            guard case ClaudeError.parsingFailed = error else {
                XCTFail("Expected ClaudeError.parsingFailed, got \(error)")
                return
            }
        }
    }

    func testEmptyTextBlock_ThrowsParsingFailed() {
        let data = makeAPIResponse("")
        XCTAssertThrowsError(try ClaudeService.parseResponse(data, fallbackDescription: "test")) { error in
            guard case ClaudeError.parsingFailed = error else {
                XCTFail("Expected ClaudeError.parsingFailed, got \(error)")
                return
            }
        }
    }

    func testCompletelyEmptyData_ThrowsParsingFailed() {
        let data = Data()
        XCTAssertThrowsError(try ClaudeService.parseResponse(data, fallbackDescription: "test")) { error in
            guard case ClaudeError.parsingFailed = error else {
                XCTFail("Expected ClaudeError.parsingFailed, got \(error)")
                return
            }
        }
    }

    func testMissingContentArray_ThrowsParsingFailed() {
        // A valid JSON response but without the expected "content" array
        let envelope: [String: Any] = ["id": "msg_test", "type": "message"]
        let data = try! JSONSerialization.data(withJSONObject: envelope)
        XCTAssertThrowsError(try ClaudeService.parseResponse(data, fallbackDescription: "test")) { error in
            guard case ClaudeError.parsingFailed = error else {
                XCTFail("Expected ClaudeError.parsingFailed, got \(error)")
                return
            }
        }
    }

    func testNoTextBlock_ThrowsParsingFailed() {
        // Content array exists but no "text" type block
        let envelope: [String: Any] = [
            "content": [["type": "image", "source": "abc"]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: envelope)
        XCTAssertThrowsError(try ClaudeService.parseResponse(data, fallbackDescription: "test")) { error in
            guard case ClaudeError.parsingFailed = error else {
                XCTFail("Expected ClaudeError.parsingFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - Markdown code fences

    func testCodeFenceWrappedJSON() throws {
        let json = """
        ```json
        {"amount": 42.00, "description": "Movie Tickets", "category": "Entertainment"}
        ```
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "movie tickets")
        XCTAssertEqual(result.amount, 42.0, accuracy: 0.001)
        XCTAssertEqual(result.description, "Movie Tickets")
        XCTAssertEqual(result.category, "Entertainment")
    }

    func testPlainCodeFenceWrappedJSON() throws {
        let json = """
        ```
        {"amount": 9.99, "description": "Netflix", "category": "Bills"}
        ```
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "netflix")
        XCTAssertEqual(result.amount, 9.99, accuracy: 0.001)
        XCTAssertEqual(result.description, "Netflix")
        XCTAssertEqual(result.category, "Bills")
    }

    // MARK: - Edge case amounts

    func testZeroAmount_ThrowsParsingFailed() {
        let json = """
        {"amount": 0, "description": "Free Sample", "category": "Food"}
        """
        XCTAssertThrowsError(try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "free sample")) { error in
            guard case ClaudeError.parsingFailed = error else {
                XCTFail("Expected ClaudeError.parsingFailed, got \(error)")
                return
            }
        }
    }

    func testNegativeAmount_ThrowsParsingFailed() {
        let json = """
        {"amount": -5.00, "description": "Refund", "category": "Shopping"}
        """
        XCTAssertThrowsError(try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "refund")) { error in
            guard case ClaudeError.parsingFailed = error else {
                XCTFail("Expected ClaudeError.parsingFailed, got \(error)")
                return
            }
        }
    }

    func testVeryLargeAmount() throws {
        let json = """
        {"amount": 99999.99, "description": "Down Payment", "category": "Bills"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "down payment")
        XCTAssertEqual(result.amount, 99999.99, accuracy: 0.001)
    }

    func testSmallCentsAmount() throws {
        let json = """
        {"amount": 0.75, "description": "Gumball", "category": "Food"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "gumball")
        XCTAssertEqual(result.amount, 0.75, accuracy: 0.001)
        XCTAssertEqual(result.description, "Gumball")
    }

    func testAmountAsIntegerInJSON() throws {
        // JSON integer (no decimal point) should still parse as Double
        let json = """
        {"amount": 100, "description": "Groceries", "category": "Food"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "groceries")
        XCTAssertEqual(result.amount, 100.0, accuracy: 0.001)
    }

    func testAmountMissing_ThrowsParsingFailed() {
        let json = """
        {"description": "Mystery", "category": "Other"}
        """
        XCTAssertThrowsError(try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "mystery")) { error in
            guard case ClaudeError.parsingFailed = error else {
                XCTFail("Expected ClaudeError.parsingFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - Empty transcript guard

    func testEmptyTranscript_ThrowsParsingFailed() async {
        do {
            _ = try await ClaudeService.shared.parseTransaction("")
            XCTFail("Expected error for empty input")
        } catch let error as ClaudeError {
            guard case .parsingFailed(let msg) = error else {
                XCTFail("Expected parsingFailed, got \(error)")
                return
            }
            XCTAssertEqual(msg, "Empty input")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testWhitespaceOnlyTranscript_ThrowsParsingFailed() async {
        do {
            _ = try await ClaudeService.shared.parseTransaction("   \n  \t  ")
            XCTFail("Expected error for whitespace-only input")
        } catch let error as ClaudeError {
            guard case .parsingFailed(let msg) = error else {
                XCTFail("Expected parsingFailed, got \(error)")
                return
            }
            XCTAssertEqual(msg, "Empty input")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Special characters in description

    func testDescriptionWithQuotes() throws {
        let json = """
        {"amount": 15.00, "description": "Ben & Jerry's Ice Cream", "category": "Food"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "ice cream")
        XCTAssertEqual(result.description, "Ben & Jerry's Ice Cream")
    }

    func testDescriptionWithUnicode() throws {
        let json = """
        {"amount": 22.50, "description": "Caf\\u00e9 Latte", "category": "Food"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "cafe latte")
        XCTAssertEqual(result.amount, 22.50, accuracy: 0.001)
        XCTAssertTrue(result.description.contains("Caf"))
    }

    func testDescriptionWithEmoji() throws {
        // Claude might include emoji in the description
        let innerJSON = #"{"amount": 8.50, "description": "Coffee \u2615", "category": "Food"}"#
        let result = try ClaudeService.parseResponse(makeAPIResponse(innerJSON), fallbackDescription: "coffee")
        XCTAssertEqual(result.amount, 8.50, accuracy: 0.001)
        // Description should parse without crashing regardless of emoji content
        XCTAssertFalse(result.description.isEmpty)
    }

    func testDescriptionWithSpecialCharacters() throws {
        let json = """
        {"amount": 30, "description": "AT&T Bill - April", "category": "Bills"}
        """
        let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "att bill")
        XCTAssertEqual(result.description, "AT&T Bill - April")
        XCTAssertEqual(result.category, "Bills")
    }

    // MARK: - All valid categories

    func testAllValidCategories() throws {
        let categories = ["Food", "Transport", "Entertainment", "Shopping", "Health", "Bills", "Other"]
        for category in categories {
            let json = """
            {"amount": 10, "description": "Test", "category": "\(category)"}
            """
            let result = try ClaudeService.parseResponse(makeAPIResponse(json), fallbackDescription: "test")
            XCTAssertEqual(result.category, category, "Category '\(category)' should be preserved exactly")
        }
    }
}
