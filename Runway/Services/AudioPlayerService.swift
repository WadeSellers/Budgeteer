import AVFoundation
import Observation

@Observable
final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {

    var isPlaying = false
    var currentPostID: String?
    var progress: Double = 0        // 0.0 – 1.0
    var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    // MARK: - Playback

    func play(url: URL, postID: String) {
        // Stop any current playback first
        if isPlaying { stop() }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()

            currentPostID = postID
            duration = player?.duration ?? 0
            progress = 0
            isPlaying = true

            player?.play()
            startProgressTimer()
        } catch {
            print("[Budgeteer] AudioPlayer error: \(error.localizedDescription)")
            reset()
        }
    }

    func stop() {
        player?.stop()
        reset()
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        reset()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        print("[Budgeteer] AudioPlayer decode error: \(error?.localizedDescription ?? "unknown")")
        reset()
    }

    // MARK: - Private

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.progress = player.duration > 0
                ? player.currentTime / player.duration
                : 0
        }
    }

    private func reset() {
        progressTimer?.invalidate()
        progressTimer = nil
        player = nil
        isPlaying = false
        currentPostID = nil
        progress = 0
        duration = 0

        // Restore session so haptics work again
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
