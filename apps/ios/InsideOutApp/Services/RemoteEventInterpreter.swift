import Foundation

/// Domain A via the backend. If the backend can't be reached at all, falls
/// back to on-device keyword matching so the app still works offline; server
/// errors are surfaced so the user can retry with their input intact.
struct RemoteEventInterpreter: EventInterpreting {
    var client = APIClient()
    var local = LocalEventInterpreter()

    /// Relationship points until Domain B computes them.
    static let defaultBondPoints = 8

    func interpret(eventText: String, source: EventSource) async throws -> EventAnalysis {
        let response: InterpretResponseDTO
        do {
            response = try await client.interpret(text: eventText, source: source)
        } catch APIError.unreachable {
            return try await local.interpret(eventText: eventText, source: source)
        }
        return try Self.analysis(from: response)
    }

    static func analysis(from response: InterpretResponseDTO) throws -> EventAnalysis {
        let dto = response.interpretation
        let feeds = dto.figures.compactMap { figure -> FigureFeed? in
            guard let kind = FigureKind(rawValue: figure.id) else { return nil }
            return FigureFeed(figure: kind, feedAmount: figure.feed, concentration: figure.concentration,
                              evidence: figure.evidence, voiceLine: figure.voiceLine)
        }
        guard !feeds.isEmpty else { throw APIError.invalidResponse }

        return EventAnalysis(
            summary: dto.summary,
            feeds: feeds,
            promotedRelationship: relationship(for: feeds, cues: dto.relationshipCues),
            interpretationMode: response.fallback ? "Server keyword fallback" : "Language model (\(response.promptVersion))",
            isKeywordGuess: response.fallback
        )
    }

    /// Prefer the model's cue for the top pair; otherwise pair the two most-fed Figures.
    private static func relationship(for feeds: [FigureFeed], cues: [InterpretationDTO.RelationshipCue]) -> RelationshipPromotion? {
        guard feeds.count > 1 else { return nil }
        let top = Set([feeds[0].figure, feeds[1].figure])
        let cue = cues.first { Set($0.figures.compactMap(FigureKind.init(rawValue:))) == top }
        return RelationshipPromotion(
            firstFigure: feeds[0].figure,
            secondFigure: feeds[1].figure,
            points: defaultBondPoints,
            reason: cue?.reason ?? "They were both present in the same remembered event."
        )
    }
}
