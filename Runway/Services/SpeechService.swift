import Foundation
import Speech
import AVFoundation

@Observable
final class SpeechService {
    var isRecording       = false
    var transcript        = ""
    var permissionGranted = false

    private var audioEngine        = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?
    private let recognizer         = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

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
        // Pre-configure audio session category (no activation yet — that stays fast)
        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
        // Pre-create the recognition task so it's ready to receive audio immediately
        setupRecognitionTask()
    }

    // MARK: - Start / Stop

    func start() throws {
        guard !isRecording else { return }
        transcript = ""

        // If somehow the pre-warm didn't happen, set up now
        if recognitionTask == nil {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            setupRecognitionTask()
        }

        // Activating the session is much faster when category is already configured
        let session = AVAudioSession.sharedInstance()
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Install tap and start the engine
        let inputNode = audioEngine.inputNode
        let format    = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
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
        try? AVAudioSession.sharedInstance().setActive(false)
        // Immediately pre-warm for the next press
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.prewarm()
        }
    }
}
