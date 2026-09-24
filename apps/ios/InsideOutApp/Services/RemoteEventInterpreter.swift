import Foundation

/// Domain A + B via the backend's /sessions/run. If the backend can't be
/// reached at all, falls back to on-device keyword matching so the app still
/// works offline; server errors are surfaced so the user can retry with their
/// input intact.
struct RemoteEventInterpreter: EventInterpreting {
    var client = APIClient()
    var local = LocalEventInterpreter()

    func interpret(eventText: String, source: EventSource, context: EcosystemContext) async throws -> EventAnalysis {
        let response: SessionResponseDTO
        do {
            response = try await client.runSession(text: eventText, source: source, snapshot: SnapshotDTO(context))
        } catch APIError.unreachable {
            return Self.withLocalBond(try await local.interpret(eventText: eventText, source: source, context: context),
                                      context: context)
        }
        return try Self.analysis(from: response)
    }

    static func analysis(from response: SessionResponseDTO) throws -> EventAnalysis {
        let feeds = response.interpretation.figures.compactMap { figure -> FigureFeed? in
            guard let kind = FigureKind(rawValue: figure.id) else { return nil }
            return FigureFeed(figure: kind, feedAmount: figure.feed, concentration: figure.concentration,
                              evidence: figure.evidence, voiceLine: figure.voiceLine)
        }
        guard !feeds.isEmpty else { throw APIError.invalidResponse }

        // Domain B always promotes exactly one pair — for a lone Figure it's
        // an existing bond with a Figure that sat this event out.
        let rel = response.resolution.promotedRelationship
        let kinds = rel.figures.compactMap(FigureKind.init(rawValue:))
        let bond = kinds.count == 2
            ? RelationshipPromotion(firstFigure: kinds[0], secondFigure: kinds[1], points: rel.delta,
                                    reason: rel.reason, before: rel.before)
            : nil

        return EventAnalysis(
            summary: response.interpretation.summary,
            feeds: feeds,
            promotedRelationship: bond,
            interpretationMode: response.fallback.interpretation ? "Server keyword fallback" : "Language model",
            isKeywordGuess: response.fallback.interpretation
        )
    }

    /// Offline: fill in the bond's starting score from local state.
    private static func withLocalBond(_ analysis: EventAnalysis, context: EcosystemContext) -> EventAnalysis {
        guard var bond = analysis.promotedRelationship else { return analysis }
        bond.before = context.relationships[bond.pair] ?? 0
        return EventAnalysis(summary: analysis.summary, feeds: analysis.feeds, promotedRelationship: bond,
                             interpretationMode: analysis.interpretationMode, isKeywordGuess: analysis.isKeywordGuess)
    }
}
