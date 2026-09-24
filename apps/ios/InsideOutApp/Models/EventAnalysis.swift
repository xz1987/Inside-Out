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
}

struct EventAnalysis: Codable, Equatable {
    let summary: String
    let feeds: [FigureFeed]
    let promotedRelationship: RelationshipPromotion
    let interpretationMode: String
}

