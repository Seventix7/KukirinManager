import Foundation

@MainActor
final class ReconnectService {
    private let lastDeviceStore: LastDeviceStore
    private let preferences: PreferencesStore

    init(lastDeviceStore: LastDeviceStore, preferences: PreferencesStore) {
        self.lastDeviceStore = lastDeviceStore
        self.preferences = preferences
    }

    func shouldAttemptReconnect() -> UUID? {
        guard preferences.autoReconnect,
              let saved = lastDeviceStore.load() else { return nil }
        return saved.id
    }
}
