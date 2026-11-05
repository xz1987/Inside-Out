import CoreBluetooth
import Foundation

@MainActor
final class CoreBluetoothBalloonLink: NSObject, BalloonLinkProtocol {
    var onEvent: ((BalloonTransportEvent) -> Void)?

    private let configuration: BalloonBLEConfiguration
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var wantsToRun = false

    init(configuration: BalloonBLEConfiguration = .installation) {
        self.configuration = configuration
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func start() {
        wantsToRun = true
        beginScanningIfPossible()
    }

    func stop() {
        wantsToRun = false
        central.stopScan()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        clearPeripheral()
        onEvent?(.state(.disconnected))
    }

    func write(_ data: Data) {
        guard let peripheral, let commandCharacteristic,
              peripheral.state == .connected else {
            onEvent?(.writeFailed)
            return
        }
        peripheral.writeValue(data, for: commandCharacteristic, type: .withResponse)
    }

    private var serviceUUID: CBUUID { CBUUID(string: configuration.serviceUUID) }
    private var commandUUID: CBUUID { CBUUID(string: configuration.commandCharacteristicUUID) }
    private var statusUUID: CBUUID { CBUUID(string: configuration.statusCharacteristicUUID) }

    private func beginScanningIfPossible() {
        guard wantsToRun else { return }
        guard central.state == .poweredOn else {
            if central.state != .unknown && central.state != .resetting {
                onEvent?(.state(.unavailable))
            }
            return
        }
        clearPeripheral()
        onEvent?(.state(.scanning))
        central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func clearPeripheral() {
        peripheral?.delegate = nil
        peripheral = nil
        commandCharacteristic = nil
        statusCharacteristic = nil
    }
}

extension CoreBluetoothBalloonLink: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn {
                beginScanningIfPossible()
            } else if central.state != .unknown && central.state != .resetting {
                onEvent?(.state(.unavailable))
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            guard wantsToRun, self.peripheral == nil else { return }
            central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            onEvent?(.state(.connecting))
            central.connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in peripheral.discoverServices([serviceUUID]) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            clearPeripheral()
            onEvent?(.state(.disconnected))
            beginScanningIfPossible()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            clearPeripheral()
            onEvent?(.state(.disconnected))
            beginScanningIfPossible()
        }
    }
}

extension CoreBluetoothBalloonLink: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard error == nil,
                  let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
                onEvent?(.writeFailed)
                return
            }
            peripheral.discoverCharacteristics([commandUUID, statusUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                onEvent?(.writeFailed)
                return
            }
            commandCharacteristic = service.characteristics?.first(where: { $0.uuid == commandUUID })
            statusCharacteristic = service.characteristics?.first(where: { $0.uuid == statusUUID })
            guard commandCharacteristic != nil, let statusCharacteristic else {
                onEvent?(.writeFailed)
                return
            }
            peripheral.setNotifyValue(true, for: statusCharacteristic)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateNotificationStateFor characteristic: CBCharacteristic,
                                error: Error?) {
        Task { @MainActor in
            guard characteristic.uuid == statusUUID, error == nil, characteristic.isNotifying else {
                onEvent?(.writeFailed)
                return
            }
            onEvent?(.state(.ready))
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        if error != nil {
            Task { @MainActor in onEvent?(.writeFailed) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        Task { @MainActor in
            guard error == nil, characteristic.uuid == statusUUID, let value = characteristic.value else {
                onEvent?(.writeFailed)
                return
            }
            onEvent?(.notification(value))
        }
    }
}
