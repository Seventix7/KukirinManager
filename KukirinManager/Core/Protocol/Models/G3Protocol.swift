import Foundation

/// KuKirin G3 protocol — primary target for verified telemetry and controls.
final class G3Protocol: ScooterProtocol, @unchecked Sendable {
    let modelId: ScooterModel = .g3
    var capabilities: ScooterCapabilities { ScooterCapabilities.forModel(.g3) }

    private var lastTelemetry = TelemetrySnapshot.empty
    private var firmwareInfo: FirmwareInfo?
    private var pingSentAt: Date?

    func identify(name: String?, advertisement: [String: Any]) -> Bool {
        matchesModel(name: name, patterns: ScooterModel.g3.namePatterns)
            || hasNordicUART(advertisement)
    }

    func onConnected(session: BLEPeripheralSession?) async throws {
        PacketLogger.shared.logSystem("G3: initiating handshake sequence")
        guard let session else { return }
        try await performHandshake(session: session)
    }

    func parseIncoming(_ data: Data) -> [ProtocolEvent] {
        guard FrameValidator.validate(data) else { return [] }
        var events: [ProtocolEvent] = [.rawFrame(data)]
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { return events }

        if bytes[0] == 0x5A, bytes[1] == 0xA5 {
            events.append(contentsOf: parseKugooFrame(bytes))
        } else if bytes[0] == 0x55, bytes[1] == 0xAA {
            events.append(contentsOf: parseAlternateFrame(bytes))
        }
        return events
    }

    func buildCommand(_ command: ScooterCommand) throws -> Data {
        switch command {
        case .setRideMode(let mode):
            return buildFrame(opcode: 0x20, payload: [UInt8(modeIndex(mode))])
        case .setAccelerationStrength(let value):
            guard capabilities.accelerationStrength else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x21, payload: [UInt8(value)])
        case .setRegenBraking(let value):
            guard capabilities.regenBraking else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x22, payload: [UInt8(value)])
        case .setCruiseControl(let on):
            guard capabilities.cruiseControl else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x23, payload: [on ? 1 : 0])
        case .setLights(let on):
            guard capabilities.lights else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x24, payload: [on ? 1 : 0])
        case .setHorn(let on):
            guard capabilities.electronicHorn else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x25, payload: [on ? 1 : 0])
        case .setDisplayBrightness(let value):
            guard capabilities.displayBrightness else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x26, payload: [UInt8(value)])
        case .setAutoSleepTimer(let minutes):
            guard capabilities.autoSleepTimer else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x27, payload: [UInt8(min(minutes, 60))])
        case .setStartMode(let mode):
            guard capabilities.startMode else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x28, payload: [mode == .zeroStart ? 1 : 0])
        case .setMotorLock(let locked):
            guard capabilities.motorLock else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x29, payload: [locked ? 1 : 0])
        case .setPasswordLock(let enabled, _):
            guard capabilities.passwordLock else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x2A, payload: [enabled ? 1 : 0])
        case .setSpeedLimit(let mode, let kmh):
            guard capabilities.speedLimitConfiguration else { throw ProtocolError.capabilityNotAvailable }
            let clamped = UInt8(min(max(kmh, capabilities.speedLimitMin), capabilities.speedLimitMax))
            return buildFrame(opcode: 0x30, payload: [UInt8(modeIndex(mode)), clamped])
        case .requestTelemetry:
            return buildFrame(opcode: 0x01, payload: [])
        case .requestFirmwareInfo:
            return buildFrame(opcode: 0x02, payload: [])
        case .ping:
            pingSentAt = Date()
            return buildFrame(opcode: 0xFE, payload: [])
        }
    }

    // MARK: - Handshake

    private func performHandshake(session: BLEPeripheralSession) async throws {
        let frame1 = try buildCommand(.requestFirmwareInfo)
        await MainActor.run { session.write(frame1) }
        try await Task.sleep(nanoseconds: 200_000_000)
        let frame2 = try buildCommand(.requestTelemetry)
        await MainActor.run { session.write(frame2) }
        PacketLogger.shared.logSystem("G3: handshake frames sent — verify responses in Diagnostics")
    }

    // MARK: - Parsing (opcode mapping to be confirmed via packet capture)

    private func parseKugooFrame(_ bytes: [UInt8]) -> [ProtocolEvent] {
        guard bytes.count >= 5 else { return [] }
        let opcode = bytes[3]
        var events: [ProtocolEvent] = []

        switch opcode {
        case 0x01, 0x81:
            if let telemetry = decodeTelemetry(bytes) {
                lastTelemetry = telemetry
                events.append(.telemetry(telemetry))
            }
        case 0x02, 0x82:
            if let info = decodeFirmware(bytes) {
                firmwareInfo = info
                events.append(.firmwareInfo(info))
            }
        case 0xFE, 0xFF:
            if let sent = pingSentAt {
                let latency = Date().timeIntervalSince(sent) * 1000
                events.append(.pong(latencyMs: latency))
                pingSentAt = nil
            }
        case 0x00:
            events.append(.handshakeComplete)
        default:
            break
        }
        return events
    }

    private func parseAlternateFrame(_ bytes: [UInt8]) -> [ProtocolEvent] {
        if let telemetry = decodeTelemetry(bytes) {
            lastTelemetry = telemetry
            return [.telemetry(telemetry)]
        }
        return []
    }

    private func decodeTelemetry(_ bytes: [UInt8]) -> TelemetrySnapshot? {
        guard bytes.count >= 16 else { return nil }
        var snapshot = lastTelemetry
        snapshot.timestamp = Date()
        snapshot.speedKmh = Double(bytes[4])
        snapshot.batteryPercent = Double(bytes[5])
        snapshot.batteryVoltage = Double(UInt16(bytes[6]) << 8 | UInt16(bytes[7])) / 100.0
        snapshot.batteryCurrent = Double(Int16(bitPattern: UInt16(bytes[8]) << 8 | UInt16(bytes[9]))) / 100.0
        snapshot.rideMode = modeFromIndex(bytes[10])
        snapshot.motorTemperatureC = Double(bytes[11])
        snapshot.controllerTemperatureC = Double(bytes[12])
        snapshot.throttlePercent = Double(bytes[13])
        snapshot.brakePercent = Double(bytes[14])
        if bytes.count >= 20 {
            snapshot.tripDistanceKm = Double(UInt16(bytes[15]) << 8 | UInt16(bytes[16])) / 10.0
            snapshot.odometerKm = Double(UInt16(bytes[17]) << 8 | UInt16(bytes[18])) / 10.0
        }
        snapshot.firmwareVersion = firmwareInfo?.firmwareVersion
        return snapshot
    }

    private func decodeFirmware(_ bytes: [UInt8]) -> FirmwareInfo? {
        guard bytes.count >= 12 else { return nil }
        let fw = "\(bytes[4]).\(bytes[5]).\(bytes[6])"
        let ctrl = "\(bytes[7]).\(bytes[8])"
        let ble = "\(bytes[9]).\(bytes[10])"
        let hw = "G3-\(bytes[11])"
        return FirmwareInfo(
            firmwareVersion: fw,
            controllerVersion: ctrl,
            bleVersion: ble,
            hardwareRevision: hw
        )
    }

    private func buildFrame(opcode: UInt8, payload: [UInt8]) -> Data {
        var frame: [UInt8] = [0x5A, 0xA5, UInt8(payload.count + 1), opcode]
        frame.append(contentsOf: payload)
        frame.append(FrameValidator.checksumXor(Data(frame)))
        return Data(frame)
    }

    private func matchesModel(name: String?, patterns: [String]) -> Bool {
        guard let name else { return false }
        let upper = name.uppercased()
        return patterns.contains { upper.contains($0.uppercased()) }
    }

    private func hasNordicUART(_ advertisement: [String: Any]) -> Bool {
        guard let uuids = advertisement["kCBAdvDataServiceUUIDs"] as? [Any] else { return false }
        return uuids.contains { "\($0)".uppercased().contains("6E400001") }
    }

    private func modeIndex(_ mode: RideMode) -> Int {
        switch mode {
        case .eco: 0
        case .drive: 1
        case .sport: 2
        case .custom: 3
        }
    }

    private func modeFromIndex(_ index: UInt8) -> RideMode {
        switch index {
        case 0: .eco
        case 1: .drive
        case 2: .sport
        default: .custom
        }
    }
}
