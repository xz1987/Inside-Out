import Foundation
import Combine

@MainActor
final class BalloonLinkController: ObservableObject {
    @Published private(set) var state: BalloonConnectionState = .disconnected
    @Published private(set) var lastStatus: BalloonStatus?
    @Published private(set) var usesMockTransport: Bool
    @Published var mockScenario: BalloonMockScenario = .acknowledge {
        didSet { (link as? MockBalloonLink)?.scenario = mockScenario }
    }

    private struct Pending {
        let command: BalloonCommand
        let packet: Data
        var attempt: Int
    }

    private var link: BalloonLinkProtocol
    private let codec: BalloonPacketCodec
    private let acknowledgementTimeoutNanoseconds: UInt64
    private var pending: Pending?
    private var timeoutTask: Task<Void, Never>?
    private var nextSequenceID: UInt16 = 1

    init(link: BalloonLinkProtocol,
         codec: BalloonPacketCodec = BalloonPacketCodec(),
         acknowledgementTimeoutNanoseconds: UInt64 = 2_000_000_000) {
        self.link = link
        self.codec = codec
        self.acknowledgementTimeoutNanoseconds = acknowledgementTimeoutNanoseconds
        usesMockTransport = link is MockBalloonLink
        if let mock = link as? MockBalloonLink {
            mockScenario = mock.scenario
        }
        bindLink()
    }

    convenience init(mock: Bool) {
        self.init(link: BalloonLinkFactory.make(mock: mock))
    }

    var isReady: Bool { state.isReady }

    func replaceLink(_ replacement: BalloonLinkProtocol) {
        cancelPending()
        link.stop()
        link.onEvent = nil
        link = replacement
        usesMockTransport = replacement is MockBalloonLink
        state = .disconnected
        bindLink()
    }

    func connect() {
        guard pending == nil else { return }
        link.start()
    }

    func disconnect() {
        cancelPending()
        link.stop()
        state = .disconnected
    }

    @discardableResult
    func send(deltas: [UInt8]) -> Bool {
        guard deltas.count == FigureKind.allCases.count else { return false }
        return send(operation: .fill, deltas: deltas)
    }

    @discardableResult
    func stopCurrentPumps() -> Bool {
        send(operation: .stop, deltas: Array(repeating: 0, count: FigureKind.allCases.count))
    }

    @discardableResult
    func testChannel(_ kind: FigureKind, amount: Int) -> Bool {
        var deltas = Array(repeating: UInt8(0), count: FigureKind.allCases.count)
        deltas[kind.channelIndex] = UInt8(clamping: max(1, min(100, amount)))
        return send(operation: .test, deltas: deltas)
    }

    private func send(operation: BalloonCommandOperation, deltas: [UInt8]) -> Bool {
        guard state.isReady, pending == nil else {
            if pending == nil { state = .fault(.notReady) }
            return false
        }
        let sequenceID = nextSequenceID
        nextSequenceID = nextSequenceID == .max ? 1 : nextSequenceID + 1
        let command = BalloonCommand(sequenceID: sequenceID, operation: operation, deltas: deltas)
        let packet = codec.encode(command)
        pending = Pending(command: command, packet: packet, attempt: 1)
        transmitPending()
        return true
    }

    private func bindLink() {
        (link as? MockBalloonLink)?.scenario = mockScenario
        link.onEvent = { [weak self] event in self?.handle(event) }
    }

    private func handle(_ event: BalloonTransportEvent) {
        switch event {
        case .state(.disconnected):
            let wasPending = pending != nil
            cancelPending()
            state = wasPending ? .fault(.disconnected) : .disconnected
        case .state(.scanning): state = .scanning
        case .state(.connecting): state = .connecting
        case .state(.ready):
            guard pending == nil else { return }
            state = .ready
        case .state(.unavailable):
            cancelPending()
            state = .unavailable(.bluetoothUnavailable)
        case .writeFailed:
            cancelPending()
            state = .fault(.writeFailed)
        case .notification(let data):
            handleNotification(data)
        }
    }

    private func transmitPending() {
        guard let pending else { return }
        state = .sending(sequenceID: pending.command.sequenceID)
        link.write(pending.packet)
        guard self.pending != nil else { return }
        state = .awaitingAcknowledgement(sequenceID: pending.command.sequenceID, attempt: pending.attempt)
        scheduleTimeout(for: pending.command.sequenceID)
    }

    private func handleNotification(_ data: Data) {
        guard let status = try? codec.decodeStatus(data), let pending else { return }
        let sequenceID: UInt16
        switch status {
        case .acknowledged(let sequence), .stopped(let sequence): sequenceID = sequence
        case .rejected(let sequence, _): sequenceID = sequence
        }
        guard sequenceID == pending.command.sequenceID else { return }

        cancelPending()
        lastStatus = status
        switch status {
        case .acknowledged, .stopped:
            state = .ready
        case .rejected(let sequence, let code):
            state = .fault(.rejected(sequenceID: sequence, code: code))
        }
    }

    private func scheduleTimeout(for sequenceID: UInt16) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.acknowledgementTimeoutNanoseconds ?? 0)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.handleTimeout(sequenceID: sequenceID)
        }
    }

    private func handleTimeout(sequenceID: UInt16) {
        guard var current = pending, current.command.sequenceID == sequenceID else { return }
        if current.attempt == 1 {
            current.attempt = 2
            pending = current
            transmitPending()
        } else {
            cancelPending()
            state = .fault(.acknowledgementTimedOut(sequenceID: sequenceID))
        }
    }

    private func cancelPending() {
        timeoutTask?.cancel()
        timeoutTask = nil
        pending = nil
    }
}
