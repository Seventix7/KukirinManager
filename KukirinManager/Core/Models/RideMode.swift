import Foundation

/// Riding mode presets exposed by the scooter controller.
enum RideMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case eco = "Eco"
    case drive = "Drive"
    case sport = "Sport"
    case custom = "Custom"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .eco: "leaf.fill"
        case .drive: "car.fill"
        case .sport: "bolt.fill"
        case .custom: "slider.horizontal.3"
        }
    }
}

/// Kick-start vs zero-start configuration.
enum StartMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case kickStart = "Kick Start"
    case zeroStart = "Zero Start"

    var id: String { rawValue }
}
