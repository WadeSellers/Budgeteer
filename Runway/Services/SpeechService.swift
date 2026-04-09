import Foundation
import Speech
import AVFoundation

@Observable
final class SpeechService {
    var isRecording       = false
    var transcript        = ""
    var permissionGranted = false
    var lastError: String?

    private var audioEngine        = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?
    private let recognizer         = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var interruptionObserver: NSObjectProtocol?
    private var recognitionTimeoutTask: Task<Void, Never>?

    // MARK: - Permissions

    @MainActor
    func requestPermissions() async {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        permissionGranted = speechStatus == .authorized && micGranted
        if permissionGranted { prewarm() }
    }

    // MARK: - Pre-warm
    // Call on view appear so the recognition task is already spun up
    // before the user ever touches the mic button.

    func prewarm() {
        guard permissionGranted, recognitionTask == nil, !isRecording else { return }
        // Pre-create the recognition task (audio category is set in start() to avoid
        // suppressing haptic feedback while the user isn't recording)
        setupRecognitionTask()
    }

    // MARK: - Start / Stop

    func start() throws {
        guard !isRecording else { return }
        transcript = ""
        lastError = nil

        // Guard: recognizer must be available
        guard let rec = recognizer, rec.isAvailable else {
            lastError = "Speech recognition unavailable"
            return
        }

        // If somehow the pre-warm didn't happen, set up now
        if recognitionTask == nil {
            setupRecognitionTask()
        }

        // Configure audio session for recording and activate
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Listen for audio session interruptions (e.g. incoming phone call)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                  type == .began else { return }
            // An interruption started (e.g. phone call) — stop gracefully
            self?.stop()
        }

        // Install tap and start the engine
        let inputNode = audioEngine.inputNode
        let format    = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        // Safety timeout — stop after 60 seconds to prevent recognition from hanging
        recognitionTimeoutTask?.cancel()
        recognitionTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled, let self, self.isRecording else { return }
            self.stop()
        }
    }

    func stop() {
        // Signal end of audio — recognition task will fire isFinal with complete transcript
        recognitionRequest?.endAudio()
        // Stop audio capture; DO NOT cancel the task — let it finalize the transcript
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        // isRecording stays true until stopInternal() is called by the task callback
    }

    // MARK: - Private

    private func setupRecognitionTask() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        guard let request = recognitionRequest,
              let rec     = recognizer,
              rec.isAvailable else { return }

        recognitionTask = rec.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async { self?.stopInternal() }
            }
        }
    }

    private func stopInternal() {
        recognitionRequest = nil
        recognitionTask    = nil
        isRecording        = false
        recognitionTimeoutTask?.cancel()
        recognitionTimeoutTask = nil
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false)
        // Reset to ambient so haptic feedback works between recordings
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        // Immediately pre-warm for the next press
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.prewarm()
        }
    }
}
