import CoreBluetooth
import Foundation

/// Known BLE service and characteristic UUIDs for e-scooter UART bridges.
enum BLEConstants {
  static let restoreIdentifier = "com.kukirin.manager.central"

  /// Nordic UART Service — common on Chinese e-scooter BLE modules.
  static let nordicUARTService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
  static let nordicUARTTX = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
  static let nordicUARTRX = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

  /// Alternative UART Service (FFF0) used by KuKirin G4
  static let altUARTService = CBUUID(string: "FFF0")
  static let altUARTTX = CBUUID(string: "FFF1")
  static let altUARTRX = CBUUID(string: "FFF2")

  static let scanDuration: TimeInterval = 12
  static let connectionTimeout: TimeInterval = 15
  static let maxReconnectAttempts = 3
  static let rssiPollInterval: TimeInterval = 1.5

  static let compatibleNameKeywords = [
    "KUKIRIN", "KUGOO", "KIRIN", "KuKirin", "Kugoo"
  ]
}
