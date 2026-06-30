import SwiftUI

struct ControlsView: View {
    @Environment(ScooterSession.self) private var session

    var body: some View {
        NavigationStack {
            ZStack {
                KGradientBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        rideModeSection
                        slidersSection
                        togglesSection
                        pickersSection
                        if session.capabilities.passwordLock {
                            passwordSection
                        }
                        NavigationLink {
                            SpeedConfigView()
                        } label: {
                            HStack {
                                Label("Speed Configuration", systemImage: "speedometer")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
            .navigationTitle("Controls")
        }
    }

    private var rideModeSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ride Mode")
                    .font(.headline)
                KRideModePicker(
                    selection: Binding(
                        get: { session.controls.rideMode },
                        set: { session.updateRideMode($0) }
                    ),
                    availableModes: session.capabilities.rideModes
                )
            }
        }
    }

    private var slidersSection: some View {
        KCard {
            VStack(spacing: 16) {
                if session.capabilities.accelerationStrength {
                    KSliderRow(
                        title: "Acceleration",
                        value: Binding(
                            get: { Double(session.controls.accelerationStrength) },
                            set: { session.updateAcceleration(Int($0)) }
                        ),
                        range: 0...100,
                        unit: "%"
                    )
                }
                if session.capabilities.regenBraking {
                    KSliderRow(
                        title: "Regenerative Braking",
                        value: Binding(
                            get: { Double(session.controls.regenBraking) },
                            set: { session.updateRegenBraking(Int($0)) }
                        ),
                        range: 0...100,
                        unit: "%"
                    )
                }
                if session.capabilities.displayBrightness {
                    KSliderRow(
                        title: "Display Brightness",
                        value: Binding(
                            get: { Double(session.controls.displayBrightness) },
                            set: { session.updateDisplayBrightness(Int($0)) }
                        ),
                        range: 10...100,
                        unit: "%"
                    )
                }
            }
        }
    }

    private var togglesSection: some View {
        KCard {
            VStack(spacing: 0) {
                if session.capabilities.cruiseControl {
                    toggleRow("Cruise Control", icon: "cruisecontrol", isOn: cruiseBinding)
                }
                if session.capabilities.lights {
                    toggleRow("Lights", icon: "lightbulb.fill", isOn: lightsBinding)
                }
                if session.capabilities.electronicHorn {
                    toggleRow("Electronic Horn", icon: "horn.fill", isOn: hornBinding)
                }
                if session.capabilities.motorLock {
                    toggleRow("Motor Lock", icon: "lock.fill", isOn: motorLockBinding)
                }
            }
        }
    }

    private var pickersSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: 16) {
                if session.capabilities.startMode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Mode")
                            .font(.headline)
                        Picker("Start Mode", selection: startModeBinding) {
                            ForEach(StartMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if session.capabilities.autoSleepTimer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto Sleep")
                            .font(.headline)
                        Picker("Auto Sleep", selection: sleepBinding) {
                            Text("5 min").tag(5)
                            Text("10 min").tag(10)
                            Text("30 min").tag(30)
                            Text("Off").tag(0)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    private var passwordSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Password Lock")
                    .font(.headline)
                Text("Configure via official app if required by your firmware.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Enable Password Lock") {
                    session.sendCommand(.setPasswordLock(enabled: true, password: nil))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
        }
        .padding(.vertical, 8)
    }

    private var cruiseBinding: Binding<Bool> {
        Binding(
            get: { session.controls.cruiseControl },
            set: { session.sendCommand(.setCruiseControl($0)) }
        )
    }

    private var lightsBinding: Binding<Bool> {
        Binding(
            get: { session.controls.lightsOn },
            set: { session.sendCommand(.setLights($0)) }
        )
    }

    private var hornBinding: Binding<Bool> {
        Binding(
            get: { false },
            set: { session.sendCommand(.setHorn($0)) }
        )
    }

    private var motorLockBinding: Binding<Bool> {
        Binding(
            get: { session.controls.motorLocked },
            set: { session.sendCommand(.setMotorLock($0)) }
        )
    }

    private var startModeBinding: Binding<StartMode> {
        Binding(
            get: { session.controls.startMode },
            set: { session.sendCommand(.setStartMode($0)) }
        )
    }

    private var sleepBinding: Binding<Int> {
        Binding(
            get: { session.controls.autoSleepMinutes },
            set: { session.updateAutoSleep(minutes: $0) }
        )
    }
}
