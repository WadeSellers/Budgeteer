import SwiftUI
import SwiftData

struct EditTransactionSheet: View {
    let transaction: Transaction
    var onDelete: (() -> Void)?

    @Environment(\.dismiss)         private var dismiss
    @Environment(\.modelContext)    private var modelContext
    @Environment(ThemeManager.self) private var theme

    @State private var amountText:  String
    @State private var description: String
    @State private var category:    String

    @FocusState private var amountFocused: Bool

    private let categories = ["Food", "Transport", "Entertainment", "Shopping", "Health", "Bills", "Other"]

    init(transaction: Transaction, onDelete: (() -> Void)? = nil) {
        self.transaction = transaction
        self.onDelete    = onDelete
        _amountText  = State(initialValue: String(format: "%.2f", transaction.amount))
        _description = State(initialValue: transaction.transactionDescription)
        _category    = State(initialValue: transaction.category)
    }

    private var canSave: Bool {
        (Double(amountText) ?? 0) > 0 && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    fieldList
                    buttons
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
            }
            .foregroundStyle(.primary)
            .navigationTitle("Edit Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.appBackground)
    }

    // MARK: - Fields

    private var fieldList: some View {
        List {
            Section {
                HStack {
                    Text("Amount").foregroundStyle(.secondary)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                            .focused($amountFocused)
                            .onChange(of: amountFocused) { _, focused in
                                if focused { amountText = "" }
                            }
                    }
                }
                .listRowBackground(theme.card)

                HStack {
                    Text("Description").foregroundStyle(.secondary)
                    Spacer()
                    TextField("What was it?", text: $description)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.primary)
                }
                .listRowBackground(theme.card)

                HStack {
                    Text("Category").foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                .listRowBackground(theme.card)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .frame(height: 240)
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                guard let amount = Double(amountText), amount > 0 else { return }
                transaction.amount = amount
                transaction.transactionDescription = description
                transaction.category = category
                try? modelContext.save()
                dismiss()
            } label: {
                Text("Save Changes")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSave ? RunwayColors.green : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canSave)

            Button(role: .destructive) {
                modelContext.delete(transaction)
                try? modelContext.save()
                onDelete?()
                dismiss()
            } label: {
                Text("Delete Purchase")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
}
