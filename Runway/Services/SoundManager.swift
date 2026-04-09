import SwiftUI

/// Manages sound effects and haptic feedback throughout the app.
/// Sound effects are disabled until custom audio files are added.
/// Haptic feedback is always available (respects system haptics setting).
final class SoundManager {
    static let shared = SoundManager()

    @AppStorage("soundEnabled") var isEnabled: Bool = true

    // Pre-prepared generators for instant response
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)

    private init() {
        mediumGenerator.prepare()
        lightGenerator.prepare()
        softGenerator.prepare()
    }

    // MARK: - Haptic Feedback

    /// Medium impact — for recording start, significant actions
    func hapticMedium() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()  // re-prepare for next use
    }

    /// Light impact — subtle feedback
    func hapticLight() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    /// Soft impact — very subtle
    func hapticSoft() {
        softGenerator.impactOccurred()
        softGenerator.prepare()
    }

    /// Success notification haptic — for purchase saved, onboarding complete
    func hapticSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Triple tap haptic — for budget cleared, undo actions
    func hapticTripleTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            generator.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            generator.impactOccurred()
        }
    }

    // MARK: - Sound Effects (placeholder for custom audio)

    /// Bill counter tap — placeholder, currently haptic-only
    func playBillTap() {
        // Custom sound file will go here
        // playCustomSound("bill_tap")
    }

    /// Recording starts
    func playRecordingStart() {
        hapticMedium()
        // Custom sound file will go here
    }

    /// Speech captured / recording stop
    func playRecordingCaptured() {
        hapticLight()
        // Custom sound file will go here
    }

    /// Purchase saved
    func playPurchaseSaved() {
        hapticSuccess()
        // Custom sound file will go here
    }

    /// Budget cleared
    func playBudgetCleared() {
        hapticTripleTap()
        // Custom sound file will go here
    }

    /// Curtain reveal / arrival
    func playCurtainReveal() {
        hapticSuccess()
        // Custom sound file will go here
    }

}
