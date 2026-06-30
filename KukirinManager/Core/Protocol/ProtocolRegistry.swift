import Foundation

/// Routes discovery and protocol handling to the correct model implementation.
final class ProtocolRegistry: @unchecked Sendable {
    private let protocols: [ScooterProtocol]

    init() {
        protocols = [
            G3Protocol(),
            G4Protocol(),
            G2Protocol(),
            DiscoveryProtocol()
        ]
    }

    func identifyModel(name: String?, advertisement: [String: Any]) -> ScooterModel {
        for proto in protocols where proto.identify(name: name, advertisement: advertisement) {
            return proto.modelId
        }
        return .unknown
    }

    func isCompatible(name: String?, advertisement: [String: Any]) -> Bool {
        protocols.contains { $0.identify(name: name, advertisement: advertisement) }
    }

    func protocolFor(model: ScooterModel) -> ScooterProtocol {
        protocols.first { $0.modelId == model } ?? DiscoveryProtocol()
    }

    func protocolFor(name: String?, advertisement: [String: Any]) -> ScooterProtocol {
        protocols.first { $0.identify(name: name, advertisement: advertisement) } ?? DiscoveryProtocol()
    }
}
