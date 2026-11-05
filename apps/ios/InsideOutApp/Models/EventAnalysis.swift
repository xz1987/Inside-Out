import Foundation

enum FigureKind: String, CaseIterable, Codable, Identifiable {
    case anger
    case joy
    case anxiety
    case sadness
    case disgust
    case fear
    case embarrassment
    case boredom

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .anger: "flame.fill"
        case .joy: "sun.max.fill"
        case .anxiety: "scribble.variable"
        case .sadness: "cloud.rain.fill"
        case .disgust: "hand.raised.fill"
        case .fear: "eye.trianglebadge.exclamationmark.fill"
        case .embarrassment: "face.dashed.fill"
        case .boredom: "ellipsis"
        }
    }

    /// Stable model/app/BLE channel order. Never derive this from localized UI copy.
    var channelIndex: Int {
        Self.allCases.firstIndex(of: self)!
    }

    var medium: InstallationMedium {
        switch self {
        case .anger, .anxiety, .embarrassment, .boredom: .air
        case .joy, .sadness, .disgust, .fear: .water
        }
    }
}

enum InstallationMedium: String, Codable {
    case air, water
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
    /// One per pair of Figures that took part together (none for a lone Figure).
    let promotedRelationships: [RelationshipPromotion]
    let interpretationMode: String
    /// true when keyword matching produced this instead of the language model
    /// (backend unreachable, or backend has no API key).
    var isKeywordGuess = false
}

