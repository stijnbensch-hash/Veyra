import Foundation

struct M3UParser {
    func parse(
        _ content: String
    ) -> [IPTVChannel] {
        let lines = content
            .components(separatedBy: .newlines)

        var channels: [IPTVChannel] = []
        var pendingMetadata: M3UMetadata?

        for rawLine in lines {
            let line = rawLine
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !line.isEmpty else {
                continue
            }

            if line.hasPrefix("#EXTINF:") {
                pendingMetadata =
                    parseMetadata(line)

                continue
            }

            if line.hasPrefix("#") {
                continue
            }

            guard
                let metadata = pendingMetadata,
                let streamURL = URL(string: line),
                let scheme = streamURL.scheme?
                    .lowercased(),
                scheme == "http" ||
                    scheme == "https"
            else {
                pendingMetadata = nil
                continue
            }

            let identifier =
                metadata.tvgID
                ?? streamURL.absoluteString

            channels.append(
                IPTVChannel(
                    id: "m3u-\(identifier)",
                    name: metadata.name,
                    streamURL: streamURL,
                    logoURL: metadata.logoURL,
                    group: metadata.group,
                    tvgID: metadata.tvgID,
                    sourceType: .m3u,
                    contentType: .live
                )
            )

            pendingMetadata = nil
        }

        return channels
    }

    private func parseMetadata(
        _ line: String
    ) -> M3UMetadata {
        let name: String

        if let commaIndex =
            line.firstIndex(of: ",")
        {
            let value = line[
                line.index(after: commaIndex)...
            ]

            let trimmed =
                value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            name = trimmed.isEmpty
                ? "Onbekende zender"
                : trimmed
        } else {
            name = "Onbekende zender"
        }

        let tvgID = attribute(
            named: "tvg-id",
            in: line
        )

        let logoString = attribute(
            named: "tvg-logo",
            in: line
        )

        let group = attribute(
            named: "group-title",
            in: line
        )

        return M3UMetadata(
            name: name,
            tvgID: tvgID,
            logoURL: logoString.flatMap {
                URL(string: $0)
            },
            group: group
        )
    }

    private func attribute(
        named name: String,
        in line: String
    ) -> String? {
        let marker = "\(name)=\""

        guard
            let markerRange =
                line.range(of: marker)
        else {
            return nil
        }

        let valueStart =
            markerRange.upperBound

        guard
            let valueEnd =
                line[valueStart...]
                    .firstIndex(of: "\"")
        else {
            return nil
        }

        let value = String(
            line[valueStart..<valueEnd]
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return value.isEmpty
            ? nil
            : value
    }
}

private struct M3UMetadata {
    let name: String
    let tvgID: String?
    let logoURL: URL?
    let group: String?
}
