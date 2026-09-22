import Foundation
import zlib

/// Compact snapshots keep Live TV usable on a device that cannot reach the
/// IPTV provider while another signed-in device can still refresh it.
nonisolated enum VeyraIPTVSnapshot {
    static let catalogPrefix = "veyra.iptv.catalogSnapshot."
    static let guidePrefix = "veyra.iptv.guideSnapshot."

    static func encode<T: Encodable>(_ value: T) -> Data? {
        guard let source = try? JSONEncoder().encode(value),
              source.count <= 16 * 1_024 * 1_024 else { return nil }

        var size = compressBound(uLong(source.count))
        var output = [UInt8](repeating: 0, count: Int(size) + 4)
        let result = source.withUnsafeBytes { input in
            output.withUnsafeMutableBytes { destination in
                compress2(
                    destination.baseAddress!.advanced(by: 4)
                        .assumingMemoryBound(to: Bytef.self),
                    &size,
                    input.bindMemory(to: Bytef.self).baseAddress,
                    uLong(source.count),
                    Z_BEST_COMPRESSION
                )
            }
        }
        guard result == Z_OK else { return nil }
        let length = UInt32(source.count).bigEndian
        withUnsafeBytes(of: length) { output.replaceSubrange(0..<4, with: $0) }
        return Data(output.prefix(Int(size) + 4))
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        guard data.count > 4 else { return nil }
        let length = data.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard length > 0, length <= 16 * 1_024 * 1_024 else { return nil }
        var output = [UInt8](repeating: 0, count: Int(length))
        var outputLength = uLongf(length)
        let result = data.dropFirst(4).withUnsafeBytes { input in
            output.withUnsafeMutableBytes { destination in
                uncompress(
                    destination.bindMemory(to: Bytef.self).baseAddress,
                    &outputLength,
                    input.bindMemory(to: Bytef.self).baseAddress,
                    uLong(input.count)
                )
            }
        }
        guard result == Z_OK, outputLength == length else { return nil }
        return try? JSONDecoder().decode(type, from: Data(output))
    }
}
