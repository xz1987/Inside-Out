import Foundation

struct DirectEventInterpreter: EventInterpreting {
    var client: DirectInterpretationProviding = DirectInterpretationClient()

    func interpret(eventText: String, source: EventSource, context: EcosystemContext) async throws -> EventAnalysis {
        let trimmed = eventText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EventInterpreterError.emptyInput }

        let payload = try await client.interpret(text: trimmed, source: source)
        guard (1...4).contains(payload.figures.count) else { throw DirectInterpretationError.invalidResponse }

        var seen = Set<FigureKind>()
        let decoded = try payload.figures.map { item -> FigureFeed in
            guard let kind = FigureKind(rawValue: item.id),
                  seen.insert(kind).inserted,
                  item.feed >= 0,
                  (0...1).contains(item.concentration),
                  !item.evidence.isEmpty,
                  !item.voiceLine.isEmpty
            else { throw DirectInterpretationError.invalidResponse }
            return FigureFeed(figure: kind, feedAmount: min(40, item.feed), concentration: item.concentration,
                              evidence: item.evidence, voiceLine: item.voiceLine)
        }
        let feeds = Self.normalized(decoded).sorted { $0.feedAmount > $1.feedAmount }

        let cueReason: (FigureKind, FigureKind) -> String? = { first, second in
            payload.relationshipCues.first { cue in
                Set(cue.figures) == Set([first.rawValue, second.rawValue])
            }?.reason
        }
        var bonds: [RelationshipPromotion] = []
        for i in feeds.indices {
            for j in feeds.indices where j > i {
                let first = feeds[i]
                let second = feeds[j]
                let points = max(4, Int((Double(first.feedAmount + second.feedAmount) / 4).rounded()))
                bonds.append(RelationshipPromotion(
                    firstFigure: first.figure,
                    secondFigure: second.figure,
                    points: points,
                    reason: cueReason(first.figure, second.figure) ?? "They shared the same remembered moment.",
                    before: context.relationships[FigurePair(first.figure, second.figure)] ?? 0
                ))
            }
        }
        bonds.sort { $0.points > $1.points }

        return EventAnalysis(summary: payload.summary, feeds: feeds, promotedRelationships: bonds,
                             interpretationMode: "Direct interpretation", isKeywordGuess: false)
    }

    static func normalized(_ feeds: [FigureFeed]) -> [FigureFeed] {
        let total = feeds.reduce(0) { $0 + max(0, $1.concentration) }
        guard total > 0 else { return feeds }
        var result = feeds.map {
            FigureFeed(figure: $0.figure, feedAmount: $0.feedAmount,
                       concentration: ($0.concentration / total * 100).rounded() / 100,
                       evidence: $0.evidence, voiceLine: $0.voiceLine)
        }
        let rest = result.dropFirst().reduce(0) { $0 + $1.concentration }
        if let first = result.first {
            result[0] = FigureFeed(figure: first.figure, feedAmount: first.feedAmount,
                                   concentration: max(0, (1 - rest) * 100).rounded() / 100,
                                   evidence: first.evidence, voiceLine: first.voiceLine)
        }
        return result
    }
}
enum InterpreterFactory {
    static func make() -> EventInterpreting {
        let mode = ((ProcessInfo.processInfo.environment["INTERPRETATION_MODE"]
                     ?? Bundle.main.object(forInfoDictionaryKey: "INTERPRETATION_MODE") as? String)
                    ?? "auto").lowercased()
        switch mode {
        case "direct":
            return DirectEventInterpreter()
        case "backend":
            return RemoteEventInterpreter()
        default:
            if DirectInterpretationConfiguration.current.isConfigured {
                return DirectEventInterpreter()
            }
            return RemoteEventInterpreter()
        }
    }
}
