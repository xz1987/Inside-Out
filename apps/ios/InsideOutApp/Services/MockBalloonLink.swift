import Foundation

@MainActor
final class MockBalloonLink: BalloonLinkProtocol {
    var onEvent: ((BalloonTransportEvent) -> Void)?
    var scenario: BalloonMockScenario
    private(set) var writeCount = 0
    private(set) var writtenPackets: [Data] = []
    private let codec = BalloonPacketCodec()
    private var running = false

    init(scenario: BalloonMockScenario = .acknowledge) {
        self.scenario = scenario
    }

    func start() {
        running = true
        onEvent?(.state(.scanning))
        onEvent?(.state(.connecting))
        onEvent?(.state(.ready))
    }

    func stop() {
        running = false
        onEvent?(.state(.disconnected))
    }

    func write(_ data: Data) {
        guard running else {
            onEvent?(.writeFailed)
            return
        }
        writeCount += 1
        writtenPackets.append(data)
        guard let command = try? codec.decodeCommand(data) else {
            onEvent?(.writeFailed)
            return
        }

        switch scenario {
        case .acknowledge:
            let status: BalloonStatus = command.operation == .stop
                ? .stopped(sequenceID: command.sequenceID)
                : .acknowledged(sequenceID: command.sequenceID)
            onEvent?(.notification(codec.encode(status)))
        case .timeout:
            break
        case .reject:
            onEvent?(.notification(codec.encode(.rejected(sequenceID: command.sequenceID, code: 1))))
        case .disconnect:
            running = false
            onEvent?(.state(.disconnected))
        }
    }
}
