import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecordingService: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case recording
        case paused
        case recorded
        case transcribing
        case finished
    }

    struct Capture {
        let transcript: String
        let duration: TimeInterval
        let fileURL: URL
    }

    enum RecordingError: LocalizedError {
        case microphoneDenied
        case speechDenied
        case recognizerUnavailable
        case inputUnavailable
        case tooShort(remaining: Int)
        case noSpeech
        case couldNotStart(String)

        var errorDescription: String? {
            switch self {
            case .microphoneDenied:
                "Microphone access is off. Enable it in Settings to record."
            case .speechDenied:
                "Speech Recognition access is off. Enable it in Settings to transcribe."
            case .recognizerUnavailable:
                "Speech recognition is temporarily unavailable."
            case .inputUnavailable:
                "No microphone input is available on this device."
            case .tooShort(let remaining):
                "Keep talking for \(remaining) more second\(remaining == 1 ? "" : "s")."
            case .noSpeech:
                "I couldn't hear any words. Delete this recording and try again."
            case .couldNotStart(let detail):
                "Recording couldn't start. \(detail)"
            }
        }
    }

    static let minimumDuration: TimeInterval = 5

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var audioFile: AVAudioFile?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var finalRecognitionTask: SFSpeechRecognitionTask?
    private var tickerTask: Task<Void, Never>?
    private var segmentStartedAt: Date?
    private var accumulatedDuration: TimeInterval = 0
    private var segmentPrefix = ""
    private var tapInstalled = false

    private(set) var recordingURL: URL?

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    var isRecording: Bool { state == .recording }
    var isPaused: Bool { state == .paused }
    var isFinalized: Bool { state == .recorded || state == .finished }
    var canTogglePause: Bool { state == .recording || state == .paused }
    var isDurationValid: Bool { elapsedSeconds >= Self.minimumDuration }

    var secondsRemaining: Int {
        max(0, Int(ceil(Self.minimumDuration - elapsedSeconds)))
    }

    func startNewRecording() async -> Bool {
        deleteRecording()
        state = .requestingPermission
        errorMessage = nil

        do {
            try await requestPermissions()
            try prepareNewAudioFile()
            try startSegment()
            return true
        } catch {
            fail(with: error)
            return false
        }
    }

    func togglePause() async {
        switch state {
        case .recording:
            pause()
        case .paused:
            do {
                try startSegment()
            } catch {
                fail(with: error)
            }
        default:
            break
        }
    }

    func pause() {
        guard state == .recording else { return }
        captureSegmentDuration()
        stopLiveSegment()
        state = .paused
    }

    func finishAndTranscribe() async throws -> Capture {
        if state == .recording {
            pause()
        }

        guard elapsedSeconds >= Self.minimumDuration else {
            let error = RecordingError.tooShort(remaining: secondsRemaining)
            errorMessage = error.localizedDescription
            throw error
        }
        guard let recordingURL else {
            throw RecordingError.inputUnavailable
        }

        // AVAudioFile finalizes the compressed .m4a container when released.
        // Speech cannot reliably reopen the URL while the writer still owns it.
        let liveTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        audioFile = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        state = .transcribing
        errorMessage = nil

        do {
            let finalText = try await transcribeFile(at: recordingURL)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !finalText.isEmpty else {
                state = .paused
                throw RecordingError.noSpeech
            }
            transcript = finalText
            state = .finished
            return Capture(transcript: finalText, duration: elapsedSeconds, fileURL: recordingURL)
        } catch {
            // The live recognizer already produced usable phone-side text in the
            // common case. Do not lose it just because the optional final pass
            // could not reopen the audio container.
            if !liveTranscript.isEmpty {
                transcript = liveTranscript
                state = .finished
                errorMessage = nil
                return Capture(transcript: liveTranscript, duration: elapsedSeconds, fileURL: recordingURL)
            }
            state = .recorded
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func deleteRecording() {
        stopTicker()
        stopLiveSegment()
        finalRecognitionTask?.cancel()
        finalRecognitionTask = nil

        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        recordingURL = nil
        audioFile = nil
        transcript = ""
        elapsedSeconds = 0
        accumulatedDuration = 0
        segmentStartedAt = nil
        segmentPrefix = ""
        errorMessage = nil
        state = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissions() async throws {
        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        guard microphoneAllowed else { throw RecordingError.microphoneDenied }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { throw RecordingError.speechDenied }
        guard speechRecognizer != nil else { throw RecordingError.recognizerUnavailable }
    }

    private func prepareNewAudioFile() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw RecordingError.inputUnavailable
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("inside-out-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioFile = try AVAudioFile(forWriting: url, settings: settings)
        recordingURL = url
    }

    private func startSegment() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw RecordingError.recognizerUnavailable
        }
        guard let audioFile else { throw RecordingError.inputUnavailable }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if shouldRequireOnDeviceRecognition(using: speechRecognizer) {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request
        segmentPrefix = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = segmentPrefix

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.recognitionRequest === request else { return }
                if let spoken = result?.bestTranscription.formattedString,
                   !spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.transcript = [prefix, spoken]
                        .filter { !$0.isEmpty }
                        .joined(separator: prefix.isEmpty ? "" : " ")
                }
                if let error, self.state == .recording {
                    #if targetEnvironment(simulator)
                    let nsError = error as NSError
                    self.errorMessage = "Simulator transcription stopped (\(nsError.domain) \(nsError.code)). Check I/O › Audio Input › Mac microphone, or test on iPhone."
                    #else
                    self.errorMessage = "Live transcription paused. Your recording is still being saved."
                    #endif
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            try? audioFile.write(from: buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stopLiveSegment()
            throw RecordingError.couldNotStart(error.localizedDescription)
        }

        segmentStartedAt = Date()
        state = .recording
        errorMessage = nil
        startTicker()
    }

    private func stopLiveSegment() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        stopTicker()
    }

    private func captureSegmentDuration() {
        if let segmentStartedAt {
            accumulatedDuration += Date().timeIntervalSince(segmentStartedAt)
        }
        segmentStartedAt = nil
        elapsedSeconds = accumulatedDuration
    }

    private func startTicker() {
        stopTicker()
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let started = self.segmentStartedAt {
                    self.elapsedSeconds = self.accumulatedDuration + Date().timeIntervalSince(started)
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func transcribeFile(at url: URL) async throws -> String {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw RecordingError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if shouldRequireOnDeviceRecognition(using: speechRecognizer) {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var completed = false
            finalRecognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
                guard !completed else { return }
                if let result, result.isFinal {
                    completed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error {
                    completed = true
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func shouldRequireOnDeviceRecognition(using recognizer: SFSpeechRecognizer) -> Bool {
        #if targetEnvironment(simulator)
        // Simulator does not reliably provide the on-device speech assets/ANE.
        // Keep recognition inside Apple's Speech framework, but allow its hosted
        // service so Mac microphone passthrough can be used during development.
        return false
        #else
        return recognizer.supportsOnDeviceRecognition
        #endif
    }

    private func fail(with error: Error) {
        stopTicker()
        stopLiveSegment()
        state = .idle
        errorMessage = error.localizedDescription
    }
}
