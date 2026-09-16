import Foundation

struct AIOStreamsMetadataParser {
    static func parse(
        name: String?,
        description: String?
    ) -> SourceMetadata {
        let name = name ?? ""
        let description = description ?? ""
        let combined = "\(name)\n\(description)"
        let uppercased = combined.uppercased()

        return SourceMetadata(
            resolution: resolution(from: uppercased),
            videoCodec: videoCodec(from: uppercased),
            dynamicRange: dynamicRange(from: uppercased),
            quality: quality(from: uppercased),
            size: size(from: description),
            bitrate: bitrate(from: description),
            languages: languages(from: description),
            audio: audio(from: description),
            releaseName: releaseName(from: description),
            providerName: providerName(from: description)
        )
    }

    private static func resolution(
        from text: String
    ) -> String? {
        if text.contains("2160P") || text.contains("4K") {
            return "4K"
        }

        if text.contains("1080P") {
            return "1080P"
        }

        if text.contains("720P") {
            return "720P"
        }

        if text.contains("480P") {
            return "480P"
        }

        return nil
    }

    private static func videoCodec(
        from text: String
    ) -> String? {
        if text.contains("HEVC") || text.contains("H.265") || text.contains("X265") {
            return "HEVC"
        }

        if text.contains("AVC") || text.contains("H.264") || text.contains("X264") {
            return "AVC"
        }

        if text.contains("AV1") {
            return "AV1"
        }

        return nil
    }

    private static func dynamicRange(
        from text: String
    ) -> [String] {
        var values: [String] = []

        if text.contains("DV") || text.contains("DOLBY VISION") {
            values.append("DV")
        }

        if text.contains("HDR10+") {
            values.append("HDR10+")
        } else if text.contains("HDR10") {
            values.append("HDR10")
        } else if text.contains("HDR") {
            values.append("HDR")
        }

        return values
    }

    private static func quality(
        from text: String
    ) -> String? {
        if text.contains("REMUX") {
            return "REMUX"
        }

        if text.contains("BLURAY") || text.contains("BLU-RAY") {
            return "BLURAY"
        }

        if text.contains("WEB-DL") || text.contains("WEBDL") {
            return "WEB-DL"
        }

        if text.contains("WEBRIP") || text.contains("WEB-RIP") {
            return "WEBRIP"
        }

        return nil
    }

    private static func size(
        from description: String
    ) -> String? {
        firstMatch(
            pattern: #"(?i)\b\d+(?:\.\d+)?\s*(?:TB|GB|MB)\b"#,
            in: description
        )
    }

    private static func bitrate(
        from description: String
    ) -> String? {
        firstMatch(
            pattern: #"(?i)\b\d+(?:\.\d+)?\s*(?:Mbps|Kbps)\b"#,
            in: description
        )
    }

    private static func languages(
        from description: String
    ) -> [String] {
        guard let line = line(
            containing: "⚑",
            in: description
        ) else {
            return []
        }

        let cleaned = line
            .replacingOccurrences(of: "⚑", with: "")
            .replacingOccurrences(of: "\\", with: "·")

        return cleaned
            .components(separatedBy: "·")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
    }

    private static func audio(
        from description: String
    ) -> [String] {
        let knownAudioTerms = [
            "ATMOS",
            "TRUEHD",
            "DTS-HD MA",
            "DTS-HD",
            "DTS",
            "EAC3",
            "DD+",
            "AC3",
            "AAC"
        ]

        let uppercased = description.uppercased()

        return knownAudioTerms.filter {
            uppercased.contains($0)
        }
    }

    private static func releaseName(
        from description: String
    ) -> String? {
        guard let line = line(
            containing: "▸",
            in: description
        ) else {
            return nil
        }

        let value = line
            .replacingOccurrences(of: "▸", with: "")
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return value.isEmpty ? nil : value
    }

    private static func providerName(
        from description: String
    ) -> String? {
        guard let line = line(
            containing: "⌕",
            in: description
        ) else {
            return nil
        }

        let value = line
            .replacingOccurrences(of: "⌕", with: "")
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return value.isEmpty ? nil : value
    }

    private static func line(
        containing marker: String,
        in text: String
    ) -> String? {
        text
            .components(separatedBy: .newlines)
            .first {
                $0.contains(marker)
            }
    }

    private static func firstMatch(
        pattern: String,
        in text: String
    ) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            text.startIndex..<text.endIndex,
            in: text
        )

        guard
            let match = regex.firstMatch(
                in: text,
                range: range
            ),
            let matchRange = Range(
                match.range,
                in: text
            )
        else {
            return nil
        }

        return String(text[matchRange])
    }
}
