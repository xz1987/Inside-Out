import SwiftUI

@MainActor
final class JournalViewModel: ObservableObject {
    enum Screen: Hashable {
        case home, listening, result, figures, memories
    }

    enum InputMode {
        case voice, typed
    }

    static let minimumTypedLength = 15

    /// Stand-in transcript until real recording + transcription lands (Sprint 1).
    private static let demoSentences = [
        "So on my way home from work,",
        "this car just cut me off at the roundabout.",
        "The driver yelled at me like it was my fault.",
        "I keep thinking it could happen again tomorrow.",
        "Honestly, I’m still a bit shaky."
    ]
    private static let demoWords: [(word: String, sentence: Int)] = demoSentences.enumerated().flatMap { index, sentence in
        sentence.split(separator: " ").map { (String($0), index) }
    }

    @Published private(set) var screen: Screen = .home
    @Published private(set) var heardWords = 0
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

    private let interpreter: EventInterpreting
    /// Only used for the live Figure reactions while listening.
    private let keywordSignals = LocalEventInterpreter()
    private var listenTask: Task<Void, Never>?
    private var pendingTask: Task<Void, Never>?
    /// Bumped on every navigation so late results from an abandoned request are dropped.
    private var navigation = 0

    init(interpreter: EventInterpreting = RemoteEventInterpreter()) {
        self.interpreter = interpreter
    }

    // MARK: - Derived state

    var showsStage: Bool { [.home, .listening, .result].contains(screen) }
    var showsTabs: Bool { [.home, .figures, .memories].contains(screen) }
    var canFinishListening: Bool { heardWords > 8 }

    var transcriptSoFar: String {
        Self.demoWords.prefix(heardWords).map(\.word).joined(separator: " ")
    }

    /// The last three sentences heard, oldest first.
    var transcriptLines: [(id: Int, text: String)] {
        var sentences: [Int: [String]] = [:]
        for item in Self.demoWords.prefix(heardWords) {
            sentences[item.sentence, default: []].append(item.word)
        }
        return sentences.keys.sorted().suffix(3).map { ($0, sentences[$0]!.joined(separator: " ")) }
    }

    var listeningClock: String {
        let seconds = Int((Double(heardWords) * 0.21).rounded())
        return "0:" + String(format: "%02d", seconds)
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
        listenTask?.cancel()
        pendingTask?.cancel()
        navigation += 1
        isInterpreting = false
        interpretError = nil
        withAnimation(.easeInOut(duration: 0.4)) {
            isTyping = false
            toast = nil
            screen = destination
        }
        if destination == .listening {
            startListening()
        }
    }

    func micTapped() {
        switch screen {
        case .home: go(.listening)
        case .listening: finishListening()
        default: break
        }
    }

    private func startListening() {
        heardWords = 0
        listenTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            while !Task.isCancelled {
                guard let self, self.heardWords < Self.demoWords.count else { return }
                // No withAnimation: animating text updates cross-fades every word.
                // Figure growth animates on its own via `.animation(value: levels)`.
                self.heardWords += 1
                try? await Task.sleep(for: .milliseconds(210))
            }
        }
    }

    /// Also the retry action after an error — the transcript is kept.
    func finishListening() {
        guard canFinishListening, !isInterpreting else { return }
        recordedSeconds = Int((Double(heardWords) * 0.21).rounded())
        let text = transcriptSoFar
        listenTask?.cancel()
        Task { await interpret(text, mode: .voice) }
    }

    func openTyping() {
        typeError = nil
        isTyping = true
    }

    func submitTyped() {
        guard !isInterpreting else { return }
        let text = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= Self.minimumTypedLength else {
            typeError = "Add a little more — at least \(Self.minimumTypedLength) characters."
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
        if let bond = analysis.promotedRelationship, let after = bond.after {
            relationships[bond.pair] = after
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
