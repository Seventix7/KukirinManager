import SwiftUI

struct SettingsView: View {
    @Environment(ScooterSession.self) private var session
    @Environment(PreferencesStore.self) private var preferences

    var body: some View {
        NavigationStack {
            ZStack {
                KGradientBackground()
                Form {
                    Section("Units") {
                        Picker("Speed", selection: Bindable(preferences).speedUnit) {
                            ForEach(SpeedUnit.allCases) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        Picker("Temperature", selection: Bindable(preferences).temperatureUnit) {
                            ForEach(TemperatureUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                    }

                    Section("Appearance") {
                        Picker("Theme", selection: Bindable(preferences).theme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                    }

                    Section("Notifications") {
                        Toggle("Disconnect Alerts", isOn: Bindable(preferences).notifyOnDisconnect)
                        Toggle("Low Battery Alerts", isOn: Bindable(preferences).notifyOnLowBattery)
                    }

                    Section("Bluetooth") {
                        Toggle("Auto Reconnect", isOn: Bindable(preferences).autoReconnect)
                        Toggle("Use Mock Data (Demo)", isOn: Bindable(preferences).useMockProtocol)
                            .onChange(of: preferences.useMockProtocol) { _, useMock in
                                if useMock {
                                    session.connectMock()
                                } else {
                                    session.disconnect()
                                }
                            }
                        Button("Forget Last Device", role: .destructive) {
                            session.forgetLastDevice()
                        }
                    }

                    Section("Privacy") {
                        LabeledContent("Data Collection", value: "On-device only")
                        Stepper("Log Retention: \(preferences.logRetentionDays) days",
                                value: Bindable(preferences).logRetentionDays,
                                in: 1...30)
                        Text("Diagnostic logs are stored locally and only exported when you choose to share them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("About") {
                        LabeledContent("App", value: "Kukirin Manager")
                        LabeledContent("Version", value: "1.0.0")
                        LabeledContent("Build", value: "1")
                        Link("Privacy Policy", destination: URL(string: "https://kukirin.global")!)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }
}
