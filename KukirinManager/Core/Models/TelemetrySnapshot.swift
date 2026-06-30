import Foundation

/// Point-in-time telemetry from the connected scooter.
struct TelemetrySnapshot: Sendable, Equatable {
    var timestamp: Date
    var speedKmh: Double
    var batteryPercent: Double
    var batteryVoltage: Double
    var batteryCurrent: Double
    var motorPowerWatts: Double
    var controllerPowerWatts: Double
    var motorTemperatureC: Double?
    var controllerTemperatureC: Double?
    var throttlePercent: Double
    var brakePercent: Double
    var rideMode: RideMode
    var rideDurationSeconds: TimeInterval
    var tripDistanceKm: Double
    var odometerKm: Double
    var errorCodes: [Int]
    var firmwareVersion: String?
    var serialNumber: String?
    var rssi: Int?

    static let empty = TelemetrySnapshot(
        timestamp: Date(),
        speedKmh: 0,
        batteryPercent: 0,
        batteryVoltage: 0,
        batteryCurrent: 0,
        motorPowerWatts: 0,
        controllerPowerWatts: 0,
        motorTemperatureC: nil,
        controllerTemperatureC: nil,
        throttlePercent: 0,
        brakePercent: 0,
        rideMode: .eco,
        rideDurationSeconds: 0,
        tripDistanceKm: 0,
        odometerKm: 0,
        errorCodes: [],
        firmwareVersion: nil,
        serialNumber: nil,
        rssi: nil
    )

    func estimatedRangeKm(ratedRange: Double) -> Double {
        guard batteryPercent > 0 else { return 0 }
        return (batteryPercent / 100.0) * ratedRange * 0.92
    }
}

struct FirmwareInfo: Sendable, Equatable {
    var firmwareVersion: String
    var controllerVersion: String
    var bleVersion: String
    var hardwareRevision: String
}

struct DiscoveredDevice: Identifiable, Sendable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
    var model: ScooterModel
    var isCompatible: Bool
    var batteryPercent: Double?
    var advertisementData: [String: String]
}

struct DiagnosticError: Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let code: Int
    let message: String
}

struct ComponentHealth: Sendable, Equatable {
    var controller: HealthStatus
    var battery: HealthStatus
    var motor: HealthStatus
    var sensors: HealthStatus

    static let unknown = ComponentHealth(
        controller: .unknown,
        battery: .unknown,
        motor: .unknown,
        sensors: .unknown
    )
}

enum HealthStatus: String, Sendable {
    case healthy = "Healthy"
    case warning = "Warning"
    case error = "Error"
    case unknown = "Unknown"
}
