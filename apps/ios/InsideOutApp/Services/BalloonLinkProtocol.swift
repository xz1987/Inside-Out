import Foundation

enum BalloonTransportState: Equatable {
    case disconnected
    case scanning
    case connecting
    case ready
    case unavailable
}

enum BalloonTransportEvent: Equatable {
    case state(BalloonTransportState)
    case notification(Data)
    case writeFailed
}

/// Low-level transport only. It has no knowledge of Figures, memories, Feed,
/// relationships, retry policy, or UI state.
@MainActor
protocol BalloonLinkProtocol: AnyObject {
    var onEvent: ((BalloonTransportEvent) -> Void)? { get set }
    func start()
    func stop()
    func write(_ data: Data)
}

@MainActor
enum BalloonLinkFactory {
    static func make(mock: Bool,
                     configuration: BalloonBLEConfiguration = .installation) -> BalloonLinkProtocol {
        #if targetEnvironment(simulator)
        return MockBalloonLink()
        #else
        return mock ? MockBalloonLink() : CoreBluetoothBalloonLink(configuration: configuration)
        #endif
    }
}
