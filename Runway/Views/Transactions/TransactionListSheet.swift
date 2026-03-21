import SwiftUI
import SwiftData

struct TransactionListSheet: View {
    /// nil = full current month. Non-nil = show only that specific day.
    var filterDate: Date? = nil

    @Environment(\.dismiss)          private var dismiss
    @Environment(\.modelContext)     private var modelContext
    @Environment(BudgetManager.self) private var budgetManager
    @Environment(ThemeManager.self)  private var theme

    @Query(sort: \Transaction.timestamp, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var editingTransaction: Transaction?

    private var displayedTransactions: [Transaction] {
        if let date = filterDate {
            return budgetManager.transactions(for: date, in: allTransactions)
        } else {
            return budgetManager.sortedCurrentMonth(allTransactions)
        }
    }

    private var pendingTransactions: [Transaction] {
        allTransactions.filter { $0.isPending && $0.monthKey == Transaction.currentMonthKey }
    }

    private var isToday: Bool {
        guard let date = filterDate else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private var navTitle: String {
        guard let date = filterDate else { return "Purchases" }
        if isToday { return "Today" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var sectionTitle: String {
        guard let date = filterDate else { return "This Month" }
        if isToday { return "Today's Purchases" }
        return date.formatted(.dateTime.month(.wide).day())
    }

    private var emptyMessage: String {
        guard let date = filterDate else { return "No purchases yet this month" }
        if isToday { return "No purchases today" }
        return "No purchases on \(date.formatted(.dateTime.month(.wide).day()))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                List {
                    // Pending section — only shown in full-month mode
                    if filterDate == nil && !pendingTransactions.isEmpty {
                        Section {
                            ForEach(pendingTransactions) { t in
                                TransactionRow(transaction: t, isPending: true)
                                    .listRowBackground(theme.card)
                            }
                        } header: {
                            Text("Processing when online…")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }

                    Section {
                        if displayedTransactions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "cart")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text(emptyMessage)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(displayedTransactions) { t in
                                TransactionRow(transaction: t, isPending: false)
                                    .listRowBackground(theme.card)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingTransaction = t }
                            }
                            .onDelete(perform: delete)
                        }
                    } header: {
                        HStack {
                            Text(sectionTitle)
                            Spacer()
                            let total = displayedTransactions.reduce(0) { $0 + $1.amount }
                            Text(String(format: "Total  $%.2f", total))
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .foregroundStyle(.primary)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(.primary)
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton().foregroundStyle(.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionSheet(transaction: transaction)
                .environment(theme)
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(displayedTransactions[i]) }
        try? modelContext.save()
    }
}

// MARK: - Row

struct TransactionRow: View {
    let transaction: Transaction
    let isPending: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(transaction.categoryEmoji)
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(Color.primary.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(isPending ? "Processing…" : transaction.transactionDescription)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isPending ? .secondary : .primary)
                Text(transaction.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isPending {
                ProgressView().tint(.orange)
            } else {
                Text(transaction.formattedAmount)
                    .font(.headline)
            }
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 4)
    }
}
