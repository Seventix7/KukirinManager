# Kukirin Manager

Native iOS 17+ SwiftUI application for connecting to KuKirin G2, G3, and G4 electric scooters via Bluetooth Low Energy.

## Requirements

- macOS with Xcode 15+
- iOS 17+ device (Bluetooth does not work in Simulator for real scooters)
- Physical KuKirin scooter for protocol verification

## Open in Xcode

```bash
open KukirinManager.xcodeproj
```

Set your **Development Team** in Signing & Capabilities, then build and run on a physical iPhone.

## Features

- **Home** — Auto-scan, nearby scooter list, connection management
- **Dashboard** — Live speed gauge, battery, range, temperatures, odometer
- **Controls** — Ride modes, acceleration, regen, lights, cruise control, motor lock
- **Speed Configuration** — Per-mode speed limits with sliders and numeric input
- **Live Data** — Real-time telemetry stream with change highlighting
- **Diagnostics** — Component health, BLE latency, error history, packet logs, export
- **Firmware** — Read-only version information (no flashing)
- **Settings** — Units, theme, auto-reconnect, mock demo mode

## Architecture

- SwiftUI + MVVM (`@Observable`)
- CoreBluetooth central role with Nordic UART service
- Modular protocol layer: `G2Protocol`, `G3Protocol`, `G4Protocol`, `DiscoveryProtocol`, `MockScooterProtocol`
- Packet capture in Diagnostics for reverse-engineering verification

## Protocol Development

Protocol opcodes are **placeholders** until verified against your hardware:

1. Connect to scooter via the app
2. Open **Diagnostics → Live Logs**
3. Export captured TX/RX frames
4. Map opcodes in `G2Protocol.swift`, `G3Protocol.swift`, or `G4Protocol.swift`
5. Update `ScooterCapabilities` per verified feature

## Mock Mode

Enable **Settings → Use Mock Data (Demo)** to explore the full UI without a scooter. Mock mode is enabled by default in Simulator.

## Privacy

All data stays on-device. Diagnostic logs export only when you explicitly share them.

## License

Copyright © 2026. All rights reserved.
