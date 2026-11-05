import Foundation
import Combine

@MainActor
final class InstallationSettings: ObservableObject {
    private enum Key {
        static let mode = "installation.mode"
        static let minimum = "installation.minimumChange"
        static let maximum = "installation.maximumChange"
        static let legacySessionMaximum = "installation.maximumSessionTotal"
        static let airInterpretationLimit = "installation.airInterpretationLimit"
        static let waterInterpretationLimit = "installation.waterInterpretationLimit"
        static let concurrent = "installation.allowConcurrent"
        static let autoConnect = "installation.autoConnect"
        static let mock = "installation.mockHardware"
    }

    private let defaults: UserDefaults

    @Published var installationMode: Bool { didSet { defaults.set(installationMode, forKey: Key.mode) } }
    @Published var minimumChange: Int { didSet { defaults.set(minimumChange, forKey: Key.minimum) } }
    @Published var maximumChangePerEvent: Int { didSet { defaults.set(maximumChangePerEvent, forKey: Key.maximum) } }
    @Published var airInterpretationLimit: Int { didSet { defaults.set(airInterpretationLimit, forKey: Key.airInterpretationLimit) } }
    @Published var waterInterpretationLimit: Int { didSet { defaults.set(waterInterpretationLimit, forKey: Key.waterInterpretationLimit) } }
    @Published var allowConcurrentPumps: Bool { didSet { defaults.set(allowConcurrentPumps, forKey: Key.concurrent) } }
    @Published var autoConnect: Bool { didSet { defaults.set(autoConnect, forKey: Key.autoConnect) } }
    @Published var mockHardware: Bool { didSet { defaults.set(mockHardware, forKey: Key.mock) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        installationMode = defaults.object(forKey: Key.mode) as? Bool ?? false
        minimumChange = defaults.object(forKey: Key.minimum) as? Int ?? 5
        maximumChangePerEvent = defaults.object(forKey: Key.maximum) as? Int ?? 25
        let legacyLimit = defaults.object(forKey: Key.legacySessionMaximum) as? Int ?? 100
        airInterpretationLimit = defaults.object(forKey: Key.airInterpretationLimit) as? Int ?? legacyLimit
        waterInterpretationLimit = defaults.object(forKey: Key.waterInterpretationLimit) as? Int ?? legacyLimit
        allowConcurrentPumps = defaults.object(forKey: Key.concurrent) as? Bool ?? true
        autoConnect = defaults.object(forKey: Key.autoConnect) as? Bool ?? true
        mockHardware = defaults.object(forKey: Key.mock) as? Bool ?? false
        normalize()
    }

    var snapshot: InstallationSettingsSnapshot {
        InstallationSettingsSnapshot(
            installationMode: installationMode,
            minimumChange: minimumChange,
            maximumChangePerEvent: maximumChangePerEvent,
            airInterpretationLimit: airInterpretationLimit,
            waterInterpretationLimit: waterInterpretationLimit,
            allowConcurrentPumps: allowConcurrentPumps
        )
    }

    var interpretationReady: Bool { DirectInterpretationConfiguration.current.isConfigured }

    func normalize() {
        minimumChange = min(100, max(1, minimumChange))
        maximumChangePerEvent = min(100, max(minimumChange, maximumChangePerEvent))
        // Board safety ceilings expressed in the same normalized units:
        // air 20,000 / 40 = 500; water 90,000 / 150 = 600.
        airInterpretationLimit = min(500, max(maximumChangePerEvent, airInterpretationLimit))
        waterInterpretationLimit = min(600, max(maximumChangePerEvent, waterInterpretationLimit))
    }

    func restoreDefaults() {
        installationMode = false
        minimumChange = 5
        maximumChangePerEvent = 25
        airInterpretationLimit = 100
        waterInterpretationLimit = 100
        allowConcurrentPumps = true
        autoConnect = true
        mockHardware = false
    }
}
