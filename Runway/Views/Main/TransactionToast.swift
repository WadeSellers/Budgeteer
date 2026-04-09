import SwiftUI

/// A compact, notification-style banner that confirms a transaction was saved.
/// Auto-dismisses after a few seconds. Tap to open the edit sheet.
struct TransactionToast: View {
    let transaction: Transaction
    let onTap:       () -> Void
    let onDismiss:   () -> Void

    @Environment(ThemeManager.self) private var theme

    private var cardBackground: Color {
        theme.isLight
            ? Color(red: 0.15, green: 0.15, blue: 0.17)
            : .white
    }

    private var primaryText: Color {
        theme.isLight ? .white : .black
    }

    private var secondaryText: Color {
        theme.isLight ? .white.opacity(0.6) : .black.opacity(0.45)
    }

    private var tertiaryText: Color {
        theme.isLight ? .white.opacity(0.4) : .black.opacity(0.25)
    }

    private var badgeBackground: Color {
        theme.isLight ? .white.opacity(0.1) : .black.opacity(0.06)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category badge
                Text(transaction.categoryEmoji)
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(badgeBackground)
                    .clipShape(Circle())

                // Description + amount
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.transactionDescription)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    Text("Saved \(transaction.formattedAmount) · Tap to edit")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }

                Spacer()

                // Hint that it's tappable
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saved \(transaction.formattedAmount) for \(transaction.transactionDescription)")
        .accessibilityHint("Tap to edit this purchase")
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
