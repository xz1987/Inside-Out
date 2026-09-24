import Foundation

enum FigureKind: String, CaseIterable, Codable, Identifiable {
    case sadness
    case joy
    case anger
    case fear

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .sadness: "cloud.rain.fill"
        case .joy: "sun.max.fill"
        case .anger: "flame.fill"
        case .fear: "eye.trianglebadge.exclamationmark.fill"
        }
    }
}

struct FigureFeed: Identifiable, Codable, Equatable {
    let figure: FigureKind
    let feedAmount: Int
    let concentration: Double
    let evidence: String
    /// A short first-person line the Figure "says" on the result screen.
    let voiceLine: String

    var id: FigureKind { figure }
}

struct RelationshipPromotion: Codable, Equatable {
    let firstFigure: FigureKind
    let secondFigure: FigureKind
    let points: Int
    let reason: String
    /// Score before this event; nil if unknown.
    var before: Int?

    var after: Int? { before.map { $0 + points } }
    var pair: FigurePair { FigurePair(firstFigure, secondFigure) }
}

enum EventSource: String, Codable {
    case voice, message
}

struct EventAnalysis: Codable, Equatable {
    let summary: String
    /// Most-fed first.
    let feeds: [FigureFeed]
    /// nil when only one Figure took part.
    let promotedRelationship: RelationshipPromotion?
    let interpretationMode: String
    /// true when keyword matching produced this instead of the language model
    /// (backend unreachable, or backend has no API key).
    var isKeywordGuess = false
}

