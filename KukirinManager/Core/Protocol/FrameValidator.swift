import Foundation

/// Validates inbound frame structure before protocol parsing.
enum FrameValidator {
    static let minFrameLength = 4
    static let maxFrameLength = 256

    static func validate(_ data: Data) -> Bool {
        guard data.count >= minFrameLength, data.count <= maxFrameLength else {
            return false
        }
        let bytes = [UInt8](data)
        let knownHeaders: [[UInt8]] = [
            [0x5A, 0xA5],
            [0x55, 0xAA],
            [0xAA, 0x55]
        ]
        return knownHeaders.contains { header in
            bytes.count >= header.count && Array(bytes.prefix(header.count)) == header
        } || data.count >= minFrameLength
    }

    static func checksumXor(_ data: Data, excludingLast: Int = 1) -> UInt8 {
        guard data.count > excludingLast else { return 0 }
        return data.dropLast(excludingLast).reduce(0) { $0 ^ $1 }
    }
}
