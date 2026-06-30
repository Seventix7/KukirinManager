import Foundation

/// Simulated protocol for UI development and Simulator testing.
final class MockScooterProtocol: ScooterProtocol, @unchecked Sendable {
    let modelId: ScooterModel = .g3
    var capabilities: ScooterCapabilities { .mock }

    private var tick: Int = 0
    private var speed: Double = 0
    private var battery: Double = 78
    private var tripKm: Double = 2.4
    private var odometerKm: Double = 1247.3
    private var rideSeconds: TimeInterval = 420
    var rideMode: RideMode = .sport
    private var timer: Timer?

    var speedLimits: [RideMode: Double] = [
        .eco: 15, .sport: 25, .race: 45, .custom: 35
    ]
    var accelerationStrength: Int = 60
    var regenBraking: Int = 40
    var cruiseControl = false
    var lightsOn = true
    var motorLocked = false
    var startMode: StartMode = .kickStart

    func identify(name: String?, advertisement: [String: Any]) -> Bool { false }

    func onConnected(session: BLEPeripheralSession?) async throws {
        startSimulation()
    }

    func disconnect() {
        timer?.invalidate()
        timer = nil
    }

    func parseIncoming(_ data: Data) -> [ProtocolEvent] { [] }

    func buildCommand(_ command: ScooterCommand) throws -> Data {
        switch command {
        case .setRideMode(let mode):
            rideMode = mode
        case .setAccelerationStrength(let value):
            accelerationStrength = value
        case .setRegenBraking(let value):
            regenBraking = value
        case .setCruiseControl(let enabled):
            cruiseControl = enabled
        case .setLights(let on):
            lightsOn = on
        case .setStartMode(let mode):
            startMode = mode
        case .setMotorLock(let locked):
            motorLocked = locked
        case .setSpeedLimit(let mode, let kmh):
            speedLimits[mode] = kmh
        case .requestTelemetry, .requestFirmwareInfo, .ping:
            break
        default:
            throw ProtocolError.unsupportedCommand
        }
        return Data()
    }

    func currentTelemetry() -> TelemetrySnapshot {
        TelemetrySnapshot(
            timestamp: Date(),
            speedKmh: speed,
            batteryPercent: battery,
            batteryVoltage: 52.4 + Double.random(in: -0.2...0.2),
            batteryCurrent: speed > 0 ? -3.2 - speed * 0.05 : 0.1,
            motorPowerWatts: speed * 28,
            controllerPowerWatts: speed * 24,
            motorTemperatureC: 38 + speed * 0.15,
            controllerTemperatureC: 35 + speed * 0.12,
            throttlePercent: min(speed / 50 * 100, 100),
            brakePercent: 0,
            rideMode: rideMode,
            rideDurationSeconds: rideSeconds,
            tripDistanceKm: tripKm,
            odometerKm: odometerKm,
            errorCodes: [],
            firmwareVersion: "1.2.4",
            serialNumber: "KR-G3-MOCK-001",
            rssi: -58
        )
    }

    func currentFirmware() -> FirmwareInfo {
        FirmwareInfo(
            firmwareVersion: "1.2.4",
            controllerVersion: "2.0.1",
            bleVersion: "1.0.3",
            hardwareRevision: "G3-RevB"
        )
    }

    private func startSimulation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.simulateTick()
            }
        }
    }

    private func simulateTick() {
        tick += 1
        let target = cruiseControl ? 28.0 : (sin(Double(tick) / 40) + 1) * 18
        speed += (target - speed) * 0.08
        if speed > 0.5 {
            tripKm += speed / 36000
            odometerKm += speed / 36000
            rideSeconds += 0.1
            battery -= 0.0003
        }
        battery = max(battery, 5)
    }
}
