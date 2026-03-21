import SwiftUI
import SwiftData

// Wrapper so we can use a String as an Identifiable sheet item
private struct MonthSelection: Identifiable {
    let id: String
}

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self) private var theme

    @Query private var allTransactions: [Transaction]
    @State private var selected: MonthSelection?

    var pastMonths: [String] { budgetManager.availableMonths(allTransactions) }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                if pastMonths.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                        Text("No history yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Past months appear here automatically\nafter each month rolls over.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(pastMonths, id: \.self) { key in
                        Button { selected = MonthSelection(id: key) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(budgetManager.displayMonth(key))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    let count = budgetManager.transactions(for: key, in: allTransactions).count
                                    Text("\(count) purchase\(count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "$%.2f", budgetManager.totalSpent(for: key, in: allTransactions)))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(theme.card)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .foregroundStyle(.primary)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(.primary)
                }
            }
            .sheet(item: $selected) { selection in
                MonthDetailView(monthKey: selection.id)
                    .environment(budgetManager)
                    .environment(theme)
            }
        }
    }
}

// MARK: - Month Detail

struct MonthDetailView: View {
    let monthKey: String

    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self) private var theme
    @Query private var allTransactions: [Transaction]

    private var transactions: [Transaction] {
        budgetManager.transactions(for: monthKey, in: allTransactions)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                List {
                    Section {
                        ForEach(transactions) { t in
                            TransactionRow(transaction: t, isPending: false)
                                .listRowBackground(theme.card)
                        }
                    } header: {
                        HStack {
                            Text("\(transactions.count) purchases")
                            Spacer()
                            Text(String(format: "Total  $%.2f",
                                        budgetManager.totalSpent(for: monthKey, in: allTransactions)))
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .foregroundStyle(.primary)
            .navigationTitle(budgetManager.displayMonth(monthKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
