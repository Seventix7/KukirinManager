import Foundation

/// KuKirin G2 protocol — extend as packet formats are verified on hardware.
final class G2Protocol: ScooterProtocol, @unchecked Sendable {
    let modelId: ScooterModel = .g2
    var capabilities: ScooterCapabilities { ScooterCapabilities.forModel(.g2) }

    private var telemetryBuffer = Data()
    private var lastTelemetry = TelemetrySnapshot.empty

    func identify(name: String?, advertisement: [String: Any]) -> Bool {
        matchesModel(name: name, patterns: ScooterModel.g2.namePatterns)
            || hasNordicUART(advertisement)
    }

    func onConnected(session: BLEPeripheralSession?) async throws {
        PacketLogger.shared.logSystem("G2: connected, awaiting verified handshake")
        guard let session else { return }
        try await requestInitialTelemetry(session: session)
    }

    func parseIncoming(_ data: Data) -> [ProtocolEvent] {
        guard FrameValidator.validate(data) else { return [] }
        telemetryBuffer.append(data)
        var events: [ProtocolEvent] = []
        events.append(.rawFrame(data))
        if let snapshot = tryParseTelemetry(data) {
            lastTelemetry = snapshot
            events.append(.telemetry(snapshot))
        }
        return events
    }

    func buildCommand(_ command: ScooterCommand) throws -> Data {
        switch command {
        case .setRideMode(let mode):
            return buildFrame(opcode: 0x10, payload: [UInt8(modeIndex(mode))])
        case .setLights(let on):
            guard capabilities.lights else { throw ProtocolError.capabilityNotAvailable }
            return buildFrame(opcode: 0x11, payload: [on ? 1 : 0])
        case .setSpeedLimit(let mode, let kmh):
            guard capabilities.speedLimitConfiguration else { throw ProtocolError.capabilityNotAvailable }
            let speedByte = UInt8(min(max(kmh, capabilities.speedLimitMin), capabilities.speedLimitMax))
            return buildFrame(opcode: 0x12, payload: [UInt8(modeIndex(mode)), speedByte])
        case .requestTelemetry:
            return buildFrame(opcode: 0x01, payload: [])
        case .ping:
            return buildFrame(opcode: 0xFE, payload: [])
        default:
            throw ProtocolError.unsupportedCommand
        }
    }

  // MARK: - Frame helpers (verify opcodes against captured G2 packets)

    private func buildFrame(opcode: UInt8, payload: [UInt8]) -> Data {
        var frame: [UInt8] = [0x5A, 0xA5, UInt8(payload.count + 1), opcode]
        frame.append(contentsOf: payload)
        let checksum = frame.reduce(0) { $0 ^ $1 }
        frame.append(checksum)
        return Data(frame)
    }

    private func tryParseTelemetry(_ data: Data) -> TelemetrySnapshot? {
        let bytes = [UInt8](data)
        guard bytes.count >= 8, bytes[0] == 0x5A, bytes[1] == 0xA5 else { return nil }
        var snapshot = lastTelemetry
        snapshot.timestamp = Date()
        if bytes.count >= 12 {
            snapshot.speedKmh = Double(bytes[4])
            snapshot.batteryPercent = Double(bytes[5])
            snapshot.batteryVoltage = Double(bytes[6]) / 10.0 + 40
            snapshot.rideMode = modeFromIndex(bytes[7])
        }
        return snapshot
    }

    private func requestInitialTelemetry(session: BLEPeripheralSession) async throws {
        let frame = try buildCommand(.requestTelemetry)
        await MainActor.run { session.write(frame) }
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
        case .sport: 1
        case .race: 2
        case .custom: 3
        }
    }

    private func modeFromIndex(_ index: UInt8) -> RideMode {
        switch index {
        case 0: .eco
        case 1: .sport
        case 2: .race
        default: .custom
        }
    }
}
