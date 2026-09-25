import Foundation

struct PlayableSource: Identifiable, Hashable {
    let id: UUID

    let name: String
    let description: String?

    let metadata: SourceMetadata?

    let url: URL
    let kind: SourceKind

    // Exacte zichtbare naam van de addon/provider.
    //
    // Voorbeeld:
    // "AIOStreams"
    // "PenguPlay"
    // "IPTV"
    let providerName: String?

    let requiresSoftwareVideo: Bool

    /// Present only for a source that came from a VeyraHub server's native
    /// API — carries what's needed to read back and report this title's
    /// resume position to that same hub. nil for every other source
    /// (addons, IPTV, a "real" Jellyfin/Emby server): those aren't
    /// VeyraHub-progress-synced (Trakt-based resume, via `TraktStore`,
    /// still covers them independently of this).
    let progressSync: VeyraHubProgressSync?

    /// Present only for a source that plays back a VeyraHub Recorder
    /// recording — lets `PlaybackViewModel` delete the recording from the
    /// hub once playback finishes, when "Verwijder automatisch na kijken"
    /// is on. nil for every other source.
    let recorderCleanup: VeyraHubRecorderCleanup?

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        metadata: SourceMetadata? = nil,
        url: URL,
        kind: SourceKind,
        providerName: String? = nil,
        requiresSoftwareVideo: Bool = false,
        progressSync: VeyraHubProgressSync? = nil,
        recorderCleanup: VeyraHubRecorderCleanup? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.metadata = metadata
        self.url = url
        self.kind = kind
        self.providerName = providerName
        self.requiresSoftwareVideo =
            requiresSoftwareVideo
        self.progressSync = progressSync
        self.recorderCleanup = recorderCleanup
    }
}

enum SourceKind: String, Hashable {
    case usenet
    case debrid
    case liveTV
    case direct
    case iptvVOD
}

/// What a `PlayableSource` needs to sync its resume position with the
/// VeyraHub server it came from — see `PlayableSource.progressSync`.
struct VeyraHubProgressSync: Hashable {
    let account: MediaServerAccount
    let mediaType: MediaType
    let mediaID: String
}

/// What a `PlayableSource` needs to delete its recording from the VeyraHub
/// Recorder it came from — see `PlayableSource.recorderCleanup`.
struct VeyraHubRecorderCleanup: Hashable {
    let account: MediaServerAccount
    let recordingID: String
}
