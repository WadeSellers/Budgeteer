import SwiftUI

/// In-app feedback form. Posts to the same Formspree inbox as AI Usage Meter;
/// the [Budgeteer] subject tag keeps the two apps' mail separable.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme

    @State private var feedbackType: FeedbackType = .bugIssue
    @State private var title: String = ""
    @State private var feedbackDescription: String = ""
    @State private var email: String = ""
    @State private var submissionState: SubmissionState = .idle

    var body: some View {
        NavigationStack {
            Group {
                if submissionState == .success {
                    confirmationView
                } else {
                    formView
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drop me a line")
                        .font(.headline)
                    Text("I read every single message — Wade")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(theme.card)
            }

            Section("What's this about?") {
                Picker("", selection: $feedbackType) {
                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(theme.card)
            }

            Section("Title") {
                TextField("What's on your mind?", text: $title)
                    .listRowBackground(theme.card)
            }

            Section("Details") {
                TextEditor(text: $feedbackDescription)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if feedbackDescription.isEmpty {
                            Text(feedbackType.placeholder)
                                .foregroundStyle(.secondary.opacity(0.6))
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .listRowBackground(theme.card)
            }

            Section {
                TextField("your@email.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .listRowBackground(theme.card)
            } header: {
                Text("Email (optional)")
            } footer: {
                Text("Only if you'd like a reply — I won't spam you, promise.")
            }

            Section {
                if case .error(let message) = submissionState {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .listRowBackground(theme.card)
                }

                Button(action: submitFeedback) {
                    HStack {
                        Spacer()
                        if submissionState == .submitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(submissionState.isError ? "Try Again" : "Send to Wade")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(BudgeteerColors.green)
                .foregroundStyle(.white)
                .disabled(!canSubmit)
            } footer: {
                Text("Includes app version and iOS version so I can reproduce bugs.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.appBackground)
    }

    // MARK: - Confirmation

    private var confirmationView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(BudgeteerColors.green)
            Text("Thanks! I'll take a look.")
                .font(.headline)
            Text("— Wade")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.appBackground)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    // MARK: - Logic

    private var canSubmit: Bool {
        submissionState != .submitting && (!title.isEmpty || !feedbackDescription.isEmpty)
    }

    private func submitFeedback() {
        submissionState = .submitting
        let payload = buildPayload()

        Task {
            do {
                try await postToFormspree(payload: payload)
                await MainActor.run {
                    withAnimation { submissionState = .success }
                }
            } catch {
                await MainActor.run {
                    submissionState = .error("Couldn't send — check your connection and try again.")
                }
            }
        }
    }

    private func buildPayload() -> [String: String] {
        let subject = "[Budgeteer]\(feedbackType.subjectTag) \(title.isEmpty ? "Feedback" : title)"

        var payload: [String: String] = [
            "_subject": subject,
            "Feedback Type": feedbackType.label,
            "Title": title,
            "Message": feedbackDescription,
            "Device Info": gatherDeviceInfo()
        ]

        if !email.isEmpty {
            payload["email"] = email
            payload["_replyto"] = email
        }

        return payload
    }

    private func postToFormspree(payload: [String: String]) async throws {
        guard let url = URL(string: "https://formspree.io/f/mykbekpd") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Budgeteer", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func gatherDeviceInfo() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        return """
        App: Budgeteer v\(appVersion) (\(buildNumber))
        iOS: \(osVersion)
        """
    }
}

// MARK: - Supporting Types

private enum FeedbackType: String, CaseIterable {
    case bugIssue
    case featureRequest
    case justSayingHi

    var label: String {
        switch self {
        case .bugIssue: return "Bug / Issue"
        case .featureRequest: return "Feature"
        case .justSayingHi: return "Say Hi"
        }
    }

    var subjectTag: String {
        switch self {
        case .bugIssue: return "[Bug]"
        case .featureRequest: return "[Feature]"
        case .justSayingHi: return "[Hi]"
        }
    }

    var placeholder: String {
        switch self {
        case .bugIssue: return "What happened? What did you expect instead?"
        case .featureRequest: return "What would make Budgeteer better for you?"
        case .justSayingHi: return "Whatever's on your mind..."
        }
    }
}

private enum SubmissionState: Equatable {
    case idle
    case submitting
    case success
    case error(String)

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
