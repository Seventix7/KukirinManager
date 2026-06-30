import SwiftUI

struct HomeView: View {
    @Environment(ScooterSession.self) private var session
    @Namespace private var heroNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                KGradientBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        connectionCard
                        if !session.discoveredDevices.isEmpty {
                            nearbyList
                        } else if session.connectionState == .scanning {
                            KSkeletonLoader()
                                .frame(height: 120)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Kukirin Manager")
            .refreshable { session.startScan() }
        }
    }

    private var connectionCard: some View {
        KCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundStyle(.accent)
                    VStack(alignment: .leading) {
                        Text("Bluetooth")
                            .font(.headline)
                        ConnectionStatusBadge(state: session.connectionState)
                    }
                    Spacer()
                    if let device = session.connectedDevice {
                        BatteryIndicatorView(percent: session.latestTelemetry.batteryPercent)
                            .opacity(device.batteryPercent != nil || session.isConnected ? 1 : 0)
                    }
                }

                if session.isConnected, let device = session.connectedDevice {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.title3.bold())
                            Text(device.model.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let rssi = session.latestTelemetry.rssi {
                            SignalStrengthView(rssi: rssi)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(spacing: 12) {
                    if session.isConnected {
                        KSecondaryButton("Disconnect", icon: "xmark.circle") {
                            session.disconnect()
                        }
                    } else {
                        KPrimaryButton("Scan", icon: "dot.radiowaves.left.and.right") {
                            session.startScan()
                        }
                        if let first = session.discoveredDevices.first(where: { $0.isCompatible }) {
                            KPrimaryButton("Connect", icon: "link") {
                                session.connect(to: first)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .animation(KAnimation.spring, value: session.connectionState)
        .matchedHero(id: "connectionCard", in: heroNamespace)
    }

    private var nearbyList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearby Scooters")
                .font(.headline)
                .padding(.horizontal)

            ForEach(session.discoveredDevices) { device in
                deviceRow(device)
            }
        }
    }

    private func deviceRow(_ device: DiscoveredDevice) -> some View {
        KCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.name)
                            .font(.headline)
                        if device.isCompatible {
                            Text(device.model.rawValue)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                        }
                    }
                    HStack(spacing: 12) {
                        SignalStrengthView(rssi: device.rssi)
                        Text("\(device.rssi) dBm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !session.isConnected {
                    Button("Connect") {
                        session.connect(to: device)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal)
    }
}
