import SwiftUI

@MainActor
final class JournalViewModel: ObservableObject {
    enum Screen: Hashable {
        case home, listening, result, figures, memories
    }

    enum InputMode {
        case voice, typed
    }

    @Published private(set) var screen: Screen = .home
    @Published var isTyping = false
    @Published var typedText = ""
    @Published var typeError: String?
    @Published private(set) var analysis: EventAnalysis?
    @Published private(set) var inputMode: InputMode = .voice
    @Published private(set) var capturedAt = Date()
    @Published private(set) var recordedSeconds = 0
    /// Figure progress as it was when the current result was produced.
    @Published private(set) var baseline: [FigureKind: FigureState] = FigureState.seed
    @Published private(set) var figures: [FigureKind: FigureState] = FigureState.seed
    @Published private(set) var memories: [MemoryEntry] = MemoryEntry.seed()
    @Published private(set) var relationships: [FigurePair: Int] = FigurePair.seedScores
    @Published private(set) var isSaved = false
    @Published private(set) var toast: String?
    @Published var selectedFigure: FigureKind = .anger
    /// A request to the backend is in flight.
    @Published private(set) var isInterpreting = false
    /// Shown on the Listening screen; the transcript is kept so Done retries.
    @Published private(set) var interpretError: String?
    /// Exactly what was sent for the current result (transcript or typed text).
    @Published private(set) var lastInputText = ""
    @Published private(set) var isFinalizingVoice = false

    private let interpreter: EventInterpreting
    let voiceRecorder: SpeechRecordingService
    /// Only used for the live Figure reactions while listening.
    private let keywordSignals = LocalEventInterpreter()
    private var pendingTask: Task<Void, Never>?
    /// Bumped on every navigation so late results from an abandoned request are dropped.
    private var navigation = 0

    init(interpreter: EventInterpreting = RemoteEventInterpreter(),
         voiceRecorder: SpeechRecordingService? = nil) {
        self.interpreter = interpreter
        self.voiceRecorder = voiceRecorder ?? SpeechRecordingService()
    }

    // MARK: - Derived state

    var showsStage: Bool { [.home, .listening, .result].contains(screen) }
    var showsTabs: Bool { [.home, .figures, .memories].contains(screen) }
    var canFinishListening: Bool { voiceRecorder.isDurationValid }
    var isVoiceBusy: Bool {
        isFinalizingVoice || isInterpreting || voiceRecorder.state == .requestingPermission || voiceRecorder.state == .transcribing
    }

    var transcriptSoFar: String {
        voiceRecorder.transcript
    }

    /// The last three sentences heard, oldest first.
    var transcriptLines: [(id: Int, text: String)] {
        let words = transcriptSoFar.split(whereSeparator: \.isWhitespace).map(String.init)
        return stride(from: 0, to: words.count, by: 8).map { start in
            (start / 8, words[start..<min(start + 8, words.count)].joined(separator: " "))
        }.suffix(3)
    }

    var listeningClock: String {
        let seconds = Int(voiceRecorder.elapsedSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// How strongly each Figure reacts to what has been said so far (0–2).
    var listeningLevels: [FigureKind: Int] {
        keywordSignals.signalCounts(in: transcriptSoFar).mapValues { min(2, $0) }
    }

    var capturedLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Today, " + formatter.string(from: capturedAt).lowercased()
    }

    // MARK: - Navigation

    func go(_ destination: Screen) {
        pendingTask?.cancel()
        navigation += 1
        isInterpreting = false
        interpretError = nil
        withAnimation(.easeInOut(duration: 0.4)) {
            isTyping = false
            toast = nil
            screen = destination
        }
    }

    func micTapped() {
        switch screen {
        case .home: Task { await beginVoiceRecording() }
        case .listening: Task { await voiceRecorder.togglePause() }
        default: break
        }
    }

    private func beginVoiceRecording() async {
        guard !isVoiceBusy else { return }
        if await voiceRecorder.startNewRecording() {
            go(.listening)
        }
    }

    func finishListening() {
        guard canFinishListening, !isVoiceBusy else { return }
        Task {
            let started = navigation
            isFinalizingVoice = true
            defer { isFinalizingVoice = false }
            do {
                let capture: SpeechRecordingService.Capture
                if voiceRecorder.state == .finished, let url = voiceRecorder.recordingURL {
                    capture = .init(transcript: voiceRecorder.transcript,
                                    duration: voiceRecorder.elapsedSeconds, fileURL: url)
                } else {
                    capture = try await voiceRecorder.finishAndTranscribe()
                }
                guard navigation == started, screen == .listening else { return }
                recordedSeconds = Int(capture.duration.rounded())
                await interpret(capture.transcript, mode: .voice)
            } catch {
                // The recorder owns the user-facing error and keeps the audio for retry.
            }
        }
    }

    func deleteAndRerecord() {
        guard !isVoiceBusy else { return }
        Task { _ = await voiceRecorder.startNewRecording() }
    }

    func cancelVoice() {
        voiceRecorder.deleteRecording()
        go(.home)
    }

    func openTyping() {
        typeError = nil
        isTyping = true
    }

    func submitTyped() {
        guard !isInterpreting else { return }
        let text = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Any length counts — even "tired" is a real moment. Only blank is rejected.
        guard !text.isEmpty else {
            typeError = "Write a few words first."
            return
        }
        Task { await interpret(text, mode: .typed) }
    }

    private func interpret(_ text: String, mode: InputMode) async {
        let started = navigation
        interpretError = nil
        typeError = nil
        withAnimation(.easeInOut(duration: 0.3)) { isInterpreting = true }
        defer { if navigation == started { isInterpreting = false } }

        do {
            let context = EcosystemContext(figures: figures, relationships: relationships, memories: memories)
            let result = try await interpreter.interpret(eventText: text, source: mode == .voice ? .voice : .message,
                                                         context: context)
            guard navigation == started else { return }
            analysis = result
            lastInputText = text
            inputMode = mode
            capturedAt = Date()
            baseline = figures
            isSaved = false
            if mode == .typed { typedText = "" }
            go(.result)
        } catch {
            guard navigation == started else { return }
            let message = error.localizedDescription
            if mode == .typed {
                typeError = message
            } else {
                withAnimation(.easeOut(duration: 0.3)) { interpretError = message }
            }
        }
    }

    // MARK: - Result actions

    func save() {
        guard let analysis, !isSaved else { return }
        for feed in analysis.feeds {
            figures[feed.figure]?.feed(feed.feedAmount)
        }
        for bond in analysis.promotedRelationships {
            if let after = bond.after { relationships[bond.pair] = after }
        }
        for index in memories.indices { memories[index].isNew = false }
        memories.insert(
            MemoryEntry(date: capturedAt, text: analysis.summary,
                        figures: analysis.feeds.map(\.figure), isNew: true),
            at: 0
        )
        isSaved = true
        let gains = analysis.feeds.map { "\($0.figure.displayName) +\($0.feedAmount)" }
        withAnimation(.easeOut(duration: 0.4)) {
            toast = (["Saved"] + gains).joined(separator: " · ")
        }
        let primary = analysis.feeds.first?.figure ?? .anger
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled, let self else { return }
            self.selectedFigure = primary
            self.go(.figures)
        }
    }

    /// "Edit input" (PRD §31 A): back to the start with the original text
    /// pre-filled in the type sheet, voice or not.
    func editLastInput() {
        let text = lastInputText
        go(.home)
        pendingTask = Task { [weak self] in
            // Let the result screen's sheet finish dismissing first.
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            self.typedText = text
            self.openTyping()
        }
    }

    func tellAnother() {
        go(.home)
    }
}
