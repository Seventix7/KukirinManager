import Foundation

/// Raw packet capture mode — logs frames without decoding until protocol is verified.
final class DiscoveryProtocol: ScooterProtocol, @unchecked Sendable {
    let modelId: ScooterModel = .unknown
    var capabilities: ScooterCapabilities { .none }

    func identify(name: String?, advertisement: [String: Any]) -> Bool {
        false
    }

    func onConnected(session: BLEPeripheralSession?) async throws {
        PacketLogger.shared.logSystem("Discovery mode: GATT ready, awaiting frame capture")
    }

    func parseIncoming(_ data: Data) -> [ProtocolEvent] {
        guard FrameValidator.validate(data) else {
            PacketLogger.shared.logSystem("Dropped invalid frame (\(data.count) bytes)")
            return []
        }
        return [.rawFrame(data)]
    }

    func buildCommand(_ command: ScooterCommand) throws -> Data {
        throw ProtocolError.unsupportedCommand
    }
}
