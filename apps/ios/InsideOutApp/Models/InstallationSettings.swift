import Foundation
import Combine

@MainActor
final class InstallationSettings: ObservableObject {
    private enum Key {
        static let mode = "installation.mode"
        // ".v2": larger defaults (2026-11-10) must replace values saved by earlier builds.
        static let airMinimum = "installation.airMinimumChange.v2"
        static let waterMinimum = "installation.waterMinimumChange.v2"
        static let maximum = "installation.maximumChange.v2"
        static let gain = "installation.feedGain"
        static let airPrefill = "installation.airPrefillAmount"
        static let airInterpretationLimit = "installation.airInterpretationLimit.v2"
        static let waterInterpretationLimit = "installation.waterInterpretationLimit.v2"
        static let concurrent = "installation.allowConcurrent"
        static let autoConnect = "installation.autoConnect"
        static let mock = "installation.mockHardware"
    }

    private let defaults: UserDefaults

    // Normalized units: air pumps run 40 ms per unit, water pumps 150 ms (see the sketch).
    // Air 25 ≈ 1 s, water 10 ≈ 1.5 s. Max 80 per event ≈ air 3.2 s / water 12 s.
    // Session limits equal the board's own cumulative caps (air 20 s, water 90 s).
    static let defaultAirMinimum = 25
    static let defaultWaterMinimum = 10
    static let defaultMaximumPerEvent = 80
    static let defaultFeedGain = 3.0
    /// One "Pre-fill air" tap: 50 units ≈ 2 s on every air pump. 100 is the protocol's per-command maximum.
    static let defaultAirPrefill = 50
    static let defaultAirLimit = 500
    static let defaultWaterLimit = 600

    @Published var installationMode: Bool { didSet { defaults.set(installationMode, forKey: Key.mode) } }
    @Published var airMinimumChange: Int { didSet { defaults.set(airMinimumChange, forKey: Key.airMinimum) } }
    @Published var waterMinimumChange: Int { didSet { defaults.set(waterMinimumChange, forKey: Key.waterMinimum) } }
    @Published var maximumChangePerEvent: Int { didSet { defaults.set(maximumChangePerEvent, forKey: Key.maximum) } }
    @Published var feedGain: Double { didSet { defaults.set(feedGain, forKey: Key.gain) } }
    @Published var airPrefillAmount: Int { didSet { defaults.set(airPrefillAmount, forKey: Key.airPrefill) } }
    @Published var airInterpretationLimit: Int { didSet { defaults.set(airInterpretationLimit, forKey: Key.airInterpretationLimit) } }
    @Published var waterInterpretationLimit: Int { didSet { defaults.set(waterInterpretationLimit, forKey: Key.waterInterpretationLimit) } }
    @Published var allowConcurrentPumps: Bool { didSet { defaults.set(allowConcurrentPumps, forKey: Key.concurrent) } }
    @Published var autoConnect: Bool { didSet { defaults.set(autoConnect, forKey: Key.autoConnect) } }
    @Published var mockHardware: Bool { didSet { defaults.set(mockHardware, forKey: Key.mock) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        installationMode = defaults.object(forKey: Key.mode) as? Bool ?? false
        airMinimumChange = defaults.object(forKey: Key.airMinimum) as? Int ?? Self.defaultAirMinimum
        waterMinimumChange = defaults.object(forKey: Key.waterMinimum) as? Int ?? Self.defaultWaterMinimum
        maximumChangePerEvent = defaults.object(forKey: Key.maximum) as? Int ?? Self.defaultMaximumPerEvent
        feedGain = defaults.object(forKey: Key.gain) as? Double ?? Self.defaultFeedGain
        airPrefillAmount = defaults.object(forKey: Key.airPrefill) as? Int ?? Self.defaultAirPrefill
        airInterpretationLimit = defaults.object(forKey: Key.airInterpretationLimit) as? Int ?? Self.defaultAirLimit
        waterInterpretationLimit = defaults.object(forKey: Key.waterInterpretationLimit) as? Int ?? Self.defaultWaterLimit
        allowConcurrentPumps = defaults.object(forKey: Key.concurrent) as? Bool ?? true
        autoConnect = defaults.object(forKey: Key.autoConnect) as? Bool ?? true
        mockHardware = defaults.object(forKey: Key.mock) as? Bool ?? false
        normalize()
    }

    var snapshot: InstallationSettingsSnapshot {
        InstallationSettingsSnapshot(
            installationMode: installationMode,
            airMinimumChange: airMinimumChange,
            waterMinimumChange: waterMinimumChange,
            maximumChangePerEvent: maximumChangePerEvent,
            airInterpretationLimit: airInterpretationLimit,
            waterInterpretationLimit: waterInterpretationLimit,
            allowConcurrentPumps: allowConcurrentPumps,
            feedGain: feedGain
        )
    }

    var interpretationReady: Bool { DirectInterpretationConfiguration.current.isConfigured }

    func minimumChange(for kind: FigureKind) -> Int {
        kind.medium == .air ? airMinimumChange : waterMinimumChange
    }

    func normalize() {
        airMinimumChange = min(100, max(1, airMinimumChange))
        waterMinimumChange = min(100, max(1, waterMinimumChange))
        feedGain = min(5, max(1, feedGain))
        airPrefillAmount = min(100, max(1, airPrefillAmount))
        maximumChangePerEvent = min(100, max(max(airMinimumChange, waterMinimumChange), maximumChangePerEvent))
        // Board safety ceilings expressed in the same normalized units:
        // air 20,000 / 40 = 500; water 90,000 / 150 = 600.
        airInterpretationLimit = min(500, max(maximumChangePerEvent, airInterpretationLimit))
        waterInterpretationLimit = min(600, max(maximumChangePerEvent, waterInterpretationLimit))
    }

    func restoreDefaults() {
        installationMode = false
        airMinimumChange = Self.defaultAirMinimum
        waterMinimumChange = Self.defaultWaterMinimum
        maximumChangePerEvent = Self.defaultMaximumPerEvent
        feedGain = Self.defaultFeedGain
        airPrefillAmount = Self.defaultAirPrefill
        airInterpretationLimit = Self.defaultAirLimit
        waterInterpretationLimit = Self.defaultWaterLimit
        allowConcurrentPumps = true
        autoConnect = true
        mockHardware = false
    }
}
