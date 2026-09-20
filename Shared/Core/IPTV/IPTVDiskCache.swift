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
        }
    }

    static func remove(key: String) {
        guard let fileURL = fileURL(for: key) else {
            return
        }

        try? FileManager.default.removeItem(at: fileURL)
    }
}
