import Foundation

/// Contract for model-specific scooter BLE protocol implementations.
protocol ScooterProtocol: AnyObject, Sendable {
    var modelId: ScooterModel { get }
    var capabilities: ScooterCapabilities { get }

    func identify(name: String?, advertisement: [String: Any]) -> Bool
    func onConnected(session: BLEPeripheralSession?) async throws
    func parseIncoming(_ data: Data) -> [ProtocolEvent]
    func buildCommand(_ command: ScooterCommand) throws -> Data
}

enum ProtocolError: Error, LocalizedError {
    case unsupportedCommand
    case invalidFrame
    case capabilityNotAvailable
    case handshakeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCommand: "Command not supported by this model"
        case .invalidFrame: "Invalid protocol frame"
        case .capabilityNotAvailable: "Feature not available on this scooter"
        case .handshakeFailed(let msg): "Handshake failed: \(msg)"
        }
    }
}
