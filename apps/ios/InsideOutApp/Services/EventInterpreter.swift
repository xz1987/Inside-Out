import Foundation

protocol EventInterpreting {
    func interpret(eventText: String) async throws -> EventAnalysis
}

enum EventInterpreterError: LocalizedError {
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Please describe one daily event first."
        }
    }
}

/// Local MVP fallback. It keeps the first two screens usable before server keys
/// are configured. The result is explicitly labeled as local prototype logic.
struct LocalEventInterpreter: EventInterpreting {
    private let keywords: [FigureKind: [String]] = [
        .anger: [
            "angry", "anger", "annoyed", "unfair", "interrupt", "ignored",
            "cut me off", "yelled", "rude",
            "生气", "愤怒", "不公平", "打断", "被忽视", "烦", "吼", "别车"
        ],
        .fear: [
            "afraid", "fear", "worried", "nervous", "uncertain", "anxious",
            "scared", "shaky", "happen again",
            "害怕", "担心", "紧张", "不确定", "焦虑", "后怕", "发抖"
        ],
        .sadness: [
            "sad", "hurt", "lost", "lonely", "cry", "miss",
            "难过", "受伤", "失落", "孤独", "哭", "想念"
        ],
        .joy: [
            "happy", "joy", "excited", "proud", "great", "celebrate",
            "开心", "高兴", "兴奋", "自豪", "庆祝", "很好"
        ]
    ]

    /// Number of keyword hits per Figure. Also drives the live Figure
    /// reactions while the user is still talking.
    func signalCounts(in text: String) -> [FigureKind: Int] {
        let normalized = text.lowercased()
        var matches: [FigureKind: Int] = [:]
        for figure in FigureKind.allCases {
            matches[figure] = keywords[figure, default: []].reduce(into: 0) { total, keyword in
                if normalized.contains(keyword) {
                    total += 1
                }
            }
        }
        return matches
    }

    func interpret(eventText: String) async throws -> EventAnalysis {
        let trimmed = eventText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EventInterpreterError.emptyInput
        }

        var matches = signalCounts(in: trimmed)

        let hasSignal = matches.values.contains { $0 > 0 }
        if !hasSignal {
            // A neutral fallback still gives the result screen two figures so
            // the relationship-promotion concept can be tested.
            matches[.joy] = 1
            matches[.sadness] = 1
        }

        let ranked = FigureKind.allCases.sorted {
            let left = matches[$0, default: 0]
            let right = matches[$1, default: 0]
            if left == right {
                return $0.rawValue < $1.rawValue
            }
            return left > right
        }

        let selected = Array(ranked.prefix(2))
        let rawWeights = selected.map { max(1, matches[$0, default: 0]) }
        let totalWeight = max(1, rawWeights.reduce(0, +))

        let feeds = zip(selected, rawWeights).map { figure, weight in
            FigureFeed(
                figure: figure,
                feedAmount: 6 + (weight * 6),
                concentration: Double(weight) / Double(totalWeight),
                evidence: evidence(for: figure),
                voiceLine: voiceLine(for: figure)
            )
        }

        let summaryLimit = 150
        let summary = trimmed.count > summaryLimit
            ? String(trimmed.prefix(summaryLimit)) + "…"
            : trimmed

        return EventAnalysis(
            summary: summary,
            feeds: feeds,
            promotedRelationship: RelationshipPromotion(
                firstFigure: selected[0],
                secondFigure: selected[1],
                points: 8,
                reason: "They were both present in the same remembered event."
            ),
            interpretationMode: "Local prototype fallback"
        )
    }

    private func voiceLine(for figure: FigureKind) -> String {
        switch figure {
        case .anger:
            "That crossed a line. It wasn’t fair."
        case .fear:
            "I’m worried it’ll happen again."
        case .sadness:
            "That one hurt. I’ll hold onto it."
        case .joy:
            "There’s something good here to keep."
        }
    }

    private func evidence(for figure: FigureKind) -> String {
        switch figure {
        case .anger:
            "Anger noticed a boundary, interruption, or sense of unfairness."
        case .fear:
            "Fear noticed uncertainty, risk, or concern about what happens next."
        case .sadness:
            "Sadness noticed hurt, distance, or something that felt lost."
        case .joy:
            "Joy noticed connection, relief, progress, or something worth keeping."
        }
    }
}

