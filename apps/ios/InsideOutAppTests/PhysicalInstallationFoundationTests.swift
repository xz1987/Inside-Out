import XCTest
@testable import InsideOutApp

final class PhysicalInstallationFoundationTests: XCTestCase {
    func testFigureOrderAndMediaAreFrozen() {
        XCTAssertEqual(FigureKind.allCases.map(\.rawValue), [
            "anger", "joy", "anxiety", "sadness",
            "disgust", "fear", "embarrassment", "boredom"
        ])
        XCTAssertEqual(FigureKind.allCases.map(\.channelIndex), Array(0..<8))
        XCTAssertEqual(FigureKind.allCases.map(\.medium), [
            .air, .water, .air, .water, .water, .water, .air, .air
        ])
    }

    func testActuationClampsMinimumMaximumAndSupportsFourChannels() {
        let settings = InstallationSettingsSnapshot(
            installationMode: true,
            airMinimumChange: 5,
            waterMinimumChange: 7,
            maximumChangePerEvent: 25,
            airInterpretationLimit: 100,
            waterInterpretationLimit: 100,
            allowConcurrentPumps: true
        )
        let feeds = [
            feed(.anger, 1), feed(.joy, 1), feed(.anxiety, 30), feed(.sadness, 8)
        ]

        let command = ActuationPolicy().command(
            feeds: feeds,
            settings: settings,
            sessionTotals: InstallationSessionTotals(),
            hardwareReady: true
        )

        XCTAssertEqual(command?.deltas, [5, 7, 25, 8, 0, 0, 0, 0])
    }

    func testActuationUsesRemainingCapacityAndNeverQueuesWhenDisconnected() {
        let settings = InstallationSettingsSnapshot(
            installationMode: true,
            airMinimumChange: 5,
            waterMinimumChange: 5,
            maximumChangePerEvent: 25,
            airInterpretationLimit: 20,
            waterInterpretationLimit: 40,
            allowConcurrentPumps: true
        )
        var totals = InstallationSessionTotals()
        totals.apply(PumpDeltaCommand(deltas: [18, 0, 0, 0, 0, 0, 0, 0]))

        XCTAssertNil(ActuationPolicy().command(
            feeds: [feed(.anger, 15)], settings: settings,
            sessionTotals: totals, hardwareReady: false
        ))
        XCTAssertEqual(ActuationPolicy().command(
            feeds: [feed(.anger, 15)], settings: settings,
            sessionTotals: totals, hardwareReady: true
        )?.deltas, [2, 0, 0, 0, 0, 0, 0, 0])
    }

    func testActuationUsesSeparateAirAndWaterInterpretationLimits() {
        let settings = InstallationSettingsSnapshot(
            installationMode: true,
            airMinimumChange: 5,
            waterMinimumChange: 5,
            maximumChangePerEvent: 25,
            airInterpretationLimit: 20,
            waterInterpretationLimit: 40,
            allowConcurrentPumps: true
        )
        var totals = InstallationSessionTotals()
        totals.apply(PumpDeltaCommand(deltas: [0, 38, 0, 0, 0, 0, 0, 18]))

        let command = ActuationPolicy().command(
            feeds: [feed(.joy, 10), feed(.boredom, 10)],
            settings: settings,
            sessionTotals: totals,
            hardwareReady: true
        )

        XCTAssertEqual(command?.deltas, [0, 2, 0, 0, 0, 0, 0, 2])
    }

    func testActuationHonorsSinglePumpAndZeroFeed() {
        let settings = InstallationSettingsSnapshot(
            installationMode: true,
            airMinimumChange: 5,
            waterMinimumChange: 5,
            maximumChangePerEvent: 25,
            airInterpretationLimit: 100,
            waterInterpretationLimit: 100,
            allowConcurrentPumps: false
        )
        let command = ActuationPolicy().command(
            feeds: [feed(.anger, 0), feed(.joy, 10), feed(.fear, 10)],
            settings: settings,
            sessionTotals: InstallationSessionTotals(),
            hardwareReady: true
        )
        XCTAssertNil(command)
    }

    func testDirectInterpreterBuildsAllSixPairsForFourFigures() async throws {
        let client = StubInterpretationProvider(payload: payload(ids: ["anger", "joy", "anxiety", "sadness"]))
        let result = try await DirectEventInterpreter(client: client).interpret(
            eventText: "A complicated moment",
            source: .message,
            context: EcosystemContext(figures: FigureState.seed,
                                      relationships: FigurePair.seedScores,
                                      memories: MemoryEntry.seed())
        )
        XCTAssertEqual(result.feeds.count, 4)
        XCTAssertEqual(result.promotedRelationships.count, 6)
        XCTAssertEqual(result.feeds.reduce(0) { $0 + $1.concentration }, 1, accuracy: 0.001)
    }

    func testDirectInterpreterRejectsFifthFigure() async {
        let client = StubInterpretationProvider(payload: payload(ids: ["anger", "joy", "anxiety", "sadness", "fear"]))
        do {
            _ = try await DirectEventInterpreter(client: client).interpret(
                eventText: "Too many",
                source: .message,
                context: EcosystemContext(figures: FigureState.seed,
                                          relationships: FigurePair.seedScores,
                                          memories: [])
            )
            XCTFail("Expected invalidResponse")
        } catch {
            XCTAssertEqual(error as? DirectInterpretationError, .invalidResponse)
        }
    }

    func testDirectRequestUsesStrictSchemaWithoutTranscriptInHeaders() throws {
        let config = DirectInterpretationConfiguration(
            baseURL: URL(string: "https://example.test/v1")!, apiKey: "test-secret", model: "test-model"
        )
        let client = DirectInterpretationClient(configuration: config, session: URLSession.shared)
        let body = client.requestBody(text: "private transcript", source: .voice)
        let data = try JSONSerialization.data(withJSONObject: body)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("json_schema"))
        XCTAssertTrue(text.contains("private transcript"))
        XCTAssertFalse(text.contains("test-secret"))
    }

    func testDirectClientDecodesMockedResponseWithoutNetworkQuota() async throws {
        let expected = payload(ids: ["joy", "sadness"])
        let content = String(decoding: try JSONEncoder().encode(expected), as: UTF8.self)
        let envelope = try JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": content]]]
        ])
        let response = HTTPURLResponse(
            url: URL(string: "https://example.test/v1/chat/completions")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        let client = DirectInterpretationClient(
            configuration: .init(baseURL: URL(string: "https://example.test/v1")!,
                                 apiKey: "test-secret", model: "test-model"),
            session: StubURLSession(result: .success((envelope, response)))
        )

        let decoded = try await client.interpret(text: "private memory", source: .message)
        XCTAssertEqual(decoded, expected)
    }

    func testDirectClientMapsTimeoutAndMalformedOutputToSafeFailures() async {
        let config = DirectInterpretationConfiguration(
            baseURL: URL(string: "https://example.test/v1")!, apiKey: "test-secret", model: "test-model"
        )
        let timeout = DirectInterpretationClient(
            configuration: config,
            session: StubURLSession(result: .failure(URLError(.timedOut)))
        )
        do {
            _ = try await timeout.interpret(text: "private memory", source: .voice)
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual(error as? DirectInterpretationError, .timedOut)
        }

        let response = HTTPURLResponse(
            url: URL(string: "https://example.test/v1/chat/completions")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        let malformed = DirectInterpretationClient(
            configuration: config,
            session: StubURLSession(result: .success((Data("{}".utf8), response)))
        )
        do {
            _ = try await malformed.interpret(text: "private memory", source: .voice)
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? DirectInterpretationError, .invalidResponse)
        }
    }

    @MainActor
    func testInstallationSettingsPersistAndRestoreDefaults() {
        let suite = "InsideOutAppTests.InstallationSettings"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = InstallationSettings(defaults: defaults)
        first.installationMode = true
        first.airMinimumChange = 7
        first.waterMinimumChange = 9
        first.maximumChangePerEvent = 24
        first.airInterpretationLimit = 80
        first.waterInterpretationLimit = 120

        let restored = InstallationSettings(defaults: defaults)
        XCTAssertTrue(restored.installationMode)
        XCTAssertEqual(restored.airMinimumChange, 7)
        XCTAssertEqual(restored.waterMinimumChange, 9)
        XCTAssertEqual(restored.maximumChangePerEvent, 24)
        XCTAssertEqual(restored.airInterpretationLimit, 80)
        XCTAssertEqual(restored.waterInterpretationLimit, 120)
        defaults.removePersistentDomain(forName: suite)
    }

    func testBalloonCodecRoundTripsCommandsAndStatuses() throws {
        let codec = BalloonPacketCodec()
        let command = BalloonCommand(
            sequenceID: 0x1234,
            operation: .fill,
            deltas: [5, 10, 15, 20, 0, 0, 25, 1]
        )
        let packet = codec.encode(command)
        XCTAssertEqual(packet.count, BalloonPacketCodec.commandLength)
        XCTAssertEqual(try codec.decodeCommand(packet), command)

        let statuses: [BalloonStatus] = [
            .acknowledged(sequenceID: 0x1234),
            .rejected(sequenceID: 0x1234, code: 7),
            .stopped(sequenceID: 0x1234)
        ]
        for status in statuses {
            let data = codec.encode(status)
            XCTAssertEqual(data.count, BalloonPacketCodec.statusLength)
            XCTAssertEqual(try codec.decodeStatus(data), status)
        }
    }

    func testBalloonCodecRejectsCorruptedPacket() {
        let codec = BalloonPacketCodec()
        let command = BalloonCommand(sequenceID: 1, operation: .fill,
                                     deltas: Array(repeating: 5, count: 8))
        var bytes = [UInt8](codec.encode(command))
        bytes[4] ^= 0xFF
        XCTAssertThrowsError(try codec.decodeCommand(Data(bytes)))
    }

    @MainActor
    func testMockWalkthroughConnectsSendsAndAcknowledges() {
        let mock = MockBalloonLink(scenario: .acknowledge)
        var transportStates: [BalloonTransportState] = []
        mock.onEvent = {
            if case .state(let state) = $0 { transportStates.append(state) }
        }
        mock.start()
        XCTAssertEqual(transportStates, [.scanning, .connecting, .ready])

        let controller = BalloonLinkController(link: mock)
        controller.connect()
        XCTAssertTrue(controller.isReady)
        XCTAssertTrue(controller.testChannel(.anger, amount: 5))
        XCTAssertEqual(mock.writeCount, 1)
        XCTAssertEqual(controller.lastStatus, .acknowledged(sequenceID: 1))
        XCTAssertTrue(controller.isReady)
    }

    @MainActor
    func testMockTimeoutRetriesExactlyOnceThenFaults() async {
        let mock = MockBalloonLink(scenario: .timeout)
        let controller = BalloonLinkController(
            link: mock,
            acknowledgementTimeoutNanoseconds: 10_000_000
        )
        controller.connect()
        XCTAssertTrue(controller.testChannel(.joy, amount: 5))
        try? await Task.sleep(nanoseconds: 60_000_000)

        XCTAssertEqual(mock.writeCount, 2)
        XCTAssertEqual(controller.state, .fault(.acknowledgementTimedOut(sequenceID: 1)))
    }

    @MainActor
    func testMockRejectProducesFault() {
        let mock = MockBalloonLink(scenario: .reject)
        let controller = BalloonLinkController(link: mock)
        controller.connect()
        XCTAssertTrue(controller.stopCurrentPumps())
        XCTAssertEqual(mock.writeCount, 1)
        XCTAssertEqual(controller.state, .fault(.rejected(sequenceID: 1, code: 1)))
    }

    @MainActor
    func testDisconnectDropsPendingCommandAndReconnectDoesNotReplay() {
        let mock = MockBalloonLink(scenario: .disconnect)
        let controller = BalloonLinkController(link: mock)
        controller.connect()
        XCTAssertTrue(controller.testChannel(.fear, amount: 5))
        XCTAssertEqual(controller.state, .fault(.disconnected))
        XCTAssertEqual(mock.writeCount, 1)

        mock.scenario = .acknowledge
        controller.connect()
        XCTAssertTrue(controller.isReady)
        XCTAssertEqual(mock.writeCount, 1)
    }

    @MainActor
    func testControllerRejectsCommandUnlessReady() {
        let controller = BalloonLinkController(link: MockBalloonLink())
        XCTAssertFalse(controller.send(deltas: Array(repeating: 5, count: 8)))
        XCTAssertEqual(controller.state, .fault(.notReady))
    }

    @MainActor
    func testControllerIgnoresMismatchedAcknowledgement() {
        let mock = MockBalloonLink(scenario: .timeout)
        let controller = BalloonLinkController(
            link: mock,
            acknowledgementTimeoutNanoseconds: 1_000_000_000
        )
        let codec = BalloonPacketCodec()
        controller.connect()
        XCTAssertTrue(controller.testChannel(.anxiety, amount: 5))

        mock.onEvent?(.notification(codec.encode(.acknowledged(sequenceID: 99))))
        XCTAssertEqual(controller.state, .awaitingAcknowledgement(sequenceID: 1, attempt: 1))

        mock.onEvent?(.notification(codec.encode(.acknowledged(sequenceID: 1))))
        XCTAssertTrue(controller.isReady)
        XCTAssertEqual(controller.lastStatus, .acknowledged(sequenceID: 1))
    }

    @MainActor
    func testChannelAndStopControlsEncodeExpectedPackets() throws {
        let mock = MockBalloonLink(scenario: .acknowledge)
        let controller = BalloonLinkController(link: mock)
        let codec = BalloonPacketCodec()
        controller.connect()

        XCTAssertTrue(controller.testChannel(.sadness, amount: 7))
        let testCommand = try codec.decodeCommand(mock.writtenPackets[0])
        XCTAssertEqual(testCommand.operation, .test)
        XCTAssertEqual(testCommand.deltas, [0, 0, 0, 7, 0, 0, 0, 0])

        XCTAssertTrue(controller.stopCurrentPumps())
        let stopCommand = try codec.decodeCommand(mock.writtenPackets[1])
        XCTAssertEqual(stopCommand.operation, .stop)
        XCTAssertEqual(stopCommand.deltas, Array(repeating: 0, count: 8))
        XCTAssertEqual(controller.lastStatus, .stopped(sequenceID: 2))
    }

    @MainActor
    func testInterpretedAnalysisSendsFillButManualTestDoesNotConsumeTotals() throws {
        let suite = "InsideOutAppTests.AutomaticActuation"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = InstallationSettings(defaults: defaults)
        settings.installationMode = true
        settings.airMinimumChange = 6
        settings.waterMinimumChange = 8
        settings.maximumChangePerEvent = 25
        settings.airInterpretationLimit = 100
        settings.waterInterpretationLimit = 100

        let mock = MockBalloonLink(scenario: .acknowledge)
        let controller = BalloonLinkController(link: mock)
        controller.connect()
        let viewModel = JournalViewModel(installationSettings: settings, balloonLink: controller)
        let interpreted = EventAnalysis(
            summary: "A bright moment.",
            feeds: [feed(.joy, 12)],
            promotedRelationships: [],
            interpretationMode: "direct"
        )

        XCTAssertTrue(viewModel.actuateAnalysisIfPossible(interpreted))
        let fill = try BalloonPacketCodec().decodeCommand(mock.writtenPackets[0])
        XCTAssertEqual(fill.operation, .fill)
        XCTAssertEqual(fill.deltas, [0, 12, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(viewModel.installationTotals[.joy], 12)

        // Manual tests bypass the interpreted-event maximum (25) and totals.
        XCTAssertTrue(controller.testChannel(.joy, amount: 100))
        let test = try BalloonPacketCodec().decodeCommand(mock.writtenPackets[1])
        XCTAssertEqual(test.operation, .test)
        XCTAssertEqual(test.deltas, [0, 100, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(viewModel.installationTotals[.joy], 12)
        defaults.removePersistentDomain(forName: suite)
    }

    private func feed(_ kind: FigureKind, _ amount: Int) -> FigureFeed {
        FigureFeed(figure: kind, feedAmount: amount, concentration: 0.25,
                   evidence: "evidence", voiceLine: "voice")
    }

    private func payload(ids: [String]) -> DirectInterpretationPayload {
        DirectInterpretationPayload(
            summary: "You remembered a layered moment.",
            turningPoint: "It changed.",
            figures: ids.map {
                .init(id: $0, concentration: 1 / Double(ids.count), feed: 10,
                      evidence: "evidence", voiceLine: "I was here.", confidence: 0.8)
            },
            relationshipCues: [], objectCandidate: nil, uncertainties: []
        )
    }
}

private struct StubInterpretationProvider: DirectInterpretationProviding {
    let payload: DirectInterpretationPayload
    func interpret(text: String, source: EventSource) async throws -> DirectInterpretationPayload { payload }
}

private struct StubURLSession: URLSessionProtocol {
    let result: Result<(Data, URLResponse), Error>
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { try result.get() }
}
