import Foundation

nonisolated struct OpenSubtitlesSearchResponse:
    Decodable
{
    let data: [OpenSubtitlesSubtitle]
}

nonisolated struct OpenSubtitlesSubtitle:
    Decodable,
    Identifiable
{
    let id: String
    let type: String?
    let attributes: Attributes

    nonisolated struct Attributes:
        Decodable
    {
        let language: String?
        let hearingImpaired: Bool?
        let forced: Bool?
        let release: String?
        let uploader: Uploader?
        let files: [File]

        enum CodingKeys:
            String,
            CodingKey
        {
            case language
            case hearingImpaired =
                "hearing_impaired"
            case forced
            case release
            case uploader
            case files
        }
    }

    nonisolated struct Uploader:
        Decodable
    {
        let name: String?
    }

    nonisolated struct File:
        Decodable,
        Identifiable
    {
        let fileID: Int
        let fileName: String?

        var id: Int {
            fileID
        }

        enum CodingKeys:
            String,
            CodingKey
        {
            case fileID =
                "file_id"
            case fileName =
                "file_name"
        }
    }
}

nonisolated struct OpenSubtitlesDownloadRequest:
    Encodable
{
    let fileID: Int

    enum CodingKeys:
        String,
        CodingKey
    {
        case fileID =
            "file_id"
    }
}

nonisolated struct OpenSubtitlesDownloadResponse:
    Decodable
{
    let link: URL
    let fileName: String?

    enum CodingKeys:
        String,
        CodingKey
    {
        case link
        case fileName =
            "file_name"
    }
}

nonisolated struct OpenSubtitlesResult:
    Identifiable,
    Hashable
{
    let id: String
    let fileID: Int
    let language: String
    let displayLanguage: String
    let name: String
    let hearingImpaired: Bool
    let forced: Bool

    var displayName: String {
        var parts: [String] = [
            displayLanguage
        ]

        if hearingImpaired {
            parts.append("SDH")
        }

        if forced {
            parts.append("Forced")
        }

        return parts.joined(
            separator: " · "
        )
    }
}
