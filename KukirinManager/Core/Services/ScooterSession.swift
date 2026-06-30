import Foundation

/// Central session coordinating BLE, protocol, and telemetry state.
@MainActor
@Observable
final class ScooterSession {
    var connectionState: ConnectionState = .idle
    var discoveredDevices: [DiscoveredDevice] = []
    var connectedDevice: DiscoveredDevice?
    var activeModel: ScooterModel = .unknown
    var capabilities: ScooterCapabilities = .none
    var latestTelemetry: TelemetrySnapshot = .empty
    var firmwareInfo: FirmwareInfo?
    var componentHealth: ComponentHealth = .unknown
    var errorHistory: [DiagnosticError] = []
    var bleLatencyMs: Double?
    var showConnectionSuccess = false
    private var lastLowBatteryNotificationPercent: Int?

    let preferences: PreferencesStore
    let telemetryPublisher: TelemetryPublisher

    private let registry: ProtocolRegistry
    private let lastDeviceStore: LastDeviceStore
    private let reconnectService: ReconnectService
    private let bleManager: BLECentralManager
    private var activeProtocol: (any ScooterProtocol)?
    private var mockProtocol: MockScooterProtocol?
    private var mockTimer: Timer?
    private var telemetryTimer: Timer?
    private var controlsState = ControlsState()

    var controls: ControlsState {
        get { controlsState }
        set { controlsState = newValue }
    }

    func updateAcceleration(_ value: Int) {
        controlsState.accelerationStrength = value
        sendCommand(.setAccelerationStrength(value))
    }

    func updateRegenBraking(_ value: Int) {
        controlsState.regenBraking = value
        sendCommand(.setRegenBraking(value))
    }

    func updateDisplayBrightness(_ value: Int) {
        controlsState.displayBrightness = value
        sendCommand(.setDisplayBrightness(value))
    }

    func updateRideMode(_ mode: RideMode) {
        controlsState.rideMode = mode
        sendCommand(.setRideMode(mode))
    }

    func updateAutoSleep(minutes: Int) {
        controlsState.autoSleepMinutes = minutes
        if minutes > 0 {
            sendCommand(.setAutoSleepTimer(minutes: minutes))
        }
    }

    func updateSpeedLimit(mode: RideMode, kmh: Double) {
        controlsState.speedLimits[mode] = kmh
        sendCommand(.setSpeedLimit(mode: mode, kmh: kmh))
    }

    var isConnected: Bool { connectionState.isConnected }
    var usesMock: Bool { preferences.useMockProtocol }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        self.registry = ProtocolRegistry()
        self.lastDeviceStore = LastDeviceStore()
        self.reconnectService = ReconnectService(lastDeviceStore: lastDeviceStore, preferences: preferences)
        self.telemetryPublisher = TelemetryPublisher()
        self.bleManager = BLECentralManager(registry: registry)
        setupBLECallbacks()
    }

    func onAppear() {
        if preferences.useMockProtocol {
            connectMock(model: .g3)
        } else {
            startScan()
            attemptAutoReconnect()
        }
    }

    func startScan() {
        guard !preferences.useMockProtocol else { return }
        bleManager.startScan()
    }

    func stopScan() {
        bleManager.stopScan()
    }

    func connect(to device: DiscoveredDevice) {
        if preferences.useMockProtocol {
            connectMock(model: device.model)
            return
        }
        connectedDevice = device
        activeModel = device.model
        activeProtocol = registry.protocolFor(model: device.model)
        capabilities = activeProtocol?.capabilities ?? .none
        bleManager.connect(to: device)
    }

    func disconnect() {
        if usesMock {
            disconnectMock()
            return
        }
        bleManager.disconnect()
        resetSession()
    }

    func sendCommand(_ command: ScooterCommand) {
        if let mock = mockProtocol {
            _ = try? mock.buildCommand(command)
            applyControlsFromMock()
            return
        }
        guard let proto = activeProtocol else { return }
        do {
            let data = try proto.buildCommand(command)
            if !data.isEmpty {
                bleManager.write(data)
            }
            updateControlsState(for: command)
        } catch {
            appendError(code: -1, message: error.localizedDescription)
        }
    }

    func connectMock(model: ScooterModel = .g3) {
        disconnectMock()
        let mock = MockScooterProtocol()
        mockProtocol = mock
        activeModel = model
        capabilities = ScooterCapabilities.forModel(model)
        activeProtocol = mock
        connectionState = .connected
        connectedDevice = DiscoveredDevice(
            id: UUID(),
            name: model.displayName,
            rssi: -55,
            model: model,
            isCompatible: true,
            batteryPercent: 78,
            advertisementData: [:]
        )
        Task { try? await mock.onConnected(session: nil) }
        startMockTelemetryLoop()
        firmwareInfo = mock.currentFirmware()
    }

    func disconnectMock() {
        mockTimer?.invalidate()
        mockTimer = nil
        mockProtocol?.disconnect()
        mockProtocol = nil
        resetSession()
    }

    func attemptAutoReconnect() {
        guard let saved = lastDeviceStore.load(),
              reconnectService.shouldAttemptReconnect() != nil else { return }
        connectedDevice = DiscoveredDevice(
            id: saved.id,
            name: saved.name,
            rssi: 0,
            model: saved.model,
            isCompatible: true,
            batteryPercent: nil,
            advertisementData: [:]
        )
        activeModel = saved.model
        activeProtocol = registry.protocolFor(model: saved.model)
        capabilities = activeProtocol?.capabilities ?? .none
        bleManager.reconnect(to: saved.id)
    }

    private func performProtocolHandshake(session bleSession: BLEPeripheralSession) async {
        guard let proto = activeProtocol else { return }
        do {
            try await proto.onConnected(session: bleSession)
        } catch {
            appendError(code: -2, message: error.localizedDescription)
        }
    }

    func forgetLastDevice() {
        lastDeviceStore.clear()
    }

    private func setupBLECallbacks() {
        bleManager.onDevicesUpdated = { [weak self] devices in
            self?.discoveredDevices = devices
        }
        bleManager.onConnectionStateChange = { [weak self] state in
            guard let self else { return }
            let wasConnected = self.connectionState.isConnected
            self.connectionState = state
            if state.isConnected, !wasConnected {
                self.showConnectionSuccess = true
                if let device = self.connectedDevice {
                    self.lastDeviceStore.save(id: device.id, model: device.model, name: device.name)
                }
                self.startTelemetryPolling()
            }
            if case .disconnected = state {
                self.telemetryTimer?.invalidate()
                if self.preferences.notifyOnDisconnect, let name = self.connectedDevice?.name {
                    NotificationService.notifyDisconnect(deviceName: name)
                }
            }
        }
        bleManager.onSessionReady = { [weak self] bleSession in
            Task { @MainActor in
                await self?.performProtocolHandshake(session: bleSession)
            }
        }
        bleManager.onDataReceived = { [weak self] data in
            self?.handleIncomingData(data)
        }
        bleManager.onRSSIUpdate = { [weak self] rssi in
            self?.latestTelemetry.rssi = rssi
        }
    }

    private func handleIncomingData(_ data: Data) {
        guard let proto = activeProtocol else { return }
        let events = proto.parseIncoming(data)
        for event in events {
            switch event {
            case .telemetry(let snapshot):
                var updated = snapshot
                updated.rssi = latestTelemetry.rssi
                latestTelemetry = updated
                telemetryPublisher.publish(updated)
                updateHealth(from: updated)
                if preferences.notifyOnLowBattery {
                    let pct = Int(updated.batteryPercent)
                    if pct <= 15, pct > 0, lastLowBatteryNotificationPercent != pct {
                        lastLowBatteryNotificationPercent = pct
                        NotificationService.notifyLowBattery(percent: pct)
                    } else if pct > 20 {
                        lastLowBatteryNotificationPercent = nil
                    }
                }
            case .firmwareInfo(let info):
                firmwareInfo = info
            case .error(let code, let message):
                appendError(code: code, message: message)
            case .pong(let latency):
                bleLatencyMs = latency
            case .handshakeComplete:
                PacketLogger.shared.logSystem("Handshake complete")
            case .rawFrame, .unsupported:
                break
            }
        }
    }

    private func startTelemetryPolling() {
        telemetryTimer?.invalidate()
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendCommand(.requestTelemetry)
            }
        }
    }

    private func startMockTelemetryLoop() {
        mockTimer?.invalidate()
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let mock = self.mockProtocol else { return }
                let snapshot = mock.currentTelemetry()
                self.latestTelemetry = snapshot
                self.telemetryPublisher.publish(snapshot)
            }
        }
    }

    private func resetSession() {
        connectionState = .disconnected
        connectedDevice = nil
        activeProtocol = nil
        capabilities = .none
        latestTelemetry = .empty
        firmwareInfo = nil
        componentHealth = .unknown
        bleLatencyMs = nil
        telemetryTimer?.invalidate()
    }

    private func appendError(code: Int, message: String) {
        errorHistory.insert(
            DiagnosticError(id: UUID(), timestamp: Date(), code: code, message: message),
            at: 0
        )
        if errorHistory.count > 100 { errorHistory.removeLast() }
    }

    private func updateHealth(from telemetry: TelemetrySnapshot) {
        componentHealth = ComponentHealth(
            controller: telemetry.controllerTemperatureC.map { $0 > 75 ? .warning : .healthy } ?? .unknown,
            battery: telemetry.batteryPercent < 15 ? .warning : .healthy,
            motor: telemetry.motorTemperatureC.map { $0 > 85 ? .warning : .healthy } ?? .unknown,
            sensors: telemetry.errorCodes.isEmpty ? .healthy : .error
        )
    }

    private func updateControlsState(for command: ScooterCommand) {
        switch command {
        case .setRideMode(let mode): controlsState.rideMode = mode
        case .setAccelerationStrength(let v): controlsState.accelerationStrength = v
        case .setRegenBraking(let v): controlsState.regenBraking = v
        case .setCruiseControl(let v): controlsState.cruiseControl = v
        case .setLights(let v): controlsState.lightsOn = v
        case .setStartMode(let v): controlsState.startMode = v
        case .setMotorLock(let v): controlsState.motorLocked = v
        default: break
        }
    }

    private func applyControlsFromMock() {
        guard let mock = mockProtocol else { return }
        controlsState.rideMode = mock.rideMode
        controlsState.accelerationStrength = mock.accelerationStrength
        controlsState.regenBraking = mock.regenBraking
        controlsState.cruiseControl = mock.cruiseControl
        controlsState.lightsOn = mock.lightsOn
        controlsState.motorLocked = mock.motorLocked
        controlsState.startMode = mock.startMode
        controlsState.speedLimits = mock.speedLimits
    }
}

/// UI-facing controls state mirrored from scooter.
struct ControlsState: Equatable {
    var rideMode: RideMode = .eco
    var accelerationStrength: Int = 50
    var regenBraking: Int = 40
    var cruiseControl = false
    var lightsOn = false
    var motorLocked = false
    var startMode: StartMode = .kickStart
    var displayBrightness: Int = 80
    var autoSleepMinutes: Int = 5
    var speedLimits: [RideMode: Double] = [
        .eco: 15, .sport: 25, .race: 45, .custom: 35
    ]
}
