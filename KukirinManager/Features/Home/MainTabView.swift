import SwiftUI

struct MainTabView: View {
    @Environment(ScooterSession.self) private var session
    @State private var selectedTab = 0
    @Namespace private var animation

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge.with.needle.fill") }
                .tag(1)
                .disabled(!session.isConnected)

            ControlsView()
                .tabItem { Label("Controls", systemImage: "slider.horizontal.3") }
                .tag(2)
                .disabled(!session.isConnected)

            DiagnosticsView()
                .tabItem { Label("Diagnostics", systemImage: "stethoscope") }
                .tag(3)
                .disabled(!session.isConnected)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .onChange(of: selectedTab) { _, _ in KHaptics.light() }
        .overlay {
            ConnectionSuccessOverlay(isPresented: Binding(
                get: { session.showConnectionSuccess },
                set: { session.showConnectionSuccess = $0 }
            ))
        }
        .onAppear { session.onAppear() }
        .onAppear { NotificationService.requestPermission() }
    }
}
