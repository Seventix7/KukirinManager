import Foundation
import SwiftUI

enum SpeedUnit: String, Codable, CaseIterable, Identifiable {
    case kmh = "km/h"
    case mph = "mph"

    var id: String { rawValue }

    func convert(kmh: Double) -> Double {
        switch self {
        case .kmh: kmh
        case .mph: kmh * 0.621371
        }
    }

    var label: String { rawValue }
}

enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case celsius = "°C"
    case fahrenheit = "°F"

    var id: String { rawValue }

    func convert(celsius: Double) -> Double {
        switch self {
        case .celsius: celsius
        case .fahrenheit: celsius * 9 / 5 + 32
        }
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
final class PreferencesStore {
    var speedUnit: SpeedUnit {
        didSet { UserDefaults.standard.set(speedUnit.rawValue, forKey: Keys.speedUnit) }
    }
    var temperatureUnit: TemperatureUnit {
        didSet { UserDefaults.standard.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }
    var autoReconnect: Bool {
        didSet { UserDefaults.standard.set(autoReconnect, forKey: Keys.autoReconnect) }
    }
    var notifyOnDisconnect: Bool {
        didSet { UserDefaults.standard.set(notifyOnDisconnect, forKey: Keys.notifyOnDisconnect) }
    }
    var notifyOnLowBattery: Bool {
        didSet { UserDefaults.standard.set(notifyOnLowBattery, forKey: Keys.notifyOnLowBattery) }
    }
    var useMockProtocol: Bool {
        didSet { UserDefaults.standard.set(useMockProtocol, forKey: Keys.useMockProtocol) }
    }
    var logRetentionDays: Int {
        didSet { UserDefaults.standard.set(logRetentionDays, forKey: Keys.logRetentionDays) }
    }

    init() {
        let defaults = UserDefaults.standard
        speedUnit = SpeedUnit(rawValue: defaults.string(forKey: Keys.speedUnit) ?? "") ?? .kmh
        temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: Keys.temperatureUnit) ?? "") ?? .celsius
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        autoReconnect = defaults.object(forKey: Keys.autoReconnect) as? Bool ?? true
        notifyOnDisconnect = defaults.object(forKey: Keys.notifyOnDisconnect) as? Bool ?? true
        notifyOnLowBattery = defaults.object(forKey: Keys.notifyOnLowBattery) as? Bool ?? true
        #if targetEnvironment(simulator)
        useMockProtocol = defaults.object(forKey: Keys.useMockProtocol) as? Bool ?? true
        #else
        useMockProtocol = defaults.object(forKey: Keys.useMockProtocol) as? Bool ?? false
        #endif
        logRetentionDays = defaults.object(forKey: Keys.logRetentionDays) as? Int ?? 7
    }

    private enum Keys {
        static let speedUnit = "prefs.speedUnit"
        static let temperatureUnit = "prefs.temperatureUnit"
        static let theme = "prefs.theme"
        static let autoReconnect = "prefs.autoReconnect"
        static let notifyOnDisconnect = "prefs.notifyOnDisconnect"
        static let notifyOnLowBattery = "prefs.notifyOnLowBattery"
        static let useMockProtocol = "prefs.useMockProtocol"
        static let logRetentionDays = "prefs.logRetentionDays"
    }
}
