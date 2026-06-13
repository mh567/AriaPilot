import Foundation

enum Fmt {
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        return f
    }()

    static func bytes(_ value: Int64) -> String {
        byteFormatter.string(fromByteCount: value)
    }

    static func speed(_ bytesPerSec: Int64) -> String {
        "\(bytes(bytesPerSec))/s"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
