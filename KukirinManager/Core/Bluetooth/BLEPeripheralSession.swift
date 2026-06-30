import CoreBluetooth
import Foundation

/// Active GATT session for a connected peripheral.
@MainActor
final class BLEPeripheralSession: NSObject {
    let peripheral: CBPeripheral
    private(set) var txCharacteristic: CBCharacteristic?
    private(set) var rxCharacteristic: CBCharacteristic?
    private(set) var discoveredServices: [CBService] = []

    var onDataReceived: ((Data) -> Void)?
    var onDiscoveryComplete: (() -> Void)?
    var onDiscoveryFailed: ((String) -> Void)?
    var onRSSIUpdate: ((Int) -> Void)?

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    func discoverServices() {
        peripheral.discoverServices([BLEConstants.nordicUARTService])
    }

    func write(_ data: Data) {
        guard let tx = txCharacteristic else { return }
        PacketLogger.shared.log(direction: .tx, data: data)
        peripheral.writeValue(data, for: tx, type: .withResponse)
    }

    func enableNotifications() {
        guard let rx = rxCharacteristic else { return }
        peripheral.setNotifyValue(true, for: rx)
    }
}

extension BLEPeripheralSession: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                onDiscoveryFailed?(error.localizedDescription)
                return
            }
            guard let services = peripheral.services, !services.isEmpty else {
                onDiscoveryFailed?("No UART service found")
                return
            }
            discoveredServices = services
            for service in services where service.uuid == BLEConstants.nordicUARTService {
                peripheral.discoverCharacteristics(
                    [BLEConstants.nordicUARTTX, BLEConstants.nordicUARTRX],
                    for: service
                )
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                onDiscoveryFailed?(error.localizedDescription)
                return
            }
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == BLEConstants.nordicUARTTX {
                    txCharacteristic = characteristic
                } else if characteristic.uuid == BLEConstants.nordicUARTRX {
                    rxCharacteristic = characteristic
                }
            }
            if txCharacteristic != nil, rxCharacteristic != nil {
                enableNotifications()
                onDiscoveryComplete?()
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value else { return }
        PacketLogger.shared.log(direction: .rx, data: data)
        Task { @MainActor in
            onDataReceived?(data)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            PacketLogger.shared.logSystem("Write error: \(error.localizedDescription)")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        Task { @MainActor in
            onRSSIUpdate?(RSSI.intValue)
        }
    }
}
