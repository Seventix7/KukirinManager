import SwiftUI

@MainActor
@Observable
final class AppDependencies {
    let preferences = PreferencesStore()
    let session: ScooterSession

    init() {
        session = ScooterSession(preferences: preferences)
    }
}
