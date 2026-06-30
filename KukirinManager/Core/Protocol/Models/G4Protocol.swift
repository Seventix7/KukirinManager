import Foundation

/// KuKirin G4 protocol — extend as packet formats are verified on hardware.
final class G4Protocol: ScooterProtocol, @unchecked Sendable {
    let modelId: ScooterModel = .g4
    var capabilities: ScooterCapabilities { ScooterCapabilities.forModel(.g4) }

    private var lastTelemetry = TelemetrySnapshot.empty

    func identify(name: String?, advertisement: [String: Any]) -> Bool {
        matchesModel(name: name, patterns: ScooterModel.g4.namePatterns)
            || hasNordicUART(advertisement)
    }

    func onConnected(session: BLEPeripheralSession?) async throws {
        PacketLogger.shared.logSystem("G4: connected — note some G4 variants may lack telemetry UART")
        guard let session else { return }
        let frame = try buildCommand(.requestTelemetry)
        await MainActor.run { session.write(frame) }
    }

    func parseIncoming(_ data: Data) -> [ProtocolEvent] {
        guard FrameValidator.validate(data) else { return [] }
        var events: [ProtocolEvent] = [.rawFrame(data)]
        let bytes = [UInt8](data)
        if bytes.count >= 14, bytes[0] == 0x55, bytes[1] == 0xAA {
            var snapshot = lastTelemetry
            snapshot.timestamp = Date()
            snapshot.speedKmh = Double(bytes[4])
            snapshot.batteryPercent = Double(bytes[5])
            snapshot.batteryVoltage = Double(UInt16(bytes[6]) << 8 | UInt16(bytes[7])) / 100.0
            snapshot.motorTemperatureC = Double(bytes[8])
            snapshot.controllerTemperatureC = Double(bytes[9])
            snapshot.rideMode = modeFromIndex(bytes[10])
            lastTelemetry = snapshot
            events.append(.telemetry(snapshot))
        }
        return events
    }

    func buildCommand(_ command: ScooterCommand) throws -> Data {
        switch command {
        case .setRideMode(let mode):
            return buildFrame(header: [0x55, 0xAA], opcode: 0x10, payload: [UInt8(modeIndex(mode))])
        case .setLights(let on):
            guard capabilities.lights else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(header: [0x55, 0xAA], opcode: 0x11, payload: [on ? 1 : 0])
        case .setSpeedLimit(let mode, let kmh):
            guard capabilities.speedLimitConfiguration else { throw ProtocolError.capabilityNotAvailable }
            let speedByte = UInt8(min(max(kmh, capabilities.speedLimitMin), capabilities.speedLimitMax))
            return buildFrame(header: [0x55, 0xAA], opcode: 0x12, payload: [UInt8(modeIndex(mode)), speedByte])
        case .setCruiseControl(let on):
            guard capabilities.cruiseControl else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(header: [0x55, 0xAA], opcode: 0x13, payload: [on ? 1 : 0])
        case .requestTelemetry:
            return buildFrame(header: [0x55, 0xAA], opcode: 0x01, payload: [])
        case .requestFirmwareInfo:
            return buildFrame(header: [0x55, 0xAA], opcode: 0x02, payload: [])
        case .ping:
            return buildFrame(header: [0x55, 0xAA], opcode: 0xFE, payload: [])
        default:
            throw ProtocolError.unsupportedCommand
        }
    }

    private func buildFrame(header: [UInt8], opcode: UInt8, payload: [UInt8]) -> Data {
        var frame = header
        frame.append(UInt8(payload.count + 1))
        frame.append(opcode)
        frame.append(contentsOf: payload)
        frame.append(frame.reduce(0) { $0 ^ $1 })
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
