import Foundation

struct InstallationSettingsSnapshot: Equatable {
    var installationMode: Bool
    var airMinimumChange: Int
    var waterMinimumChange: Int
    var maximumChangePerEvent: Int
    var airInterpretationLimit: Int
    var waterInterpretationLimit: Int
    var allowConcurrentPumps: Bool
    /// Multiplies the interpreted Feed before clamping, so the same emotion
    /// moves the balloons more. 1 keeps Feed as-is.
    var feedGain: Double = 1

    func interpretationLimit(for kind: FigureKind) -> Int {
        kind.medium == .air ? airInterpretationLimit : waterInterpretationLimit
    }

    func minimumChange(for kind: FigureKind) -> Int {
        kind.medium == .air ? airMinimumChange : waterMinimumChange
    }
}
struct PumpDeltaCommand: Equatable, Identifiable {
    let id: UUID
    /// Stable app channel order from `FigureKind.allCases`; always eight values.
    let deltas: [UInt8]

    init(id: UUID = UUID(), deltas: [UInt8]) {
        precondition(deltas.count == FigureKind.allCases.count)
        self.id = id
        self.deltas = deltas
    }

    subscript(_ kind: FigureKind) -> UInt8 { deltas[kind.channelIndex] }
}

struct InstallationSessionTotals: Equatable {
    private(set) var values: [Int] = Array(repeating: 0, count: FigureKind.allCases.count)

    subscript(_ kind: FigureKind) -> Int { values[kind.channelIndex] }

    mutating func apply(_ command: PumpDeltaCommand) {
        for index in values.indices {
            values[index] += Int(command.deltas[index])
        }
    }

    mutating func reset() {
        values = Array(repeating: 0, count: FigureKind.allCases.count)
    }
}

/// Pure conversion from interpreted Feed to a fill-only, normalized eight-channel command.
struct ActuationPolicy {
    func command(
        feeds: [FigureFeed],
        settings: InstallationSettingsSnapshot,
        sessionTotals: InstallationSessionTotals,
        hardwareReady: Bool
    ) -> PumpDeltaCommand? {
        guard settings.installationMode, hardwareReady else { return nil }
        let selected = settings.allowConcurrentPumps ? Array(feeds.prefix(4)) : Array(feeds.prefix(1))

        var deltas = Array(repeating: UInt8(0), count: FigureKind.allCases.count)
        for feed in selected where feed.feedAmount > 0 {
            let minimum = max(1, min(100, settings.minimumChange(for: feed.figure)))
            // This ceiling belongs only to interpreted event commands. Manual
            // hardware tests use the separate `.test` BLE operation.
            let maximum = max(minimum, min(100, settings.maximumChangePerEvent))
            let sessionMaximum = max(1, settings.interpretationLimit(for: feed.figure))
            let remaining = max(0, sessionMaximum - sessionTotals[feed.figure])
            guard remaining > 0 else { continue }
            let scaled = Int((Double(feed.feedAmount) * max(0.1, settings.feedGain)).rounded())
            let clamped = min(remaining, min(maximum, max(minimum, scaled)))
            deltas[feed.figure.channelIndex] = UInt8(clamping: clamped)
        }
        return deltas.contains(where: { $0 > 0 }) ? PumpDeltaCommand(deltas: deltas) : nil
    }
}
