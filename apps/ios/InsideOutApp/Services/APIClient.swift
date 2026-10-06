import Foundation

/// Talks to apps/api. No AI keys live in the app — only the backend URL.
struct APIClient {
    /// Resolution order:
    /// 1. Xcode scheme environment override (useful for one-off testing).
    /// 2. API_BASE_URL embedded from Debug.xcconfig / Local.xcconfig.
    /// 3. localhost for Simulator development.
    ///
    /// A physical iPhone must use the Mac's LAN/.local address or an HTTPS
    /// tunnel. `localhost` on an iPhone points back to the iPhone itself.
    static let defaultBaseURL: URL = {
        let environmentValue = ProcessInfo.processInfo.environment["API_BASE_URL"]
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String

        for value in [environmentValue, bundleValue].compactMap({ $0 }) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               ["http", "https"].contains(scheme),
               url.host != nil {
                return url
            }
        }

        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:3000")!
        #else
        // This should only be reached when the local xcconfig was not created.
        // The request will fail cleanly and the result UI will identify the
        // on-device keyword fallback instead of exposing a server secret.
        if let url = URL(string: "http://localhost:3000") {
            return url
        }
        fatalError("Invalid fallback API URL")
        #endif
    }()

    var baseURL: URL = APIClient.defaultBaseURL
    var session: URLSession = .shared
    /// Domain A + Domain B together typically take 5–10 s.
    var timeout: TimeInterval = 45

    /// POST /api/v1/sessions/run — interpretation + staged ecosystem outcome.
    func runSession(text: String, source: EventSource, snapshot: SnapshotDTO) async throws -> SessionResponseDTO {
        try await post("api/v1/sessions/run", SessionRequestDTO(inputType: source.rawValue, text: text, snapshot: snapshot))
    }

    private func post<Body: Encodable, Response: Decodable>(_ path: String, _ body: Body) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where Self.unreachableCodes.contains(error.code) {
            throw APIError.unreachable
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.server(message: "Your Figures took too long to answer.", retryable: true)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelopeDTO.self, from: data)
            throw APIError.server(
                message: envelope?.error.message ?? "The server returned \(http.statusCode).",
                retryable: envelope?.error.retryable ?? (http.statusCode >= 500)
            )
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    /// Backend not running / no network — the caller falls back to local logic.
    private static let unreachableCodes: Set<URLError.Code> = [
        .cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .networkConnectionLost, .dnsLookupFailed
    ]
}

enum APIError: LocalizedError, Equatable {
    case unreachable
    case server(message: String, retryable: Bool)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unreachable: "Couldn’t reach your Figures right now."
        case .server(let message, _): message
        case .invalidResponse: "Your Figures answered in a way the app didn’t understand."
        }
    }
}

// MARK: - Wire format (packages/contracts/schemas)

struct SessionRequestDTO: Encodable {
    let inputType: String
    let text: String
    let snapshot: SnapshotDTO
}

/// ecosystem-snapshot.v1
struct SnapshotDTO: Encodable {
    struct Figure: Encodable {
        let id: String
        let level: Int
        let exp: Int
        let energy: Int
    }

    struct Relationship: Encodable {
        let figures: [String]
        let score: Int
    }

    struct SeedMemory: Encodable {
        let id: String
        let title: String
        let ownerFigureId: String
        let state: String
        let objectId: String
        let objectName: String
    }

    let schemaVersion = "ecosystem-snapshot.v1"
    let figures: [Figure]
    let relationships: [Relationship]
    let seedMemories: [SeedMemory]

    init(_ context: EcosystemContext) {
        figures = FigureKind.allCases.compactMap { kind in
            guard let state = context.figures[kind] else { return nil }
            return Figure(id: kind.rawValue,
                          level: min(10, max(1, state.level)),
                          exp: min(100, max(0, state.exp)),
                          energy: Int((min(1, max(0, state.energy)) * 100).rounded()))
        }
        relationships = context.relationships
            .map { Relationship(figures: [$0.key.first.rawValue, $0.key.second.rawValue], score: $0.value) }
            .sorted { $0.figures.joined() < $1.figures.joined() }
        seedMemories = context.memories.compactMap { memory in
            guard let seedID = memory.seedID, let owner = memory.figures.first else { return nil }
            return SeedMemory(id: seedID, title: memory.text, ownerFigureId: owner.rawValue, state: "visible",
                              objectId: seedID.replacingOccurrences(of: "memory_", with: "object_"),
                              objectName: memory.objectName ?? memory.text)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, figures, relationships, seedMemories
    }
}

/// client-session-response.v1
struct SessionResponseDTO: Decodable {
    struct Fallback: Decodable {
        let interpretation: Bool
        let resolution: Bool
    }

    let sessionId: String
    let interpretation: InterpretationDTO
    let resolution: ResolutionDTO
    let fallback: Fallback
}

/// event-interpretation.v1
struct InterpretationDTO: Decodable {
    struct Figure: Decodable {
        let id: String
        let concentration: Double
        let feed: Int
        let evidence: String
        let voiceLine: String
    }

    let summary: String
    let turningPoint: String
    let figures: [Figure]
}

/// ecosystem-resolution.v1 — only what the app shows today. Evolution, raid
/// and explanation feed the Screen 3–5 mock narrative (Sprint 3).
struct ResolutionDTO: Decodable {
    struct PromotedRelationship: Decodable {
        let figures: [String]
        let before: Int
        let delta: Int
        let after: Int
        let reason: String
    }

    /// One per pair of Figures that took part together — empty for a lone
    /// Figure, three for three.
    let promotedRelationships: [PromotedRelationship]
}

private struct ErrorEnvelopeDTO: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
        let retryable: Bool?
    }

    let error: Body
}
