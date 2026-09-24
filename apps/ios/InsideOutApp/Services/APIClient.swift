import Foundation

/// Talks to apps/api. No AI keys live in the app — only the backend URL.
struct APIClient {
    /// Override with the `API_BASE_URL` environment variable in the Xcode
    /// scheme (e.g. a LAN IP or tunnel when running on a physical iPhone).
    static let defaultBaseURL: URL = {
        if let value = ProcessInfo.processInfo.environment["API_BASE_URL"], let url = URL(string: value) {
            return url
        }
        return URL(string: "http://localhost:3000")!
    }()

    var baseURL: URL = APIClient.defaultBaseURL
    var session: URLSession = .shared
    var timeout: TimeInterval = 30

    func interpret(text: String, source: EventSource) async throws -> InterpretResponseDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/events/interpret"), timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(InterpretRequestDTO(inputType: source.rawValue, text: text))

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
            return try JSONDecoder().decode(InterpretResponseDTO.self, from: data)
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

// MARK: - Wire format (packages/contracts/schemas/event-interpretation.v1)

struct InterpretRequestDTO: Encodable {
    let inputType: String
    let text: String
}

struct InterpretResponseDTO: Decodable {
    let interpretation: InterpretationDTO
    let fallback: Bool
    let promptVersion: String
}

struct InterpretationDTO: Decodable {
    struct Figure: Decodable {
        let id: String
        let concentration: Double
        let feed: Int
        let evidence: String
        let voiceLine: String
    }

    struct RelationshipCue: Decodable {
        let figures: [String]
        let reason: String
    }

    let summary: String
    let turningPoint: String
    let figures: [Figure]
    let relationshipCues: [RelationshipCue]
}

private struct ErrorEnvelopeDTO: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
        let retryable: Bool?
    }

    let error: Body
}
