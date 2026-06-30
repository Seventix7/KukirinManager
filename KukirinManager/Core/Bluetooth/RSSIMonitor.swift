@preconcurrency import CoreBluetooth
import Foundation

@MainActor
final class RSSIMonitor {
    private var timer: Timer?
    private weak var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    var onRSSIUpdate: ((Int) -> Void)?

    func start(central: CBCentralManager, peripheral: CBPeripheral) {
        self.central = central
        self.peripheral = peripheral
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: BLEConstants.rssiPollInterval, repeats: true) { [weak self] _ in
            self?.peripheral?.readRSSI()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func handleRSSI(_ rssi: NSNumber) {
        onRSSIUpdate?(rssi.intValue)
    }
}
