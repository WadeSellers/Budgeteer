import Foundation

struct ParsedTransaction {
    let amount: Double
    let description: String
    let category: String
}

enum ClaudeError: LocalizedError {
    case networkUnavailable
    case timeout
    case parsingFailed(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:      return "No internet connection. Your purchase will be saved when you're back online."
        case .timeout:                 return "Request timed out. Please try again."
        case .parsingFailed:           return "Couldn't understand that purchase. Try rephrasing it."
        case .apiError(let c, _):
            switch c {
            case 429:                  return "Too many requests. Please wait a moment and try again."
            case 500...599:            return "Server issue. Please try again shortly."
            default:                   return "Something went wrong. Please try again."
            }
        }
    }
}

final class ClaudeService {
    static let shared = ClaudeService()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func parseTransaction(_ input: String) async throws -> ParsedTransaction {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClaudeError.parsingFailed("Empty input")
        }

        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue(Secrets.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let prompt = """
        You are a purchase parser for a personal budgeting app. \
        Parse the user's input and return ONLY a JSON object with these exact fields:
        - "amount": a number (the dollar amount spent, no currency symbol)
        - "description": a string (brief, clean description of what was purchased, title case, max 5 words)
        - "category": a string, exactly one of: Food, Transport, Entertainment, Shopping, Health, Bills, Other

        CRITICAL — how people naturally speak dollar amounts:
        People do NOT say "eight dollars and three cents." They say "eight oh three" and mean $8.03.
        They say "twenty-five sixty-two" and mean $25.62. They say "twelve fifty" and mean $12.50.
        Treat any number that sounds like dollars-and-cents as dollars.cents, not as a whole number.
        Specific rules:
        - Two separate number groups where the second is 2 digits = dollars then cents.
          "8 03" = $8.03, "12 50" = $12.50, "116 57" = $116.57, "45 99" = $45.99.
          The first group is always the full dollar amount — do NOT re-split it.
        - Speech recognizers sometimes split a hundreds digit into a separate word: "One 1657" means
          one-sixteen-fifty-seven = $116.57. Rule: word number ("one","two","three"...) + 4-digit number →
          the word is the hundreds prefix, the 4-digit number contains the remaining dollars.cents.
          "One 1657" → 100 + 16.57 = $116.57. "Two 2550" → 200 + 25.50 = $225.50.
        - A single unbroken number with no "hundred/thousand" and no natural pause:
          3 digits → first digit is dollars, last two are cents: "803" = $8.03
          4 digits → first two are dollars, last two are cents: "2562" = $25.62
        - Only treat a number as a large whole amount if the user explicitly says "hundred" or "thousand",
          or if context makes it unambiguous (e.g. "rent was two thousand").
        - "eight fifty" = $8.50 (not $850), "forty-five" = $45.00, "a dollar twenty" = $1.20
        - "buck fifty" = $1.50 (not $150). "a buck" = $1.00, "a buck twenty" = $1.20
        - Retail pricing: "nine ninety-nine" = $9.99, "nineteen ninety-nine" = $19.99 (not 999 or 1999)
        - Fractions: "and a half" = .50, "and a quarter" = .25 (e.g. "six and a quarter" = $6.25)
        - Cents only: "seventy-five cents" = $0.75, "fifty cents" = $0.50
        - "grand" = $1,000 (e.g. "a grand" = $1000, "two grand" = $2000)

        User input: "\(input)"

        Return ONLY the JSON object, no explanation, no markdown.
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 150,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClaudeError.timeout
        } catch {
            throw ClaudeError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.apiError(0, "Invalid response")
        }

        switch http.statusCode {
        case 200: break
        default:
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw ClaudeError.apiError(http.statusCode, body)
        }

        return try Self.parseResponse(data, fallbackDescription: input)
    }

    /// Parse the raw Claude API response `Data` into a `ParsedTransaction`.
    /// Extracted so unit tests can exercise parsing without making network calls.
    static func parseResponse(_ data: Data, fallbackDescription: String) throws -> ParsedTransaction {
        // Extract the text field from Claude's response envelope
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let textBlock = content.first(where: { $0["type"] as? String == "text" }),
              let responseText = textBlock["text"] as? String else {
            throw ClaudeError.parsingFailed("Unexpected API response format")
        }

        // Strip markdown code fences Claude sometimes adds (```json ... ```)
        var cleaned = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let parsedData = cleaned.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: parsedData) as? [String: Any] else {
            throw ClaudeError.parsingFailed(responseText)
        }

        let amount = (parsed["amount"] as? Double) ??
                     Double(parsed["amount"] as? String ?? "") ?? 0
        let description = parsed["description"] as? String ?? fallbackDescription
        let category    = parsed["category"]    as? String ?? "Other"

        guard amount > 0 else { throw ClaudeError.parsingFailed("Could not determine amount") }
        return ParsedTransaction(amount: amount, description: description, category: category)
    }
}
