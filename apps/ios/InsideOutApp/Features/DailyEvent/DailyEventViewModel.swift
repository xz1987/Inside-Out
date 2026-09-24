import Foundation

@MainActor
final class DailyEventViewModel: ObservableObject {
    @Published var eventText = ""
    @Published private(set) var analysis: EventAnalysis?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let interpreter: EventInterpreting

    init(interpreter: EventInterpreting = LocalEventInterpreter()) {
        self.interpreter = interpreter
    }

    var canSubmit: Bool {
        eventText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 15
            && !isLoading
    }

    func interpretEvent() async {
        guard canSubmit else { return }

        isLoading = true
        errorMessage = nil
        analysis = nil

        do {
            analysis = try await interpreter.interpret(eventText: eventText)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func startOver() {
        eventText = ""
        analysis = nil
        errorMessage = nil
    }
}

