import SwiftUI

struct SpeedConfigView: View {
    @Environment(ScooterSession.self) private var session
    @Environment(PreferencesStore.self) private var preferences
    @State private var debounceTasks: [RideMode: Task<Void, Never>] = [:]

    var body: some View {
        ZStack {
            KGradientBackground()
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(RideMode.allCases) { mode in
                        if session.capabilities.rideModes.contains(mode) {
                            modeCard(mode)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Speed Limits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modeCard(_ mode: RideMode) -> some View {
        let range = session.capabilities.speedLimitRange(for: mode)
        let binding = Binding<Double>(
            get: { session.controls.speedLimits[mode] ?? range.lowerBound },
            set: { newValue in
                debounceSpeedUpdate(mode: mode, value: newValue)
            }
        )
        return KCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: mode.iconName)
                    Text(mode.rawValue)
                        .font(.headline)
                    Spacer()
                    Text(currentDisplay(binding.wrappedValue))
                        .font(.title3.bold().monospacedDigit())
                        .contentTransition(.numericText())
                }
                Slider(value: binding, in: range, step: 1)
                    .tint(.accentColor)
                HStack {
                    Text("Min: \(Int(range.lowerBound))")
                    Spacer()
                    Text("Max: \(Int(range.upperBound))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack {
                    Text("Exact:")
                    TextField("Speed", value: binding, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    Text(preferences.speedUnit.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func currentDisplay(_ kmh: Double) -> String {
        let value = preferences.speedUnit.convert(kmh: kmh)
        return String(format: "%.0f %@", value, preferences.speedUnit.label)
    }

    private func debounceSpeedUpdate(mode: RideMode, value: Double) {
        debounceTasks[mode]?.cancel()
        debounceTasks[mode] = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                session.updateSpeedLimit(mode: mode, kmh: value)
            }
        }
    }
}
