import SwiftUI

@main
struct KukirinManagerApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(dependencies.session)
                .environment(dependencies.preferences)
                .preferredColorScheme(dependencies.preferences.theme.colorScheme)
        }
    }
}