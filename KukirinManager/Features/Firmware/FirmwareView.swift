import SwiftUI

struct FirmwareView: View {
    @Environment(ScooterSession.self) private var session

    var body: some View {
        ZStack {
            KGradientBackground()
            ScrollView {
                VStack(spacing: 16) {
                    if let info = session.firmwareInfo {
                        firmwareCard(info)
                    } else {
                        KCard {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Requesting firmware info…")
                                    .foregroundStyle(.secondary)
                                Button("Refresh") {
                                    session.sendCommand(.requestFirmwareInfo)
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }

                    KCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Firmware Update", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            Text("Firmware flashing is not supported. This screen displays read-only version information from your scooter.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Firmware")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            session.sendCommand(.requestFirmwareInfo)
        }
    }

    private func firmwareCard(_ info: FirmwareInfo) -> some View {
        KCard {
            VStack(spacing: 12) {
                infoRow("Firmware Version", info.firmwareVersion, icon: "memorychip")
                Divider()
                infoRow("Controller", info.controllerVersion, icon: "cpu")
                Divider()
                infoRow("BLE Module", info.bleVersion, icon: "antenna.radiowaves.left.and.right")
                Divider()
                infoRow("Hardware Revision", info.hardwareRevision, icon: "wrench.and.screwdriver")
            }
        }
    }

    private func infoRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
            Spacer()
        }
    }
}
