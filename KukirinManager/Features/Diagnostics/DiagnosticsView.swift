import SwiftUI

struct DiagnosticsView: View {
    @Environment(ScooterSession.self) private var session
    @State private var logFilter: PacketDirection?
    @State private var showExport = false
    @State private var exportText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                KGradientBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        healthSection
                        bleSection
                        errorSection
                        logSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Export as Text") { exportLogs(asJSON: false) }
                        Button("Export as JSON") { exportLogs(asJSON: true) }
                        Button("Clear Logs", role: .destructive) {
                            PacketLogger.shared.clear()
                        }
                        Button("Ping Device") {
                            session.sendCommand(.ping)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        FirmwareView()
                    } label: {
                        Label("Firmware", systemImage: "cpu")
                    }
                }
            }
            .sheet(isPresented: $showExport) {
                ShareSheet(items: [exportText])
            }
        }
    }

    private var healthSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Component Status")
                    .font(.headline)
                healthRow("Controller", session.componentHealth.controller)
                healthRow("Battery", session.componentHealth.battery)
                healthRow("Motor", session.componentHealth.motor)
                healthRow("Sensors", session.componentHealth.sensors)
            }
        }
    }

    private var bleSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Bluetooth")
                    .font(.headline)
                if let rssi = session.latestTelemetry.rssi {
                    HStack {
                        Text("Signal Quality")
                        Spacer()
                        SignalStrengthView(rssi: rssi)
                        Text("\(rssi) dBm")
                            .font(.caption.monospacedDigit())
                    }
                }
                if let latency = session.bleLatencyMs {
                    HStack {
                        Text("Latency")
                        Spacer()
                        Text(String(format: "%.0f ms", latency))
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var errorSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Error History")
                    .font(.headline)
                if session.errorHistory.isEmpty {
                    Text("No errors recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.errorHistory.prefix(10)) { error in
                        HStack(alignment: .top) {
                            Text("[\(error.code)]")
                                .font(.caption.monospaced())
                                .foregroundStyle(.red)
                            VStack(alignment: .leading) {
                                Text(error.message)
                                    .font(.caption)
                                Text(error.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var logSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Live Logs")
                        .font(.headline)
                    Spacer()
                    Picker("Filter", selection: $logFilter) {
                        Text("All").tag(PacketDirection?.none)
                        Text("TX").tag(PacketDirection?.some(.tx))
                        Text("RX").tag(PacketDirection?.some(.rx))
                        Text("System").tag(PacketDirection?.some(.system))
                    }
                    .pickerStyle(.menu)
                }
                LogConsoleView(filter: logFilter)
                    .frame(minHeight: 200)
            }
        }
    }

    private func healthRow(_ title: String, _ status: HealthStatus) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(status.rawValue)
                .font(.caption.bold())
                .foregroundStyle(color(for: status))
        }
    }

    private func color(for status: HealthStatus) -> Color {
        switch status {
        case .healthy: .green
        case .warning: .orange
        case .error: .red
        case .unknown: .gray
        }
    }

    private func exportLogs(asJSON: Bool) {
        if asJSON, let data = PacketLogger.shared.exportJSON(), let str = String(data: data, encoding: .utf8) {
            exportText = str
        } else {
            exportText = PacketLogger.shared.exportText()
        }
        showExport = true
    }
}

struct LogConsoleView: View {
    let filter: PacketDirection?
    @State private var entries: [PacketLogEntry] = []
    @State private var timer: Timer?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredEntries) { entry in
                        Text(formatEntry(entry))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(color(for: entry.direction))
                            .id(entry.id)
                    }
                }
            }
            .onAppear {
                refresh()
                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    refresh()
                }
            }
            .onDisappear { timer?.invalidate() }
            .onChange(of: entries.count) { _, _ in
                if let last = filteredEntries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var filteredEntries: [PacketLogEntry] {
        guard let filter else { return entries }
        return entries.filter { $0.direction == filter }
    }

    private func refresh() {
        entries = PacketLogger.shared.snapshot()
    }

    private func formatEntry(_ entry: PacketLogEntry) -> String {
        let time = entry.timestamp.formatted(date: .omitted, time: .standard)
        let payload = entry.hex.isEmpty ? (entry.note ?? "") : entry.hex
        return "[\(time)] \(entry.direction.rawValue.uppercased()) \(payload)"
    }

    private func color(for direction: PacketDirection) -> Color {
        switch direction {
        case .tx: .blue
        case .rx: .green
        case .system: .secondary
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
