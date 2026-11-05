import Foundation

enum BalloonConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case ready
    case sending(sequenceID: UInt16)
    case awaitingAcknowledgement(sequenceID: UInt16, attempt: Int)
    case fault(BalloonLinkError)
    case unavailable(BalloonLinkError)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .scanning: "Scanning"
        case .connecting: "Connecting"
        case .ready: "Ready"
        case .sending: "Sending"
        case .awaitingAcknowledgement(_, let attempt): attempt == 1 ? "Waiting for ACK" : "Retrying · waiting for ACK"
        case .fault(let error): "Fault · \(error.shortDescription)"
        case .unavailable(let error): "Unavailable · \(error.shortDescription)"
        }
    }
}

enum BalloonLinkError: Error, Equatable, LocalizedError {
    case bluetoothUnavailable
    case notReady
    case invalidPacket
    case writeFailed
    case acknowledgementTimedOut(sequenceID: UInt16)
    case rejected(sequenceID: UInt16, code: UInt8)
    case disconnected

    var shortDescription: String {
        switch self {
        case .bluetoothUnavailable: "Bluetooth unavailable"
        case .notReady: "Not ready"
        case .invalidPacket: "Invalid packet"
        case .writeFailed: "Write failed"
        case .acknowledgementTimedOut: "ACK timeout"
        case .rejected: "Command rejected"
        case .disconnected: "Disconnected"
        }
    }

    var errorDescription: String? { shortDescription }
}

enum BalloonCommandOperation: UInt8, Equatable {
    case fill = 0x01
    case stop = 0x02
    /// Manual setup pulse. It is safety-clamped per command by the board but
    /// does not consume the interpretation/runtime total.
    case test = 0x03
}

struct BalloonCommand: Equatable {
    let sequenceID: UInt16
    let operation: BalloonCommandOperation
    /// Stable app channel order; always eight normalized values.
    let deltas: [UInt8]

    init(sequenceID: UInt16, operation: BalloonCommandOperation, deltas: [UInt8]) {
        precondition(deltas.count == FigureKind.allCases.count)
        self.sequenceID = sequenceID
        self.operation = operation
        self.deltas = deltas
    }
}

enum BalloonStatus: Equatable {
    case acknowledged(sequenceID: UInt16)
    case rejected(sequenceID: UInt16, code: UInt8)
    case stopped(sequenceID: UInt16)
}

/// Values shared by the iOS codec and the Set 6 Arduino sketch.
/// Change them only in a coordinated protocol revision on both sides.
struct BalloonBLEConfiguration: Equatable {
    let serviceUUID: String
    let commandCharacteristicUUID: String
    let statusCharacteristicUUID: String

    static let installation = BalloonBLEConfiguration(
        serviceUUID: "FEE7D000-6A7A-4F3D-9E31-1A51D8E10000",
        commandCharacteristicUUID: "FEE7D001-6A7A-4F3D-9E31-1A51D8E10000",
        statusCharacteristicUUID: "FEE7D002-6A7A-4F3D-9E31-1A51D8E10000"
    )
}

struct BalloonPacketCodec {
    static let protocolVersion: UInt8 = 1
    static let commandLength = 13
    static let statusLength = 6

    func encode(_ command: BalloonCommand) -> Data {
        var bytes: [UInt8] = [
            Self.protocolVersion,
            command.operation.rawValue,
            UInt8(command.sequenceID >> 8),
            UInt8(command.sequenceID & 0xFF)
        ]
        bytes.append(contentsOf: command.deltas)
        bytes.append(checksum(bytes))
        return Data(bytes)
    }

    func decodeCommand(_ data: Data) throws -> BalloonCommand {
        let bytes = [UInt8](data)
        guard bytes.count == Self.commandLength,
              bytes[0] == Self.protocolVersion,
              checksum(Array(bytes.dropLast())) == bytes.last,
              let operation = BalloonCommandOperation(rawValue: bytes[1]) else {
            throw BalloonLinkError.invalidPacket
        }
        let sequenceID = UInt16(bytes[2]) << 8 | UInt16(bytes[3])
        return BalloonCommand(sequenceID: sequenceID, operation: operation,
                              deltas: Array(bytes[4..<12]))
    }

    func encode(_ status: BalloonStatus) -> Data {
        let code: UInt8
        let sequenceID: UInt16
        let detail: UInt8
        switch status {
        case .acknowledged(let sequence):
            code = 0x00; sequenceID = sequence; detail = 0
        case .rejected(let sequence, let reason):
            code = 0x01; sequenceID = sequence; detail = reason
        case .stopped(let sequence):
            code = 0x02; sequenceID = sequence; detail = 0
        }
        var bytes = [Self.protocolVersion, code, UInt8(sequenceID >> 8), UInt8(sequenceID & 0xFF), detail]
        bytes.append(checksum(bytes))
        return Data(bytes)
    }

    func decodeStatus(_ data: Data) throws -> BalloonStatus {
        let bytes = [UInt8](data)
        guard bytes.count == Self.statusLength,
              bytes[0] == Self.protocolVersion,
              checksum(Array(bytes.dropLast())) == bytes.last else {
            throw BalloonLinkError.invalidPacket
        }
        let sequenceID = UInt16(bytes[2]) << 8 | UInt16(bytes[3])
        switch bytes[1] {
        case 0x00: return .acknowledged(sequenceID: sequenceID)
        case 0x01: return .rejected(sequenceID: sequenceID, code: bytes[4])
        case 0x02: return .stopped(sequenceID: sequenceID)
        default: throw BalloonLinkError.invalidPacket
        }
    }

    private func checksum(_ bytes: [UInt8]) -> UInt8 {
        bytes.reduce(0, ^)
    }
}

enum BalloonMockScenario: String, CaseIterable, Identifiable {
    case acknowledge = "Acknowledge"
    case timeout = "Timeout"
    case reject = "Reject"
    case disconnect = "Disconnect"

    var id: String { rawValue }
}
