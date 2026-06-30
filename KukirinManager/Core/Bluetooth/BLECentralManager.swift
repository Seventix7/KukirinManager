import CoreBluetooth
import Foundation

/// CoreBluetooth central manager wrapper with scan, connect, and notify handling.
@MainActor
final class BLECentralManager: NSObject {
    var onDevicesUpdated: (([DiscoveredDevice]) -> Void)?
    var onConnectionStateChange: ((ConnectionState) -> Void)?
    var onSessionReady: ((BLEPeripheralSession) -> Void)?
    var onDataReceived: ((Data) -> Void)?
    var onRSSIUpdate: ((Int) -> Void)?

    private(set) var discoveredDevices: [DiscoveredDevice] = []
    private(set) var session: BLEPeripheralSession?
    private(set) var connectionState: ConnectionState = .idle

    private var central: CBCentralManager!
    private let coordinator = ConnectionCoordinator()
    private let rssiMonitor = RSSIMonitor()
    private let registry: ProtocolRegistry
    private var scanTimer: Timer?
    private var connectionTimer: Timer?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var pendingConnectId: UUID?

    init(registry: ProtocolRegistry) {
        self.registry = registry
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: BLEConstants.restoreIdentifier]
        )
        coordinator.onStateChange = { [weak self] state in
            self?.connectionState = state
            self?.onConnectionStateChange?(state)
        }
    }

    var isBluetoothReady: Bool {
        central.state == .poweredOn
    }

    func startScan() {
        guard central.state == .poweredOn else {
            coordinator.markFailed("Bluetooth is not available")
            return
        }
        discoveredDevices.removeAll()
        peripherals.removeAll()
        onDevicesUpdated?([])
        coordinator.beginScan()
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        PacketLogger.shared.logSystem("Scan started")
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.scanDuration, repeats: false) { [weak self] _ in
            self?.stopScan()
        }
    }

    func stopScan() {
        central.stopScan()
        scanTimer?.invalidate()
        scanTimer = nil
        if connectionState == .scanning {
            coordinator.markIdle()
        }
        PacketLogger.shared.logSystem("Scan stopped")
    }

    func connect(to device: DiscoveredDevice) {
        stopScan()
        guard let peripheral = peripherals[device.id] else {
            coordinator.markFailed("Peripheral not found")
            return
        }
        pendingConnectId = device.id
        coordinator.beginConnect()
        central.connect(peripheral, options: nil)
        startConnectionTimeout()
        PacketLogger.shared.logSystem("Connecting to \(device.name)")
    }

    func disconnect() {
        guard let peripheral = session?.peripheral else {
            coordinator.markDisconnected()
            return
        }
        central.cancelPeripheralConnection(peripheral)
        cleanupSession()
        coordinator.markDisconnected()
    }

    func reconnect(to peripheralId: UUID) {
        let retrieved = central.retrievePeripherals(withIdentifiers: [peripheralId])
        guard let peripheral = retrieved.first else {
            coordinator.markFailed("Could not retrieve peripheral")
            return
        }
        peripherals[peripheral.identifier] = peripheral
        pendingConnectId = peripheral.identifier
        if coordinator.beginReconnect() {
            coordinator.state = .connecting
            central.connect(peripheral, options: nil)
            startConnectionTimeout()
        }
    }

    func write(_ data: Data) {
        session?.write(data)
    }

    private func startConnectionTimeout() {
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.connectionTimeout, repeats: false) { [weak self] _ in
            guard let self, !self.connectionState.isConnected else { return }
            self.coordinator.markFailed("Connection timed out")
            if let peripheral = self.session?.peripheral ?? self.peripherals[self.pendingConnectId ?? UUID()] {
                self.central.cancelPeripheralConnection(peripheral)
            }
        }
    }

    private func cleanupSession() {
        rssiMonitor.stop()
        session = nil
        connectionTimer?.invalidate()
        connectionTimer = nil
    }

    private func updateDeviceList(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        peripherals[peripheral.identifier] = peripheral
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Unknown Device"
        let model = registry.identifyModel(name: name, advertisement: advertisementData)
        let isCompatible = registry.isCompatible(name: name, advertisement: advertisementData)
        let advStrings = advertisementData.reduce(into: [String: String]()) { result, pair in
            result["\(pair.key)"] = "\(pair.value)"
        }
        let device = DiscoveredDevice(
            id: peripheral.identifier,
            name: name,
            rssi: rssi.intValue,
            model: model,
            isCompatible: isCompatible,
            batteryPercent: nil,
            advertisementData: advStrings
        )
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
        discoveredDevices.sort { lhs, rhs in
            if lhs.isCompatible != rhs.isCompatible { return lhs.isCompatible }
            return lhs.rssi > rhs.rssi
        }
        onDevicesUpdated?(discoveredDevices)
    }
}

extension BLECentralManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                PacketLogger.shared.logSystem("Bluetooth powered on")
            case .poweredOff:
                coordinator.markFailed("Bluetooth is turned off")
            case .unauthorized:
                coordinator.markFailed("Bluetooth permission denied")
            default:
                break
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        Task { @MainActor in
            if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
                for peripheral in peripherals {
                    self.peripherals[peripheral.identifier] = peripheral
                    if peripheral.state == .connected {
                        self.session = BLEPeripheralSession(peripheral: peripheral)
                        self.setupSessionCallbacks()
                        self.coordinator.markConnected()
                    }
                }
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            updateDeviceList(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionTimer?.invalidate()
            coordinator.beginDiscover()
            let newSession = BLEPeripheralSession(peripheral: peripheral)
            session = newSession
            setupSessionCallbacks()
            newSession.discoverServices()
            rssiMonitor.start(central: central, peripheral: peripheral)
            PacketLogger.shared.logSystem("Connected to \(peripheral.name ?? "device")")
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            coordinator.markFailed(error?.localizedDescription ?? "Connection failed")
            cleanupSession()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            cleanupSession()
            PacketLogger.shared.logSystem("Disconnected: \(error?.localizedDescription ?? "user initiated")")
            coordinator.markDisconnected()
        }
    }

    @MainActor
    private func setupSessionCallbacks() {
        session?.onDataReceived = { [weak self] data in
            self?.onDataReceived?(data)
        }
        session?.onRSSIUpdate = { [weak self] rssi in
            self?.onRSSIUpdate?(rssi)
        }
        session?.onDiscoveryComplete = { [weak self] in
            self?.coordinator.beginHandshake()
            if let session = self?.session {
                self?.onSessionReady?(session)
            }
            self?.coordinator.markConnected()
        }
        session?.onDiscoveryFailed = { [weak self] message in
            self?.coordinator.markFailed(message)
        }
    }
}
