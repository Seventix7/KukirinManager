import Foundation

/// Outbound commands sent to the scooter via the active protocol.
enum ScooterCommand: Sendable {
    case setRideMode(RideMode)
    case setAccelerationStrength(Int)
    case setRegenBraking(Int)
    case setCruiseControl(Bool)
    case setLights(Bool)
    case setHorn(Bool)
    case setDisplayBrightness(Int)
    case setAutoSleepTimer(minutes: Int)
    case setStartMode(StartMode)
    case setMotorLock(Bool)
    case setPasswordLock(enabled: Bool, password: String?)
    case setSpeedLimit(mode: RideMode, kmh: Double)
    case requestTelemetry
    case requestFirmwareInfo
    case ping
}

/// Events emitted when parsing inbound protocol frames.
enum ProtocolEvent: Sendable {
    case telemetry(TelemetrySnapshot)
    case firmwareInfo(FirmwareInfo)
    case error(code: Int, message: String)
    case rawFrame(Data)
    case pong(latencyMs: Double)
    case handshakeComplete
    case unsupported
}
