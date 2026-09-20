import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import zlib

// Geen opgeslagen providerwachtwoorden of streamadressen in deze modellen.
nonisolated struct VeyraEPGProgramme: Identifiable, Hashable, Sendable {
    let channelID: String
    let title: String
    let subtitle: String
    let summary: String
    let start: Date
    let end: Date
    let estimatedEnd: Bool

    var id: String {
        "\(channelID)|\(start.timeIntervalSince1970)|\(title)"
    }

    func isOnAir(at date: Date) -> Bool {
        start <= date && date < end
    }
}

nonisolated struct VeyraEPGData: Sendable {
    var programmes: [String: [VeyraEPGProgramme]] = [:]
    var skipped = 0
}

nonisolated enum VeyraEPGError: LocalizedError {
    case invalidURL
    case http(Int)
    case invalidXML
    case tooLarge
    case compressedData
    case noSource

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "De EPG-bron bevat geen geldig HTTP(S)-adres."

        case .http(let code):
            return "De EPG-server antwoordde met HTTP \(code)."

        case .invalidXML:
            return "De EPG-bron is geen bruikbaar XMLTV-bestand."

        case .tooLarge:
            return "De programmagids overschrijdt de veiligheidslimiet. Gebruik een kleinere XMLTV-feed."

        case .compressedData:
            return "De gecomprimeerde programmagids kon niet worden uitgepakt."

        case .noSource:
            return "Deze M3U bevat geen url-tvg of x-tvg-url. De zenders blijven afspeelbaar, maar een aparte XMLTV-bron is nodig voor de gids."
        }
    }
}

// Gebruik alleen exact overeenkomende tvg-id's;
// geen zenders raden op naam.
actor VeyraEPGService {
    private let session: URLSession
    private let redirectGuard = VeyraEPGRedirectGuard()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false

        session = URLSession(configuration: configuration)
    }

    func discoverSource(
        in playlistURL: URL
    ) async throws -> URL {
        let downloaded = try await download(
            playlistURL,
            maximumBytes: 32 * 1_024 * 1_024
        )

        let file = downloaded.file

        defer {
            try? FileManager.default.removeItem(at: file)
        }

        let handle = try FileHandle(forReadingFrom: file)

        defer {
            try? handle.close()
        }

        // De verwijzing hoort in de EXT M3U-header te staan.
        let data = try handle.read(upToCount: 65_536) ?? Data()

        guard
            let text = String(data: data, encoding: .utf8),
            let url = Self.sourceURL(
                in: text,
                relativeTo: downloaded.origin
            )
        else {
            throw VeyraEPGError.noSource
        }

        return url
    }

    func load(
        url: URL,
        channelIDs: Set<String>,
        from: Date,
        to: Date
    ) async throws -> VeyraEPGData {
        let response = try await download(
            url,
            maximumBytes: 96 * 1_024 * 1_024
        )

        let downloaded = response.file
        var unpacked: URL?

        defer {
            try? FileManager.default.removeItem(at: downloaded)

            if let unpacked {
                try? FileManager.default.removeItem(at: unpacked)
            }
        }

        try Task.checkCancellation()

        let handle = try FileHandle(forReadingFrom: downloaded)
        let signature = try handle.read(upToCount: 2) ?? Data()
        try handle.close()

        let xml: URL

        if signature == Data([0x1f, 0x8b]) {
            let result = try VeyraEPGGzip.expand(downloaded)
            unpacked = result
            xml = result
        } else {
            xml = downloaded
        }

        try Task.checkCancellation()

        return try VeyraXMLTVReader.read(
            file: xml,
            channelIDs: channelIDs,
            from: from,
            to: to
        )
    }

    private func download(
        _ url: URL,
        maximumBytes: Int
    ) async throws -> (file: URL, origin: URL) {
        guard Self.isHTTP(url) else {
            throw VeyraEPGError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "application/xml, text/xml, */*",
            forHTTPHeaderField: "Accept"
        )

        let (file, response) = try await session.download(
            for: request,
            delegate: redirectGuard
        )

        do {
            try Task.checkCancellation()

            guard let http = response as? HTTPURLResponse else {
                throw VeyraEPGError.invalidXML
            }

            guard (200..<300).contains(http.statusCode) else {
                throw VeyraEPGError.http(http.statusCode)
            }

            let attributes = try FileManager.default.attributesOfItem(
                atPath: file.path
            )

            guard
                let size = attributes[.size] as? NSNumber,
                size.intValue <= maximumBytes
            else {
                throw VeyraEPGError.tooLarge
            }

            return (file, response.url ?? url)
        } catch {
            try? FileManager.default.removeItem(at: file)
            throw error
        }
    }

    nonisolated static func isHTTP(_ url: URL) -> Bool {
        ["https", "http"].contains(
            url.scheme?.lowercased() ?? ""
        ) && url.host != nil
    }

    nonisolated static func sourceURL(
        in text: String,
        relativeTo playlist: URL
    ) -> URL? {
        let header = text.split(whereSeparator: \.isNewline)
            .first {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(
                        in: CharacterSet(charactersIn: "\u{FEFF}")
                    )
                    .uppercased()
                    .hasPrefix("#EXTM3U")
            }
            .map(String.init) ?? ""

        let pattern =
            #"(?i)(?:url-tvg|x-tvg-url)\s*=\s*["']([^"']+)["']"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: header,
                range: NSRange(header.startIndex..., in: header)
            ),
            let range = Range(match.range(at: 1), in: header)
        else {
            return nil
        }

        // Eerste opgegeven feed.
        // Meerdere XMLTV-bronnen samenvoegen is niet ingeschakeld.
        let value = String(header[range])
            .components(separatedBy: ",")[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !value.isEmpty,
            let url = URL(
                string: value,
                relativeTo: playlist
            )?.absoluteURL,
            isHTTP(url)
        else {
            return nil
        }

        return url
    }
}

nonisolated private final class VeyraEPGRedirectGuard:
    NSObject,
    URLSessionTaskDelegate,
    @unchecked Sendable
{
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard
            let url = request.url,
            VeyraEPGService.isHTTP(url)
        else {
            completionHandler(nil)
            return
        }

        // Een beveiligde aanvraag mag niet naar HTTP omleiden.
        if response.url?.scheme?.lowercased() == "https"
            && url.scheme?.lowercased() != "https" {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}

// MARK: - XMLTV

nonisolated private final class VeyraXMLTVReader:
    NSObject,
    XMLParserDelegate
{
    private struct Draft {
        let channel: String
        let start: Date
        let end: Date?

        var title = ""
        var subtitle = ""
        var summary = ""
        var ranks: [String: Int] = [:]
    }

    private let channelIDs: Set<String>
    private let from: Date
    private let to: Date
    private let formatter: DateFormatter

    private var drafts: [String: [Draft]] = [:]
    private var current: Draft?

    private var depth = 0
    private var field: String?
    private var fieldDepth = 0
    private var fieldRank = 0
    private var text = ""

    private var rootIsTV = false
    private var rejected = false
    private var count = 0
    private var skipped = 0

    private init(
        channelIDs: Set<String>,
        from: Date,
        to: Date
    ) {
        self.channelIDs = channelIDs
        self.from = from
        self.to = to

        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        formatter.isLenient = false
    }

    static func read(
        file: URL,
        channelIDs: Set<String>,
        from: Date,
        to: Date
    ) throws -> VeyraEPGData {
        try validateXML(file)

        guard let stream = InputStream(url: file) else {
            throw VeyraEPGError.invalidXML
        }

        let reader = VeyraXMLTVReader(
            channelIDs: channelIDs,
            from: from,
            to: to
        )

        let parser = XMLParser(stream: stream)
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = reader

        let success = parser.parse()

        try Task.checkCancellation()

        guard
            success,
            parser.parserError == nil,
            reader.rootIsTV,
            !reader.rejected
        else {
            if reader.count > 250_000 {
                throw VeyraEPGError.tooLarge
            }

            throw VeyraEPGError.invalidXML
        }

        return reader.result()
    }

    private static func validateXML(_ file: URL) throws {
        // Alleen ASCII-compatibele XML, zoals UTF-8.
        // Eigen DTD-entiteiten blokkeren we ook als een platform
        // de delegate hiervoor niet aanroept.
        let handle = try FileHandle(forReadingFrom: file)

        defer {
            try? handle.close()
        }

        var tail = Data()
        var total = 0

        while let chunk = try handle.read(upToCount: 65_536),
              !chunk.isEmpty {
            try Task.checkCancellation()

            total += chunk.count

            guard total <= 192 * 1_024 * 1_024 else {
                throw VeyraEPGError.tooLarge
            }

            var check = tail
            check.append(chunk)

            guard
                !check.contains(0),
                check.range(of: Data("<!ENTITY".utf8)) == nil
            else {
                throw VeyraEPGError.invalidXML
            }

            tail = Data(check.suffix(16))
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String] = [:]
    ) {
        depth += 1

        if Task.isCancelled {
            parser.abortParsing()
            return
        }

        if depth == 1 {
            rootIsTV = elementName == "tv"

            if !rootIsTV {
                parser.abortParsing()
            }
        }

        if depth > 32 {
            rejected = true
            parser.abortParsing()
            return
        }

        if depth == 2 && elementName == "programme" {
            current = nil

            let channel = (attributes["channel"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard channelIDs.contains(channel) else {
                return
            }

            guard let start = date(attributes["start"] ?? "") else {
                skipped += 1
                return
            }

            let end = attributes["stop"].flatMap(date)

            // Extra context voor een ontbrekende eindtijd:
            // de volgende begintijd gebruiken.
            guard
                start < to.addingTimeInterval(86_400),
                (end ?? start.addingTimeInterval(172_800)) > from
            else {
                return
            }

            if let end, end <= start {
                skipped += 1
                return
            }

            current = Draft(
                channel: channel,
                start: start,
                end: end
            )
        } else if depth == 3,
                  current != nil,
                  ["title", "sub-title", "desc"].contains(elementName) {
            field = elementName
            fieldDepth = depth
            text = ""

            let lang = (attributes["lang"] ?? "").lowercased()

            fieldRank = lang.hasPrefix("nl")
                ? 0
                : lang.isEmpty
                    ? 1
                    : lang.hasPrefix("en")
                        ? 2
                        : 3
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        if field != nil && text.count < 8_000 {
            text += String(
                string.prefix(8_000 - text.count)
            )
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCDATA CDATABlock: Data
    ) {
        if let value = String(
            data: CDATABlock,
            encoding: .utf8
        ) {
            self.parser(parser, foundCharacters: value)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer {
            depth -= 1
        }

        if let field,
           depth == fieldDepth,
           elementName == field {
            let value = text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !value.isEmpty,
               var draft = current,
               fieldRank < (draft.ranks[field] ?? 99) {
                draft.ranks[field] = fieldRank

                switch field {
                case "title":
                    draft.title = String(value.prefix(300))

                case "sub-title":
                    draft.subtitle = String(value.prefix(500))

                default:
                    draft.summary = String(value.prefix(6_000))
                }

                current = draft
            }

            self.field = nil
            text = ""
        }

        if depth == 2 && elementName == "programme" {
            if let draft = current {
                drafts[draft.channel, default: []].append(draft)
                count += 1

                if count > 250_000 {
                    parser.abortParsing()
                }
            }

            current = nil
        }
    }

    func parser(
        _ parser: XMLParser,
        foundInternalEntityDeclarationWithName name: String,
        value: String?
    ) {
        rejected = true
        parser.abortParsing()
    }

    func parser(
        _ parser: XMLParser,
        resolveExternalEntityName name: String,
        systemID: String?
    ) -> Data? {
        nil
    }

    private func date(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        var digits = String(
            value.prefix(while: {
                $0.isASCII && $0.isNumber
            })
        )

        var zone = String(value.dropFirst(digits.count))
            .trimmingCharacters(in: .whitespaces)

        guard digits.count == 12 || digits.count == 14 else {
            return nil
        }

        if digits.count == 12 {
            digits += "00"
        }

        let named = [
            "": "+0000",
            "Z": "+0000",
            "UTC": "+0000",
            "GMT": "+0000",
            "BST": "+0100",
            "CET": "+0100",
            "CEST": "+0200"
        ]

        zone = named[zone.uppercased()]
            ?? zone.replacingOccurrences(of: ":", with: "")

        guard
            zone.count == 5,
            zone.first == "+" || zone.first == "-",
            zone.dropFirst().allSatisfy(\.isNumber)
        else {
            return nil
        }

        return formatter.date(
            from: "\(digits) \(zone)"
        )
    }

    private func result() -> VeyraEPGData {
        var result = VeyraEPGData(skipped: skipped)

        for (channel, values) in drafts {
            let sorted = values.sorted {
                $0.start < $1.start
            }

            let starts = Array(
                Set(sorted.map(\.start))
            )
            .sorted()

            let nextStarts = Dictionary(
                uniqueKeysWithValues: zip(
                    starts,
                    starts.dropFirst()
                )
            )

            var seen = Set<String>()

            for draft in sorted {
                let next = nextStarts[draft.start]

                guard
                    let end = draft.end ?? next,
                    end > draft.start
                else {
                    result.skipped += 1
                    continue
                }

                guard end > from && draft.start < to else {
                    continue
                }

                let programme = VeyraEPGProgramme(
                    channelID: channel,
                    title: draft.title.isEmpty
                        ? "Titel niet beschikbaar"
                        : draft.title,
                    subtitle: draft.subtitle,
                    summary: draft.summary,
                    start: draft.start,
                    end: end,
                    estimatedEnd: draft.end == nil
                )

                if seen.insert(programme.id).inserted {
                    result.programmes[channel, default: []]
                        .append(programme)
                }
            }
        }

        return result
    }
}

// MARK: - Begrensd gzip uitpakken naar een tijdelijk bestand

nonisolated private enum VeyraEPGGzip {
    static func expand(_ source: URL) throws -> URL {
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString + ".xml"
            )

        let input = try FileHandle(forReadingFrom: source)

        defer {
            try? input.close()
        }

        guard FileManager.default.createFile(
            atPath: target.path,
            contents: nil
        ) else {
            throw VeyraEPGError.compressedData
        }

        var success = false

        defer {
            if !success {
                try? FileManager.default.removeItem(at: target)
            }
        }

        let output = try FileHandle(forWritingTo: target)

        defer {
            try? output.close()
        }

        var stream = z_stream()

        guard inflateInit2_(
            &stream,
            15 + 32,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        ) == Z_OK else {
            throw VeyraEPGError.compressedData
        }

        defer {
            inflateEnd(&stream)
        }

        var buffer = [UInt8](
            repeating: 0,
            count: 65_536
        )

        var total = 0
        var ended = false

        while !ended {
            try Task.checkCancellation()

            let chunk = try input.read(upToCount: 65_536) ?? Data()

            guard !chunk.isEmpty else {
                throw VeyraEPGError.compressedData
            }

            try chunk.withUnsafeBytes { bytes in
                stream.next_in = UnsafeMutablePointer(
                    mutating: bytes.bindMemory(
                        to: UInt8.self
                    ).baseAddress!
                )

                stream.avail_in = uInt(bytes.count)

                repeat {
                    let produced: (Int32, Data) =
                        buffer.withUnsafeMutableBytes { out in
                            stream.next_out = out.bindMemory(
                                to: UInt8.self
                            ).baseAddress!

                            stream.avail_out = uInt(out.count)

                            let status = inflate(
                                &stream,
                                Z_NO_FLUSH
                            )

                            return (
                                status,
                                Data(
                                    out.prefix(
                                        out.count - Int(stream.avail_out)
                                    )
                                )
                            )
                        }

                    if produced.0 == Z_BUF_ERROR
                        && stream.avail_in == 0
                        && produced.1.isEmpty {
                        break
                    }

                    guard
                        produced.0 == Z_OK
                            || produced.0 == Z_STREAM_END
                    else {
                        throw VeyraEPGError.compressedData
                    }

                    total += produced.1.count

                    guard total <= 192 * 1_024 * 1_024 else {
                        throw VeyraEPGError.tooLarge
                    }

                    try output.write(contentsOf: produced.1)
                    try Task.checkCancellation()

                    if produced.0 == Z_STREAM_END {
                        // Meerdere aaneengeplakte gzip-streams
                        // niet stilzwijgend afkappen.
                        guard stream.avail_in == 0 else {
                            throw VeyraEPGError.compressedData
                        }

                        ended = true
                        break
                    }
                } while stream.avail_in > 0
                    || stream.avail_out == 0
            }
        }

        guard (
            try input.read(upToCount: 1) ?? Data()
        ).isEmpty else {
            throw VeyraEPGError.compressedData
        }

        success = true
        return target
    }
}
