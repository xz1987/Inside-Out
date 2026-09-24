import Foundation

/// In-memory progress for one Figure. Not persisted yet (SwiftData is a
/// later sprint), so every launch starts from `seed`.
struct FigureState: Equatable {
    let kind: FigureKind
    var level: Int
    /// Progress toward the next level, 0–100.
    var exp: Int
    /// Current energy, 0–1.
    var energy: Double
    /// Last seven days of energy (0–100) for the sparkline.
    var trend: [Double]
    var headline: String

    mutating func feed(_ amount: Int) {
        exp += amount
        while exp >= 100 {
            level += 1
            exp -= 100
        }
        energy = min(1, energy + Double(amount) / 200)
        if !trend.isEmpty {
            trend[trend.count - 1] = energy * 100
        }
    }

    static let seed: [FigureKind: FigureState] = [
        .joy: FigureState(kind: .joy, level: 5, exp: 64, energy: 0.58,
                          trend: [70, 64, 66, 55, 58, 50, 58],
                          headline: "Joy’s been a little quieter"),
        .sadness: FigureState(kind: .sadness, level: 2, exp: 40, energy: 0.32,
                              trend: [40, 38, 45, 30, 28, 30, 32],
                              headline: "Sadness is resting"),
        .anger: FigureState(kind: .anger, level: 3, exp: 52, energy: 0.70,
                            trend: [20, 24, 22, 35, 40, 52, 70],
                            headline: "Anger has been growing this week"),
        .fear: FigureState(kind: .fear, level: 2, exp: 30, energy: 0.46,
                           trend: [20, 22, 30, 28, 34, 38, 46],
                           headline: "Fear is sticking close to Anger")
    ]
}

struct MemoryEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let text: String
    let figures: [FigureKind]
    var isNew = false

    static func seed(relativeTo now: Date = .now) -> [MemoryEntry] {
        let day = { (offset: Int) in
            Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
        }
        return [
            MemoryEntry(date: day(1), text: "Mia brought you coffee without asking", figures: [.joy]),
            MemoryEntry(date: day(2), text: "Missed grandma’s call, again", figures: [.sadness, .fear]),
            MemoryEntry(date: day(3), text: "Finished the long hike right at sunset", figures: [.joy, .sadness])
        ]
    }
}
