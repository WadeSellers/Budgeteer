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
                Text("Before You Record")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .padding(.bottom, 36)

                // Three concise points
                VStack(spacing: 24) {
                    privacyPoint(
                        icon: "waveform",
                        text: "Your voice is converted to text **on your device**. No audio is saved or sent."
                    )

                    privacyPoint(
                        icon: "cpu",
                        text: "The text is sent to AI to extract the **amount and category**. Nothing else."
                    )

                    privacyPoint(
                        icon: "lock.shield",
                        text: "Your purchases **stay on your phone**. We don't have an account or a server."
                    )
                }

                Spacer(minLength: 20)

                // Privacy policy link
                Button {
                    if let url = URL(string: "https://wadesellers.github.io/Budgeteer/privacy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Full privacy policy")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .underline()
                }
                .padding(.bottom, 18)

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
            .frame(maxWidth: .infinity, maxHeight: H * 0.82)
        }
        .ignoresSafeArea()
    }

    // MARK: - Components

    private func privacyPoint(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.2))
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
