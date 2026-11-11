import SwiftUI

struct InstallationSettingsView: View {
    @ObservedObject var settings: InstallationSettings
    let totals: InstallationSessionTotals
    @ObservedObject var link: BalloonLinkController
    let onNewSession: () -> Void
    let onConnectionSettingsChanged: () -> Void
    let onMockHardwareChanged: (Bool) -> Void
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onStop: () -> Void
    let onPrefillAir: () -> Void
    let onTestChannel: (FigureKind) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Installation") {
                    Toggle("Installation Mode", isOn: $settings.installationMode)
                    LabeledContent("BLE") {
                        Label(link.state.label, systemImage: statusSymbol)
                            .foregroundStyle(statusColor)
                    }
                    Toggle("Auto Connect in foreground", isOn: $settings.autoConnect)
                    Toggle("Allow concurrent pumps", isOn: $settings.allowConcurrentPumps)
                    Button(link.state.isReady ? "Disconnect" : "Connect") {
                        link.state.isReady ? onDisconnect() : onConnect()
                    }
                    .disabled(!settings.installationMode)
                }

                Section("Pre-fill air") {
                    Stepper("Amount per air balloon: \(settings.airPrefillAmount)",
                            value: $settings.airPrefillAmount, in: 5...100, step: 5)
                    Button("Pre-fill all air balloons · +\(settings.airPrefillAmount)", action: onPrefillAir)
                        .disabled(!link.state.isReady || !settings.installationMode)
                    Text("Runs the 4 air pumps one after another (about \(String(format: "%.1f", Double(settings.airPrefillAmount) * 0.04)) s each, \(String(format: "%.1f", Double(settings.airPrefillAmount) * 0.16)) s in total). Water is not touched. Counts toward Session totals; tap again for more.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Interpreted fill · normalized units") {
                    Stepper("Strength ×\(settings.feedGain, specifier: "%.1f")", value: $settings.feedGain, in: 1...5, step: 0.5)
                    Stepper("Air minimum change: \(settings.airMinimumChange)", value: airMinimumBinding, in: 1...100)
                    Stepper("Water minimum change: \(settings.waterMinimumChange)", value: waterMinimumBinding, in: 1...100)
                    Stepper("Transcription maximum per event: \(settings.maximumChangePerEvent)", value: maximumBinding, in: 1...100)
                    Stepper("Air total limit: \(settings.airInterpretationLimit)", value: airLimitBinding, in: 1...500)
                    Stepper("Water total limit: \(settings.waterInterpretationLimit)", value: waterLimitBinding, in: 1...600)
                    Text("Minimums, maximum per event, and totals apply only to interpreted voice/message events. Air and water use separate minimums.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Direct Interpretation") {
                    LabeledContent("Configuration") {
                        Label(settings.interpretationReady ? "Ready" : "Key not configured",
                              systemImage: settings.interpretationReady ? "checkmark.seal.fill" : "key.slash")
                            .foregroundStyle(settings.interpretationReady ? .green : .orange)
                    }
                    Text("The key value is never displayed. Configure it only in gitignored Local.xcconfig.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Session totals") {
                    ForEach(FigureKind.allCases) { kind in
                        LabeledContent {
                            Text("\(totals[kind]) / \(interpretationLimit(for: kind))").monospacedDigit()
                        } label: {
                            Label(kind.displayName, systemImage: kind.symbolName)
                                .foregroundStyle(kind.palette.dark)
                        }
                    }
                    Button("Start New Session", action: onNewSession)
                }

                Section("Hardware controls") {
                    Button("Stop Current Pumps", role: .destructive, action: onStop)
                        .disabled(!link.state.isReady)
                    ForEach(FigureKind.allCases) { kind in
                        Button("Test \(kind.displayName) · +\(settings.minimumChange(for: kind))") {
                            onTestChannel(kind)
                        }
                        .disabled(!link.state.isReady)
                    }
                    Text("Commands are enabled only while the link is ready. Missed commands are never queued for reconnect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Manual Test has no interpreted-event maximum and no cumulative total limit. Each tap uses that channel medium's minimum as its safe pulse size.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                Section("Development") {
                    Toggle("Mock Hardware", isOn: $settings.mockHardware)
                    if link.usesMockTransport {
                        Picker("Mock response", selection: $link.mockScenario) {
                            ForEach(BalloonMockScenario.allCases) { scenario in
                                Text(scenario.rawValue).tag(scenario)
                            }
                        }
                    }
                    Text(link.usesMockTransport
                         ? "Simulator and Mock Hardware use deterministic responses for Set 5 testing."
                         : "A physical iPhone scans for one installation using the configured service UUID.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                #endif

                Section {
                    Button("Restore defaults", role: .destructive) { settings.restoreDefaults() }
                }
            }
            .navigationTitle("Installation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settings.normalize()
                        dismiss()
                    }
                }
            }
            .onChange(of: settings.installationMode) { _, _ in onConnectionSettingsChanged() }
            .onChange(of: settings.autoConnect) { _, _ in onConnectionSettingsChanged() }
            .onChange(of: settings.mockHardware) { _, enabled in onMockHardwareChanged(enabled) }
        }
    }

    private var statusSymbol: String {
        switch link.state {
        case .ready: "antenna.radiowaves.left.and.right"
        case .scanning, .connecting, .sending, .awaitingAcknowledgement: "dot.radiowaves.left.and.right"
        case .fault, .unavailable: "exclamationmark.triangle.fill"
        case .disconnected: "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var statusColor: Color {
        switch link.state {
        case .ready: .green
        case .scanning, .connecting, .sending, .awaitingAcknowledgement: .blue
        case .fault, .unavailable: .orange
        case .disconnected: .secondary
        }
    }

    private var airMinimumBinding: Binding<Int> {
        Binding(get: { settings.airMinimumChange }, set: {
            settings.airMinimumChange = $0
            settings.normalize()
        })
    }

    private var waterMinimumBinding: Binding<Int> {
        Binding(get: { settings.waterMinimumChange }, set: {
            settings.waterMinimumChange = $0
            settings.normalize()
        })
    }

    private var maximumBinding: Binding<Int> {
        Binding(get: { settings.maximumChangePerEvent }, set: {
            settings.maximumChangePerEvent = $0
            settings.normalize()
        })
    }

    private var airLimitBinding: Binding<Int> {
        Binding(get: { settings.airInterpretationLimit }, set: {
            settings.airInterpretationLimit = $0
            settings.normalize()
        })
    }

    private var waterLimitBinding: Binding<Int> {
        Binding(get: { settings.waterInterpretationLimit }, set: {
            settings.waterInterpretationLimit = $0
            settings.normalize()
        })
    }

    private func interpretationLimit(for kind: FigureKind) -> Int {
        kind.medium == .air ? settings.airInterpretationLimit : settings.waterInterpretationLimit
    }
}
