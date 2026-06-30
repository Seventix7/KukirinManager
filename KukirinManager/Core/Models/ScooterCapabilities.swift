import Foundation

/// Feature flags describing what the connected scooter supports.
struct ScooterCapabilities: Sendable, Equatable {
    var isConnectableForTelemetry: Bool
    var rideModes: Set<RideMode>
    var motorTemperature: Bool
    var controllerTemperature: Bool
    var electronicHorn: Bool
    var passwordLock: Bool
    var cruiseControl: Bool
    var motorLock: Bool
    var lights: Bool
    var regenBraking: Bool
    var accelerationStrength: Bool
    var displayBrightness: Bool
    var autoSleepTimer: Bool
    var startMode: Bool
    var speedLimitConfiguration: Bool
    var firmwareUpdate: Bool
    var speedLimitMin: Double
    var speedLimitMax: Double
    var ratedRangeKm: Double

    static let none = ScooterCapabilities(
        isConnectableForTelemetry: false,
        rideModes: [],
        motorTemperature: false,
        controllerTemperature: false,
        electronicHorn: false,
        passwordLock: false,
        cruiseControl: false,
        motorLock: false,
        lights: false,
        regenBraking: false,
        accelerationStrength: false,
        displayBrightness: false,
        autoSleepTimer: false,
        startMode: false,
        speedLimitConfiguration: false,
        firmwareUpdate: false,
        speedLimitMin: 10,
        speedLimitMax: 25,
        ratedRangeKm: 40
    )

    static let mock = ScooterCapabilities(
        isConnectableForTelemetry: true,
        rideModes: Set(RideMode.allCases),
        motorTemperature: true,
        controllerTemperature: true,
        electronicHorn: true,
        passwordLock: true,
        cruiseControl: true,
        motorLock: true,
        lights: true,
        regenBraking: true,
        accelerationStrength: true,
        displayBrightness: true,
        autoSleepTimer: true,
        startMode: true,
        speedLimitConfiguration: true,
        firmwareUpdate: false,
        speedLimitMin: 10,
        speedLimitMax: 65,
        ratedRangeKm: 55
    )

    static func forModel(_ model: ScooterModel) -> ScooterCapabilities {
        switch model {
        case .g2:
            return ScooterCapabilities(
                isConnectableForTelemetry: true,
                rideModes: [.eco, .sport, .race],
                motorTemperature: false,
                controllerTemperature: true,
                electronicHorn: false,
                passwordLock: false,
                cruiseControl: true,
                motorLock: true,
                lights: true,
                regenBraking: true,
                accelerationStrength: true,
                displayBrightness: true,
                autoSleepTimer: true,
                startMode: true,
                speedLimitConfiguration: true,
                firmwareUpdate: false,
                speedLimitMin: 10,
                speedLimitMax: 50,
                ratedRangeKm: 45
            )
        case .g3:
            return ScooterCapabilities(
                isConnectableForTelemetry: true,
                rideModes: Set(RideMode.allCases),
                motorTemperature: true,
                controllerTemperature: true,
                electronicHorn: true,
                passwordLock: true,
                cruiseControl: true,
                motorLock: true,
                lights: true,
                regenBraking: true,
                accelerationStrength: true,
                displayBrightness: true,
                autoSleepTimer: true,
                startMode: true,
                speedLimitConfiguration: true,
                firmwareUpdate: false,
                speedLimitMin: 10,
                speedLimitMax: 65,
                ratedRangeKm: 55
            )
        case .g4:
            return ScooterCapabilities(
                isConnectableForTelemetry: true,
                rideModes: [.eco, .sport, .race, .custom],
                motorTemperature: true,
                controllerTemperature: true,
                electronicHorn: false,
                passwordLock: false,
                cruiseControl: true,
                motorLock: true,
                lights: true,
                regenBraking: true,
                accelerationStrength: true,
                displayBrightness: true,
                autoSleepTimer: true,
                startMode: true,
                speedLimitConfiguration: true,
                firmwareUpdate: false,
                speedLimitMin: 15,
                speedLimitMax: 70,
                ratedRangeKm: 75
            )
        case .unknown:
            return .none
        }
    }

    func speedLimitRange(for mode: RideMode) -> ClosedRange<Double> {
        guard rideModes.contains(mode) else { return 0...0 }
        return speedLimitMin...speedLimitMax
    }
}
