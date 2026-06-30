import Foundation

/// Supported KuKirin scooter model identifiers.
enum ScooterModel: String, Codable, Sendable, CaseIterable, Identifiable {
    case g2 = "G2"
    case g3 = "G3"
    case g4 = "G4"
    case unknown = "Unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .g2: "KuKirin G2"
        case .g3: "KuKirin G3"
        case .g4: "KuKirin G4"
        case .unknown: "Unknown Scooter"
        }
    }

    /// Name patterns used during BLE discovery.
    var namePatterns: [String] {
        switch self {
        case .g2: ["G2", "g2", "KIRIN G2", "KuKirin G2", "Kugoo G2"]
        case .g3: ["G3", "g3", "KIRIN G3", "KuKirin G3", "Kugoo G3"]
        case .g4: ["G4", "g4", "KIRIN G4", "KuKirin G4", "Kugoo G4"]
        case .unknown: []
        }
    }
}
