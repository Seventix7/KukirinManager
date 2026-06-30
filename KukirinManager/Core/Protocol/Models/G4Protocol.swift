import Foundation

// MARK: - KuKirin G4 Protocol
// Reverse-engineered from FFF2 BLE notifications.
//
// FFF2 sends two frame types interleaved:
//
// Frame A (11 bytes): byte[1] = 0x00
//   [SPD_LIMIT] [00] [2C] [01] [81] [17] [22] [20] [MOTOR_SPD] [00] [01]
//   • byte[0]  = speed limit km/h
//   • byte[8]  = motor/wheel speed in 0.5 km/h units
//
// Frame B (20 bytes): byte[1] = 0x3C  ← main telemetry
//   [SPD_LIMIT] [3C] [00] [SL-13] [00] [MODE] [SPD_LO] [SPD_HI]
//   [CURR] [V_HI] [V_LO] [00] [00] [00] [FLAGS] [ODO_LO] [ODO_HI]
//   [50] [BATT%] [00]
//   • byte[0]     = speed limit km/h (0x1E=30, 0x23=35, 0x28=40)
//   • byte[5]     = mode (0x01=Eco, 0x02=Sport, 0x03=Race)
//   • bytes[6][7] = speed little-endian, /10 → km/h
//   • bytes[9][10]= voltage big-endian, /100 → V
//   • byte[14]    = flags: 0x20=normal, 0x22=cruise-off, 0x26=cruise-on
//   • bytes[15][16]=odometer little-endian, /10 → km
//   • byte[18]    = battery percent (decimal)

final class G4Protocol: ScooterProtocol, @unchecked Sendable {
    let modelId: ScooterModel = .g4
    var capabilities: ScooterCapabilities { ScooterCapabilities.forModel(.g4) }

    private var lastTelemetry = TelemetrySnapshot.empty

    func identify(name: String?, advertisement: [String: Any]) -> Bool {
        matchesModel(name: name, patterns: ScooterModel.g4.namePatterns)
            || hasAltUART(advertisement)
    }

    func onConnected(session: BLEPeripheralSession?) async throws {
        PacketLogger.shared.logSystem("G4: connected — streaming telemetry on FFF2")
        // G4 streams automatically, no request needed
    }

    func parseIncoming(_ data: Data) -> [ProtocolEvent] {
        let bytes = [UInt8](data)
        var events: [ProtocolEvent] = [.rawFrame(data)]

        // Frame B: 20 bytes, byte[1] == 0x3C — main telemetry (NO speed here)
        if bytes.count == 20 && bytes[1] == 0x3C {
            var snapshot = lastTelemetry
            snapshot.timestamp = Date()

            // Ride mode — byte[5]: 0x01=Eco, 0x02=Sport, 0x03=Race
            snapshot.rideMode = modeFromByte(bytes[5])

            // Battery voltage — bytes[9][10] big-endian, /100 → V
            let rawVolt = UInt16(bytes[9]) << 8 | UInt16(bytes[10])
            snapshot.batteryVoltage = Double(rawVolt) / 100.0

            // Battery percent — byte[18] decimal (e.g. 100 = 100%)
            snapshot.batteryPercent = Double(bytes[18])

            // Odometer — bytes[15][16] little-endian, /10 → km
            let rawOdo = UInt16(bytes[16]) << 8 | UInt16(bytes[15])
            snapshot.odometerKm = Double(rawOdo) / 10.0

            // Motor RPM proxy — bytes[6][7] little-endian
            // Stored in motorPowerWatts field for dashboard display as "motor speed"
            let rawRPM = UInt16(bytes[7]) << 8 | UInt16(bytes[6])
            snapshot.motorPowerWatts = Double(rawRPM)

            lastTelemetry = snapshot
            events.append(.telemetry(snapshot))
        }

        // Frame A: 11 bytes, byte[1] == 0x00 — contains WHEEL SPEED
        // byte[8] × 0.5 = speed in km/h (confirmed: 90 × 0.5 = 45 km/h)
        else if bytes.count == 11 && bytes[1] == 0x00 {
            var snapshot = lastTelemetry
            snapshot.timestamp = Date()
            snapshot.speedKmh = Double(bytes[8]) * 0.5
            lastTelemetry = snapshot
            events.append(.telemetry(snapshot))
        }

        return events
    }

    func buildCommand(_ command: ScooterCommand) throws -> Data {
        // G4 command format: F0 4C [cmd] [value]
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
            // strength 0..100 → G4 values: 0x01=slow, 0x02=fast
            let val: UInt8 = strength >= 50 ? 0x02 : 0x01
            return Data([0xF0, 0x4C, 0x30, val])

        case .setStartMode(let mode):
            // F0 4C 02 00 = ZeroStart ON, F0 4C 02 01 = KickStart
            return Data([0xF0, 0x4C, 0x02, mode == .zeroStart ? 0x00 : 0x01])

        case .ping:
            return Data([0xF0, 0x4C, 0xFF, 0x00])

        case .requestTelemetry:
            // G4 streams automatically; send empty data (won't be written)
            return Data()

        default:
            throw ProtocolError.unsupportedCommand
        }
    }

    // MARK: - Helpers

    private func modeFromByte(_ b: UInt8) -> RideMode {
        switch b {
        case 0x01: return .eco
        case 0x02: return .sport
        case 0x03: return .race
        default:   return .eco
        }
    }

    private func modeByteFor(_ mode: RideMode) -> UInt8 {
        switch mode {
        case .eco:    return 0x01
        case .sport:  return 0x02
        case .race:   return 0x03
        case .custom: return 0x01
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
