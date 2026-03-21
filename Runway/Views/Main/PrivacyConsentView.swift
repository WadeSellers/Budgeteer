import SwiftUI

/// Visual, icon-driven consent card shown before the user's first voice recording.
/// Explains the voice → text → AI → categories flow in a friendly way.
struct PrivacyConsentView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Drag handle
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 24)

            // Title
            Text("How Voice Recording Works")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 28)

            // Flow steps
            VStack(spacing: 20) {
                flowStep(
                    icon: "mic.fill",
                    color: BudgeteerColors.green,
                    title: "You speak",
                    detail: "Hold the button and say what you bought"
                )

                flowArrow()

                flowStep(
                    icon: "text.quote",
                    color: .blue,
                    title: "Speech becomes text",
                    detail: "Apple converts your voice to text on your device. No audio is saved or sent anywhere."
                )

                flowArrow()

                flowStep(
                    icon: "cpu",
                    color: .purple,
                    title: "AI reads the text",
                    detail: "The text is sent to an AI service to figure out the amount, description, and category. Only the text — never audio or personal info."
                )

                flowArrow()

                flowStep(
                    icon: "checkmark.circle.fill",
                    color: BudgeteerColors.green,
                    title: "Saved to your device",
                    detail: "The purchase is logged locally. Your data stays on your phone."
                )
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 24)

            // Privacy policy link
            Button {
                if let url = URL(string: "https://wadesellers.github.io/Budgeteer/privacy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Read full privacy policy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .padding(.bottom, 12)

            // Accept button
            Button {
                onAccept()
                dismiss()
            } label: {
                Text("Got It")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(BudgeteerColors.green)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(theme.appBackground)
        .preferredColorScheme(theme.resolvedColorScheme)
    }

    // MARK: - Components

    private func flowStep(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func flowArrow() -> some View {
        Image(systemName: "arrow.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}
