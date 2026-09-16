import Foundation

struct SourceMetadata: Hashable {
    let resolution: String?
    let videoCodec: String?
    let dynamicRange: [String]
    let quality: String?
    let size: String?
    let bitrate: String?
    let languages: [String]
    let audio: [String]
    let releaseName: String?
    let providerName: String?

    init(
        resolution: String? = nil,
        videoCodec: String? = nil,
        dynamicRange: [String] = [],
        quality: String? = nil,
        size: String? = nil,
        bitrate: String? = nil,
        languages: [String] = [],
        audio: [String] = [],
        releaseName: String? = nil,
        providerName: String? = nil
    ) {
        self.resolution = resolution
        self.videoCodec = videoCodec
        self.dynamicRange = dynamicRange
        self.quality = quality
        self.size = size
        self.bitrate = bitrate
        self.languages = languages
        self.audio = audio
        self.releaseName = releaseName
        self.providerName = providerName
    }
}
