import Foundation

enum PacketDirection: String, Sendable, Codable {
    case tx
    case rx
    case system
}

struct PacketLogEntry: Identifiable, Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let direction: PacketDirection
    let hex: String
    let note: String?

    init(direction: PacketDirection, data: Data, note: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.direction = direction
        self.hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        self.note = note
    }

    init(direction: PacketDirection, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.direction = direction
        self.hex = ""
        self.note = message
    }
}

/// Thread-safe ring buffer for BLE packet logging and diagnostic export.
final class PacketLogger: @unchecked Sendable {
    static let shared = PacketLogger()
    private let queue = DispatchQueue(label: "ble.packet.logger")
    private var entries: [PacketLogEntry] = []
    private let maxEntries = 10_000

    private init() {}

    func log(direction: PacketDirection, data: Data, note: String? = nil) {
        queue.async {
            self.entries.append(PacketLogEntry(direction: direction, data: data, note: note))
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    func logSystem(_ message: String) {
        queue.async {
            self.entries.append(PacketLogEntry(direction: .system, message: message))
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    func snapshot() -> [PacketLogEntry] {
        queue.sync { entries }
    }

    func exportText() -> String {
        let lines = snapshot().map { entry in
            let time = ISO8601DateFormatter().string(from: entry.timestamp)
            let payload = entry.hex.isEmpty ? (entry.note ?? "") : entry.hex
            return "[\(time)] \(entry.direction.rawValue.uppercased()): \(payload)"
        }
        return lines.joined(separator: "\n")
    }

    func exportJSON() -> Data? {
        try? JSONEncoder().encode(snapshot())
    }

    func clear() {
        queue.async { self.entries.removeAll() }
    }
}
