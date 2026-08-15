import Foundation
import Speech
import AVFoundation

@Observable
final class SpeechService {
    var isRecording       = false
    var transcript        = ""
    var permissionGranted = false
    var lastError: String?

    // Audio file capture — opt-in for Town Hall recordings
    var saveAudioToFile   = false
    private(set) var audioFileURL: URL?
    private var audioFile: AVAudioFile?

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

    private var isStarting = false

    func start() throws {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        transcript = ""
        lastError = nil

        // Guard: recognizer must be available
        guard let rec = recognizer, rec.isAvailable else {
            lastError = "Speech recognition unavailable"
            isStarting = false
            return
        }

        // Always start with a fresh recognition task — a prewarmed task may have
        // gone stale (especially in Town Hall where there's a category selection step
        // between prewarm and recording).
        if recognitionTask != nil {
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            recognitionRequest = nil
            recognitionTask = nil
        }
        setupRecognitionTask()

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

        // If saveAudioToFile is enabled, create an audio file to write alongside transcription
        if saveAudioToFile {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("caf")
            audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
            audioFileURL = url
        }

        // Defensive: remove any existing tap to prevent crash on double-start
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            try? self?.audioFile?.write(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        isStarting = false

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
        audioFile = nil  // Close file handle; audioFileURL kept for caller to read
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

    /// Remove the captured audio file after the caller has consumed it (e.g. uploaded to CloudKit).
    func clearAudioFile() {
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioFileURL = nil
        saveAudioToFile = false
    }

    // MARK: - Waveform Extraction

    /// Extract amplitude samples from an audio file for waveform visualization.
    /// Returns normalized [Float] array with `sampleCount` points (default 50).
    static func extractWaveform(from url: URL, sampleCount: Int = 50) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        let length = Int(file.length)
        guard length > 0 else { return [] }

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: file.fileFormat.sampleRate,
                                          channels: 1,
                                          interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length)) else {
            return []
        }

        do {
            try file.read(into: buffer)
        } catch {
            return []
        }

        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameCount = Int(buffer.frameLength)
        let samplesPerBucket = max(1, frameCount / sampleCount)

        var peaks = [Float]()
        peaks.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let start = i * samplesPerBucket
            let end = min(start + samplesPerBucket, frameCount)
            var peak: Float = 0
            for j in start..<end {
                peak = max(peak, abs(channelData[j]))
            }
            peaks.append(peak)
        }

        // Normalize to 0–1
        let maxPeak = peaks.max() ?? 1
        guard maxPeak > 0 else { return peaks }
        return peaks.map { $0 / maxPeak }
    }
}
