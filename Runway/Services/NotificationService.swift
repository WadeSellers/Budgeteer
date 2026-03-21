import UserNotifications

enum ThresholdType: String {
    case yellow, red, overBudget
}

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    @discardableResult
    func requestPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    func notify(_ type: ThresholdType, remaining: Double, budget: Double) {
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch type {
        case .yellow:
            let pctSpent = Int((1 - remaining / budget) * 100)
            content.title = "Spendometer Check 💰"
            content.body  = "You've spent \(pctSpent)% of your budget. \(fmt(remaining)) remaining."
        case .red:
            content.title = "Low Balance ⚠️"
            content.body  = "Only \(fmt(remaining)) left in your budget this month."
        case .overBudget:
            content.title = "Over Budget 🛑"
            content.body  = "You're \(fmt(abs(remaining))) over your monthly budget."
        }

        let id = "spendometer-\(type.rawValue)-\(Int(Date().timeIntervalSince1970))"
        let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private func fmt(_ amount: Double) -> String { String(format: "$%.2f", amount) }
}
