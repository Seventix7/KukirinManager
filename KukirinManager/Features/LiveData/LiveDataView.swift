import SwiftUI

struct LiveDataView: View {
    @Environment(ScooterSession.self) private var session
    @Environment(PreferencesStore.self) private var preferences
    @State private var highlightedFields: Set<String> = []
    @State private var previousSnapshot = TelemetrySnapshot.empty

    var body: some View {
        ZStack {
            KGradientBackground()
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(dataRows, id: \.label) { row in
                        dataRowView(row)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Live Data")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: session.latestTelemetry) { _, newValue in
            detectChanges(from: previousSnapshot, to: newValue)
            previousSnapshot = newValue
        }
    }

    private var dataRows: [(label: String, value: String)] {
        let t = session.latestTelemetry
        var rows: [(String, String)] = [
            ("Speed", formatSpeed(t.speedKmh)),
            ("Battery", "\(Int(t.batteryPercent))%"),
            ("Voltage", String(format: "%.2f V", t.batteryVoltage)),
            ("Current", String(format: "%.2f A", t.batteryCurrent)),
            ("Motor Power", String(format: "%.0f W", t.motorPowerWatts)),
            ("Controller Power", String(format: "%.0f W", t.controllerPowerWatts)),
            ("Throttle", String(format: "%.0f%%", t.throttlePercent)),
            ("Brake", String(format: "%.0f%%", t.brakePercent)),
            ("Ride Mode", t.rideMode.rawValue),
            ("Ride Duration", formatDuration(t.rideDurationSeconds)),
            ("Trip Distance", String(format: "%.2f km", t.tripDistanceKm)),
            ("Odometer", String(format: "%.1f km", t.odometerKm))
        ]
        if let mt = t.motorTemperatureC {
            rows.append(("Motor Temp", formatTemp(mt)))
        }
        if let ct = t.controllerTemperatureC {
            rows.append(("Controller Temp", formatTemp(ct)))
        }
        if let fw = t.firmwareVersion {
            rows.append(("Firmware", fw))
        }
        if let sn = t.serialNumber {
            rows.append(("Serial", sn))
        }
        if !t.errorCodes.isEmpty {
            rows.append(("Error Codes", t.errorCodes.map(String.init).joined(separator: ", ")))
        }
        if let rssi = t.rssi {
            rows.append(("BLE RSSI", "\(rssi) dBm"))
        }
        return rows
    }

    private func dataRowView(_ row: (label: String, value: String)) -> some View {
        HStack {
            Text(row.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(row.value)
                .font(.system(.body, design: .monospaced))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            highlightedFields.contains(row.label)
                ? Color.accentColor.opacity(0.15)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .animation(KAnimation.fade, value: highlightedFields.contains(row.label))
    }

    private func detectChanges(from old: TelemetrySnapshot, to new: TelemetrySnapshot) {
        var changed: Set<String> = []
        if old.speedKmh != new.speedKmh { changed.insert("Speed") }
        if old.batteryPercent != new.batteryPercent { changed.insert("Battery") }
        if old.batteryVoltage != new.batteryVoltage { changed.insert("Voltage") }
        if old.batteryCurrent != new.batteryCurrent { changed.insert("Current") }
        highlightedFields = changed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            highlightedFields.subtract(changed)
        }
    }

    private func formatSpeed(_ kmh: Double) -> String {
        let v = preferences.speedUnit.convert(kmh: kmh)
        return String(format: "%.1f %@", v, preferences.speedUnit.label)
    }

    private func formatTemp(_ c: Double) -> String {
        let v = preferences.temperatureUnit.convert(celsius: c)
        return String(format: "%.1f%@", v, preferences.temperatureUnit.rawValue)
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return String(format: "%02d:%02d", m, sec)
    }
}
