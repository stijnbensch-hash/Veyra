import Foundation

/// Generieke schijf-cache (JSON in de Caches-map) voor IPTV-gegevens zoals
/// zenderlijsten, categorieën, VOD/series-lijsten en de EPG. Hiermee kan een
/// scherm het vorige resultaat meteen tonen bij het opstarten/heropenen,
/// terwijl er op de achtergrond stilletjes wordt ververst — zonder
/// wachttijd of laad-indicator wanneer er al gegevens bekend zijn.
nonisolated enum IPTVDiskCache {
    private static let directoryName = "IPTVCache"

    private static var directoryURL: URL? {
        guard
            let base = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first
        else {
            return nil
        }

        let url = base.appendingPathComponent(
            directoryName,
            isDirectory: true
        )

        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }

        return url
    }

    private static func fileURL(for key: String) -> URL? {
        guard let directoryURL else {
            return nil
        }

        let safeName = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        return directoryURL
            .appendingPathComponent(safeName)
            .appendingPathExtension("json")
    }

    private struct Envelope<T: Codable>: Codable {
        let savedAt: Date
        let value: T
    }

    /// Leest een gecachte waarde, ongeacht ouderdom. De aanroeper bepaalt of
    /// dit al dan niet meteen getoond wordt terwijl er ververst wordt.
    static func read<T: Codable>(
        _ type: T.Type,
        key: String
    ) -> (value: T, savedAt: Date)? {
        guard
            let fileURL = fileURL(for: key),
            let data = try? Data(contentsOf: fileURL)
        else {
            return nil
        }

        guard
            let envelope = try? JSONDecoder().decode(
                Envelope<T>.self,
                from: data
            )
        else {
            return nil
        }

        return (envelope.value, envelope.savedAt)
    }

    /// Serializes large disk decodes with writes, away from the UI thread. Pending
    /// saves finish first, so a refresh never observes an older cache value.
    static func readAsync<T: Codable & Sendable>(
        _ type: T.Type, key: String
    ) async -> (value: T, savedAt: Date)? {
        guard !Task.isCancelled else { return nil }
        let result = await withCheckedContinuation { continuation in
            writeQueue.async {
                continuation.resume(returning: read(type, key: key))
            }
        }
        return Task.isCancelled ? nil : result
    }

    private static let writeQueue = DispatchQueue(
        label: "veyra.iptv.diskcache.write",
        qos: .utility
    )

    /// Schrijft op de achtergrond, zodat het beeldscherm (bv. na het laden
    /// van een verse EPG) niet even blijft haperen door schijf-I/O.
    static func write<T: Codable & Sendable>(
        _ value: T,
        key: String
    ) {
        guard let fileURL = fileURL(for: key) else {
            return
        }

        let envelope = Envelope(
            savedAt: Date(),
            value: value
        )

        writeQueue.async {
            guard
                let data = try? JSONEncoder().encode(envelope)
            else {
                return
            }

            try? data.write(
                to: fileURL,
                options: .atomic
            )
            #if os(iOS) || os(tvOS)
            // De catalogus kan streamadressen met providergegevens bevatten.
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            #endif
        }
    }

    static func remove(key: String) {
        guard let fileURL = fileURL(for: key) else {
            return
        }
        writeQueue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Wist de volledige schijf-cache (alle providers/sleutels ineens) --
    /// voor de "Cache legen"-knop in Instellingen → Data.
    static func removeAll() {
        guard let directoryURL else { return }
        writeQueue.sync {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    static func removeAllAsync() async {
        await withCheckedContinuation { continuation in
            writeQueue.async {
                if let directoryURL { try? FileManager.default.removeItem(at: directoryURL) }
                continuation.resume()
            }
        }
    }

    /// Wacht tot eerdere achtergrondsaves klaar zijn voordat andere schermen
    /// de zojuist voorgevulde cache lezen.
    static func flush() async {
        await withCheckedContinuation { continuation in
            writeQueue.async { continuation.resume() }
        }
    }
}
