import SwiftUI

// MARK: - Manual Entry Sheet
// Fallback for when voice isn't practical.
// Step 1: type your purchase. Step 2: confirm the parsed result.

struct ManualEntrySheet: View {
    var backdateDate: Date? = nil
    let onSave: (Double, String, String) -> Void

    @Environment(\.dismiss)          private var dismiss
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(ThemeManager.self)  private var theme

    @State private var inputText     = ""
    @State private var isProcessing  = false
    @State private var errorMessage: String?

    // Confirm step
    @State private var showConfirm   = false
    @State private var confirmAmount = ""
    @State private var confirmDesc   = ""
    @State private var confirmCat    = "Other"

    @FocusState private var confirmAmountFocused: Bool

    private let categories = ["Food", "Transport", "Entertainment", "Shopping", "Health", "Bills", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()
                if showConfirm { confirmStep } else { inputStep }
            }
            .foregroundStyle(.primary)
            .navigationTitle(showConfirm ? "Confirm Purchase" : "Log a Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showConfirm ? "Back" : "Cancel") {
                        if showConfirm {
                            withAnimation { showConfirm = false }
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.appBackground)
    }

    // MARK: Step 1 — text input

    private var inputStep: some View {
        VStack(spacing: 20) {
            TextField("e.g. $45 at Trader Joe's", text: $inputText, axis: .vertical)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .background(theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .autocorrectionDisabled()

            if let err = errorMessage {
                Text(err).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            }

            Button { processInput() } label: {
                Group {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Process").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(inputText.isEmpty ? Color.gray.opacity(0.4) : RunwayColors.green)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(inputText.isEmpty || isProcessing)
            .padding(.horizontal, 24)
        }
        .padding(.top, 20)
    }

    // MARK: Step 2 — confirm

    private var confirmStep: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    HStack {
                        Text("Amount").foregroundStyle(.secondary)
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $confirmAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                                .focused($confirmAmountFocused)
                                .onChange(of: confirmAmountFocused) { _, focused in
                                    if focused { confirmAmount = "" }
                                }
                        }
                    }
                    .listRowBackground(theme.card)

                    HStack {
                        Text("Description").foregroundStyle(.secondary)
                        Spacer()
                        TextField("What was it?", text: $confirmDesc)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                    }
                    .listRowBackground(theme.card)

                    HStack {
                        Text("Category").foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $confirmCat) {
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
            .frame(height: 220)

            VStack(spacing: 10) {
                if let date = backdateDate {
                    Label(
                        "Logging for \(date.formatted(.dateTime.month(.abbreviated).day()))",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                Button {
                    guard let amount = Double(confirmAmount), amount > 0 else { return }
                    onSave(amount, confirmDesc, confirmCat)
                    dismiss()
                } label: {
                    Text("Save Purchase")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background((Double(confirmAmount) ?? 0) > 0 ? RunwayColors.green : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    // MARK: - Claude processing

    private func processInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        isProcessing = true

        Task {
            do {
                let result = try await ClaudeService.shared.parseTransaction(text)
                await MainActor.run {
                    confirmAmount = String(format: "%.2f", result.amount)
                    confirmDesc   = result.description
                    confirmCat    = result.category
                    isProcessing  = false
                    withAnimation { showConfirm = true }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }
}
