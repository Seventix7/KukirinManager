import Foundation

/// BLE connection lifecycle states.
enum ConnectionState: Equatable, Sendable {
    case idle
    case scanning
    case connecting
    case discovering
    case handshaking
    case connected
    case reconnecting(attempt: Int)
    case disconnected
    case failed(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isActive: Bool {
        switch self {
        case .connecting, .discovering, .handshaking, .connected, .reconnecting:
            return true
        default:
            return false
        }
    }

    var displayTitle: String {
        switch self {
        case .idle: "Ready"
        case .scanning: "Scanning…"
        case .connecting: "Connecting…"
        case .discovering: "Discovering services…"
        case .handshaking: "Handshaking…"
        case .connected: "Connected"
        case .reconnecting(let attempt): "Reconnecting (\(attempt))…"
        case .disconnected: "Disconnected"
        case .failed(let message): "Failed: \(message)"
        }
    }
}
