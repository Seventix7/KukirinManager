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

    private var buffer = Data()

    func parseIncoming(_ data: Data) -> [ProtocolEvent] {
        guard FrameValidator.validate(data) else { return [] }
        var events: [ProtocolEvent] = [.rawFrame(data)]
        
        buffer.append(data)
        
        while buffer.count > 0 {
            let length = Int(buffer[0])
            let totalLength = length + 1
            
            if buffer.count >= totalLength && length > 0 {
                let frame = buffer.prefix(totalLength)
                buffer.removeFirst(totalLength)
                let bytes = [UInt8](frame)
                
                if bytes[0] == 0x1E && bytes.count == 31 {
                    var snapshot = lastTelemetry
                    snapshot.timestamp = Date()
                    // Battery %
                    snapshot.batteryPercent = Double(bytes[8])
                    // Voltage (big endian)
                    snapshot.batteryVoltage = Double(UInt16(bytes[9]) << 8 | UInt16(bytes[10])) / 100.0
                    // Speed (km/h)
                    snapshot.speedKmh = Double(bytes[13]) // Try byte 13 based on typical offset
                    // Odometer (little endian 2C 01 -> 300 -> 30.0)
                    let odo16 = Double(UInt16(bytes[23]) << 8 | UInt16(bytes[22])) / 10.0
                    snapshot.tripOdometerKm = odo16
                    // Mode
                    let modeByte = bytes[5]
                    if modeByte == 1 { snapshot.rideMode = .eco }
                    else if modeByte == 2 { snapshot.rideMode = .sport }
                    else if modeByte == 3 { snapshot.rideMode = .custom } // Race
                    
                    lastTelemetry = snapshot
                    events.append(.telemetry(snapshot))
                }
            } else if length == 0 {
                // Prevent infinite loop if buffer starts with 0
                buffer.removeFirst()
            } else {
                break
            }
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
