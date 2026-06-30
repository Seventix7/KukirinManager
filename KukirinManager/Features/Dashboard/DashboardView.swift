import SwiftUI

struct DashboardView: View {
    @Environment(ScooterSession.self) private var session
    @Environment(PreferencesStore.self) private var preferences

    var body: some View {
        NavigationStack {
            ZStack {
                KGradientBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        speedHero
                        gaugeSection
                        metricsGrid
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        LiveDataView()
                    } label: {
                        Label("Live Data", systemImage: "waveform.path.ecg")
                    }
                }
            }
        }
    }

    private var speedHero: some View {
        VStack(spacing: 4) {
            Text(formattedSpeed)
                .font(KTheme.heroFont)
                .contentTransition(.numericText())
                .animation(KAnimation.spring, value: session.latestTelemetry.speedKmh)
            Text(preferences.speedUnit.label)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var gaugeSection: some View {
        SpeedGaugeView(
            speed: displaySpeed,
            maxSpeed: session.capabilities.speedLimitMax
        )
        .frame(height: 200)
        .padding(.horizontal, 32)
    }

    private var metricsGrid: some View {
        let t = session.latestTelemetry
        let caps = session.capabilities
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(title: "Battery", value: "\(Int(t.batteryPercent))%", icon: "battery.100percent")
            MetricCard(title: "Voltage", value: String(format: "%.1f V", t.batteryVoltage), icon: "bolt.fill")
            MetricCard(title: "Current", value: String(format: "%.1f A", t.batteryCurrent), icon: "arrow.left.arrow.right")
            MetricCard(title: "Range", value: String(format: "%.0f km", t.estimatedRangeKm(ratedRange: caps.ratedRangeKm)), icon: "map.fill")
            if caps.motorTemperature, let temp = t.motorTemperatureC {
                MetricCard(title: "Motor Temp", value: formattedTemp(temp), icon: "engine.combustion.fill")
            }
            if caps.controllerTemperature, let temp = t.controllerTemperatureC {
                MetricCard(title: "Controller", value: formattedTemp(temp), icon: "cpu.fill")
            }
            MetricCard(title: "Ride Time", value: formatDuration(t.rideDurationSeconds), icon: "clock.fill")
            MetricCard(title: "Trip", value: String(format: "%.1f km", t.tripDistanceKm), icon: "point.topleft.down.to.point.bottomright.curvepath.fill")
            MetricCard(title: "Odometer", value: String(format: "%.0f km", t.odometerKm), icon: "speedometer")
            MetricCard(title: "Mode", value: t.rideMode.rawValue, icon: t.rideMode.iconName)
            if let rssi = t.rssi {
                MetricCard(title: "BLE Signal", value: "\(rssi) dBm", icon: "antenna.radiowaves.left.and.right")
            }
        }
    }

    private var displaySpeed: Double {
        preferences.speedUnit.convert(kmh: session.latestTelemetry.speedKmh)
    }

    private var formattedSpeed: String {
        String(format: "%.0f", displaySpeed)
    }

    private func formattedTemp(_ celsius: Double) -> String {
        let value = preferences.temperatureUnit.convert(celsius: celsius)
        return String(format: "%.0f%@", value, preferences.temperatureUnit.rawValue)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
