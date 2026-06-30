import Foundation

/// Coordinates connection state transitions and reconnect logic.
@MainActor
final class ConnectionCoordinator {
    var state: ConnectionState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ConnectionState) -> Void)?
    private var reconnectAttempt = 0

    func beginScan() {
        state = .scanning
    }

    func beginConnect() {
        state = .connecting
        reconnectAttempt = 0
    }

    func beginDiscover() {
        state = .discovering
    }

    func beginHandshake() {
        state = .handshaking
    }

    func markConnected() {
        reconnectAttempt = 0
        state = .connected
    }

    func markDisconnected() {
        state = .disconnected
    }

    func markIdle() {
        state = .idle
    }

    func markFailed(_ message: String) {
        state = .failed(message)
    }

    func beginReconnect() -> Bool {
        reconnectAttempt += 1
        guard reconnectAttempt <= BLEConstants.maxReconnectAttempts else {
            state = .disconnected
            return false
        }
        state = .reconnecting(attempt: reconnectAttempt)
        return true
    }

    func reset() {
        reconnectAttempt = 0
        state = .idle
    }
}
