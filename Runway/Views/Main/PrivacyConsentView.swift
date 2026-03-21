import SwiftUI

/// Consent content that floats on top of the green recording overlay.
/// White text on the green background — no card needed.
/// Positioned in the upper portion of the screen, above the mic button.
struct PrivacyConsentView: View {

    let onAccept: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let H = proxy.size.height

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Title
                Text("How Voice Recording Works")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .padding(.bottom, 28)

                // Flow steps
                VStack(spacing: 16) {
                    flowStep(
                        icon: "mic.fill",
                        title: "You speak",
                        detail: "Hold the button and say what you bought"
                    )

                    flowArrow()

                    flowStep(
                        icon: "text.quote",
                        title: "Speech becomes text",
                        detail: "Apple converts your voice to text on your device. No audio is saved or sent anywhere."
                    )

                    flowArrow()

                    flowStep(
                        icon: "cpu",
                        title: "AI reads the text",
                        detail: "The text is sent to an AI service to figure out the amount, description, and category. Only the text — never audio or personal info."
                    )

                    flowArrow()

                    flowStep(
                        icon: "checkmark.circle.fill",
                        title: "Saved to your device",
                        detail: "The purchase is logged locally. Your data stays on your phone."
                    )
                }

                Spacer(minLength: 16)

                // Privacy policy link
                Button {
                    if let url = URL(string: "https://wadesellers.github.io/Budgeteer/privacy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Read full privacy policy")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .underline()
                }
                .padding(.bottom, 16)

                // Accept button
                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Text("Got It")
                            .font(.headline.weight(.bold))
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 36)
            // Keep everything in the upper ~82% so it doesn't overlap the mic button
            .frame(maxWidth: .infinity, maxHeight: H * 0.82)
        }
        .ignoresSafeArea()
    }

    // MARK: - Components

    private func flowStep(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func flowArrow() -> some View {
        Image(systemName: "arrow.down")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.5))
    }
}
