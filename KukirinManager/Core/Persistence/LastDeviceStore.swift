import Foundation

/// Persists the last successfully connected peripheral for auto-reconnect.
final class LastDeviceStore: Sendable {
    private let deviceIdKey = "lastDevice.id"
    private let modelKey = "lastDevice.model"
    private let nameKey = "lastDevice.name"

    func save(id: UUID, model: ScooterModel, name: String) {
        UserDefaults.standard.set(id.uuidString, forKey: deviceIdKey)
        UserDefaults.standard.set(model.rawValue, forKey: modelKey)
        UserDefaults.standard.set(name, forKey: nameKey)
    }

    func load() -> (id: UUID, model: ScooterModel, name: String)? {
        guard let idString = UserDefaults.standard.string(forKey: deviceIdKey),
              let id = UUID(uuidString: idString),
              let modelRaw = UserDefaults.standard.string(forKey: modelKey),
              let model = ScooterModel(rawValue: modelRaw),
              let name = UserDefaults.standard.string(forKey: nameKey) else {
            return nil
        }
        return (id, model, name)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: deviceIdKey)
        UserDefaults.standard.removeObject(forKey: modelKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
    }
}
