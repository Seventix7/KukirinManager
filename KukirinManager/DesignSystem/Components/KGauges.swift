import SwiftUI

struct ConnectionStatusBadge: View {
    let state: ConnectionState
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .scaleEffect(pulse && state == .scanning ? 1.4 : 1)
                .opacity(pulse && state == .scanning ? 0.5 : 1)
                .animation(
                    state == .scanning ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )
            Text(state.displayTitle)
                .font(KTheme.captionFont)
                .foregroundStyle(.secondary)
        }
        .onAppear { pulse = true }
        .onChange(of: state) { _, _ in
            if state.isConnected { KHaptics.success() }
        }
    }

    private var statusColor: Color {
        switch state {
        case .connected: .green
        case .scanning, .connecting, .discovering, .handshaking, .reconnecting: .orange
        case .failed: .red
        default: .gray
        }
    }
}

struct SignalStrengthView: View {
    let rssi: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < barCount ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(6 + index * 4))
            }
        }
        .accessibilityLabel("Signal strength \(barCount) of 4")
    }

    private var barCount: Int {
        switch rssi {
        case ..<(-80): 1
        case -80..<(-70): 2
        case -70..<(-60): 3
        default: 4
        }
    }
}

struct BatteryIndicatorView: View {
    let percent: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: batterySymbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(batteryColor)
                .contentTransition(.symbolEffect(.replace))
            Text("\(Int(percent))%")
                .font(KTheme.captionFont)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .animation(KAnimation.spring, value: percent)
    }

    private var batterySymbol: String {
        switch percent {
        case ..<10: "battery.0percent"
        case ..<35: "battery.25percent"
        case ..<65: "battery.50percent"
        case ..<90: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private var batteryColor: Color {
        percent < 20 ? .red : (percent < 40 ? .orange : .green)
    }
}

struct SpeedGaugeView: View {
    let speed: Double
    let maxSpeed: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 16)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.green, .yellow, .orange, .red],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(KAnimation.spring, value: progress)
            VStack(spacing: 4) {
                Text("\(Int(speed))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("km/h")
                    .font(KTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var progress: CGFloat {
        guard maxSpeed > 0 else { return 0 }
        return CGFloat(min(speed / maxSpeed, 1))
    }
}

struct KSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    var onCommit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Slider(value: $value, in: range, step: 1) { editing in
                if !editing { onCommit?() }
            }
            .tint(.accentColor)
        }
    }
}

struct KRideModePicker: View {
    @Binding var selection: RideMode
    let availableModes: Set<RideMode>

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RideMode.allCases) { mode in
                if availableModes.contains(mode) {
                    Button {
                        KHaptics.light()
                        withAnimation(KAnimation.spring) { selection = mode }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.iconName)
                                .font(.title3)
                            Text(mode.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selection == mode ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selection == mode ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ConnectionSuccessOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: isPresented)
                    Text("Connected")
                        .font(.title2.bold())
                    Text("Your scooter is ready to ride")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .transition(.scale.combined(with: .opacity))
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dismiss() }
            }
        }
    }

    private func dismiss() {
        withAnimation(KAnimation.spring) { isPresented = false }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        KCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(value)
                    .font(KTheme.metricFont)
                    .contentTransition(.numericText())
                Text(title)
                    .font(KTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
