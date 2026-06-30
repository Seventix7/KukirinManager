import Foundation

/// KuKirin G4 protocol — reverse-engineered from hardware captures.
/// Telemetry frame: 20 bytes, sync = byte[1] == 0x3C
/// Command format: F0 4C [cmd] [value]
final class G4Protocol: ScooterProtocol, @unchecked Sendable {
    let modelId: ScooterModel = .g4
    var capabilities: ScooterCapabilities { ScooterCapabilities.forModel(.g4) }

    private var lastTelemetry = TelemetrySnapshot.empty
    private var buffer = Data()

    func identify(name: String?, advertisement: [String: Any]) -> Bool {
        matchesModel(name: name, patterns: ScooterModel.g4.namePatterns)
            || hasAltUART(advertisement)
    }

    func onConnected(session: BLEPeripheralSession?) async throws {
        PacketLogger.shared.logSystem("G4: connected — telemetry streams automatically")
        // G4 streams telemetry without needing a request command
    }

    func parseIncoming(_ data: Data) -> [ProtocolEvent] {
        var events: [ProtocolEvent] = [.rawFrame(data)]

        buffer.append(data)

        // G4 sends 20-byte telemetry frames. Sync = byte[1] == 0x3C
        while buffer.count >= 20 {
            let bytes = [UInt8](buffer)

            guard bytes[1] == 0x3C else {
                // Out of sync — drop first byte and retry
                buffer.removeFirst()
                continue
            }

            // We have a valid 20-byte frame
            let frame = buffer.prefix(20)
            buffer.removeFirst(20)

            var snapshot = lastTelemetry
            snapshot.timestamp = Date()

            // Byte [5] — ride mode (02=eco, 03=sport, 04=race based on captures)
            snapshot.rideMode = modeFromByte(bytes[5])

            // Bytes [9][10] — battery voltage, big-endian, /100
            // e.g. 1A 89 → 0x1A89 = 6793 → 67.93V
            snapshot.batteryVoltage = Double(UInt16(bytes[9]) << 8 | UInt16(bytes[10])) / 100.0

            // Byte [18] — battery percent (decimal), e.g. 0x64 = 100%
            snapshot.batteryPercent = Double(bytes[18])

            // Bytes [15][16] — odometer in 0.1km units, little-endian
            // e.g. 49 22 → 0x2249 = 8777 → 877.7km
            let odoRaw = UInt16(bytes[16]) << 8 | UInt16(bytes[15])
            snapshot.odometerKm = Double(odoRaw) / 10.0

            // Byte [14] — flags (bit 1 = cruise control, bit 2 = lights)
            // We don't parse flags into telemetry snapshot currently

            lastTelemetry = snapshot
            events.append(.telemetry(snapshot))
        }

        return events
    }

    func buildCommand(_ command: ScooterCommand) throws -> Data {
        // G4 command format: F0 4C [cmd_id] [value]
        switch command {
        case .setRideMode(let mode):
            return Data([0xF0, 0x4C, 0x03, modeByteFor(mode)])
        case .setCruiseControl(let on):
            guard capabilities.cruiseControl else { throw ProtocolError.capabilityNotAvailable }
            return Data([0xF0, 0x4C, 0x13, on ? 0x01 : 0x00])
        case .setLights(let on):
            guard capabilities.lights else { throw ProtocolError.capabilityNotAvailable }
            return Data([0xF0, 0x4C, 0x04, on ? 0x01 : 0x00])
        case .setAccelerationStrength(let strength):
            // 0=slow, 1=normal, 2=fast
            let val = UInt8(max(0, min(2, strength / 34)))
            return Data([0xF0, 0x4C, 0x30, val])
        case .ping:
            return Data([0xF0, 0x4C, 0xFF, 0x00])
        case .requestTelemetry:
            // G4 streams automatically; no request needed. Return empty.
            return Data()
        default:
            throw ProtocolError.unsupportedCommand
        }
    }

    // MARK: - Helpers

    private func modeFromByte(_ b: UInt8) -> RideMode {
        switch b {
        case 0x02: return .eco
        case 0x03: return .sport
        case 0x04: return .race
        default:   return .eco
        }
    }

    private func modeByteFor(_ mode: RideMode) -> UInt8 {
        switch mode {
        case .eco:    return 0x02
        case .sport:  return 0x03
        case .race:   return 0x04
        case .custom: return 0x02
        }
    }

    private func matchesModel(name: String?, patterns: [String]) -> Bool {
        guard let name else { return false }
        let upper = name.uppercased()
        return patterns.contains { upper.contains($0.uppercased()) }
    }

    private func hasAltUART(_ advertisement: [String: Any]) -> Bool {
        guard let uuids = advertisement["kCBAdvDataServiceUUIDs"] as? [Any] else { return false }
        return uuids.contains { "\($0)".uppercased().contains("FFF0") }
    }
}
