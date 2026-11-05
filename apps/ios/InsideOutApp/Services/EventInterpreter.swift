import Foundation

protocol EventInterpreting {
    /// `context` is the current inner-world state; the backend needs it to
    /// stage the ecosystem outcome, the local fallback ignores it.
    func interpret(eventText: String, source: EventSource, context: EcosystemContext) async throws -> EventAnalysis
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
            "afraid", "fear", "scared", "unsafe", "danger", "threat", "panic", "shaky",
            "害怕", "恐惧", "危险", "不安全", "惊吓", "发抖"
        ],
        .anxiety: [
            "anxious", "anxiety", "worried", "nervous", "uncertain", "overthinking", "happen again",
            "焦虑", "担心", "紧张", "不确定", "想太多", "后怕"
        ],
        .sadness: [
            "sad", "hurt", "lost", "lonely", "cry", "miss",
            "难过", "受伤", "失落", "孤独", "哭", "想念"
        ],
        .joy: [
            "happy", "joy", "excited", "proud", "great", "celebrate",
            "开心", "高兴", "兴奋", "自豪", "庆祝", "很好"
        ],
        .disgust: ["disgust", "disgusted", "gross", "nasty", "repulsed", "恶心", "反感", "嫌弃", "膈应"],
        .embarrassment: ["embarrassed", "awkward", "humiliated", "ashamed", "cringe", "尴尬", "丢脸", "羞耻", "难为情"],
        .boredom: ["bored", "boring", "dull", "tedious", "nothing to do", "无聊", "没意思", "乏味", "等太久"]
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

    func interpret(eventText: String, source: EventSource, context: EcosystemContext) async throws -> EventAnalysis {
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
            promotedRelationships: [RelationshipPromotion(
                firstFigure: selected[0],
                secondFigure: selected[1],
                points: 8,
                reason: "They were both present in the same remembered event."
            )],
            interpretationMode: "Local prototype fallback",
            isKeywordGuess: true
        )
    }

    private func voiceLine(for figure: FigureKind) -> String {
        switch figure {
        case .anger:
            "That crossed a line. It wasn’t fair."
        case .fear:
            "That felt dangerous. I want us somewhere safe."
        case .anxiety:
            "My mind keeps circling what might happen next."
        case .sadness:
            "That one hurt. I’ll hold onto it."
        case .joy:
            "There’s something good here to keep."
        case .disgust:
            "I want some distance from that."
        case .embarrassment:
            "I wish I could hide for a minute."
        case .boredom:
            "Nothing here is holding my attention."
        }
    }

    private func evidence(for figure: FigureKind) -> String {
        switch figure {
        case .anger:
            "Anger noticed a boundary, interruption, or sense of unfairness."
        case .fear:
            "Fear noticed immediate danger, shock, or a need to escape."
        case .anxiety:
            "Anxiety noticed anticipation, uncertainty, or a thought that kept looping."
        case .sadness:
            "Sadness noticed hurt, distance, or something that felt lost."
        case .joy:
            "Joy noticed connection, relief, progress, or something worth keeping."
        case .disgust:
            "Disgust noticed aversion, rejection, or a visceral boundary."
        case .embarrassment:
            "Embarrassment noticed exposure, awkwardness, or a wish to disappear."
        case .boredom:
            "Boredom noticed repetition, waiting, or too little stimulation."
        }
    }
}

