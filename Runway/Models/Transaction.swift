import SwiftData
import Foundation

@Model
final class Transaction {
    var id: UUID
    var amount: Double
    var transactionDescription: String
    var category: String
    var timestamp: Date
    var monthKey: String
    var isPending: Bool
    var rawInput: String

    init(
        amount: Double,
        transactionDescription: String,
        category: String = "Other",
        timestamp: Date = .now,
        isPending: Bool = false,
        rawInput: String = ""
    ) {
        self.id = UUID()
        self.amount = amount
        self.transactionDescription = transactionDescription
        self.category = category
        self.timestamp = timestamp
        self.isPending = isPending
        self.rawInput = rawInput
        self.monthKey = Self.makeMonthKey(from: timestamp)
    }

    static func makeMonthKey(from date: Date = .now) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }

    static var currentMonthKey: String { makeMonthKey() }

    var categoryEmoji: String {
        switch category {
        case "Food":          return "🍽️"
        case "Transport":     return "🚗"
        case "Entertainment": return "🎬"
        case "Shopping":      return "🛍️"
        case "Health":        return "💊"
        case "Bills":         return "📄"
        default:              return "💳"
        }
    }

    var formattedAmount: String { String(format: "$%.2f", amount) }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: timestamp)
    }
}
