import Foundation
import AetherEngine

@MainActor
final class SubtitleService {
    static let shared = SubtitleService()
    private let client = OpenSubtitlesClient()
    private var tracks: [Int: Int] = [:]
    private var generation = UUID()
    private var selectionRevision = 0
    private init() {}

    func reset() {
        generation = UUID()
        selectionRevision = 0
        tracks.removeAll()
    }
    func userSelectedTrack() { selectionRevision += 1 }

    func search(for item: MediaItem, language: SubtitleLanguage) async throws -> [OpenSubtitlesResult] {
        guard UserDefaults.standard.bool(forKey: "openSubtitlesEnabled") else {
            throw SubtitleLookupError.disabled
        }
        guard let imdbID = item.imdbID, !imdbID.isEmpty else { throw SubtitleLookupError.noIdentifier }
        return try await client.search(imdbID: imdbID, type: item.type,
                                       seasonNumber: item.seasonNumber, episodeNumber: item.episodeNumber,
                                       languages: [language.rawValue])
            .sorted { score($0) < score($1) }
    }

    func select(_ result: OpenSubtitlesResult, into engine: AetherEngine) async throws {
        userSelectedTrack()
        let revision = selectionRevision
        let session = generation
        let id = try await register(result, into: engine, session: session)
        guard generation == session, selectionRevision == revision else { return }
        engine.selectSubtitleTrack(index: id)
    }

    func loadExternalSubtitles(for item: MediaItem, into engine: AetherEngine) async {
        let preferred = SubtitlePreferences.language()
        guard UserDefaults.standard.bool(forKey: "openSubtitlesEnabled"),
              AppConfiguration.openSubtitlesAPIKey != nil,
              !engine.subtitleTracks.contains(where: { preferred.matches($0.language) }) else { return }
        let session = generation
        let revision = selectionRevision
        let initialTrack = engine.activeSubtitleTrackIndex
        do {
            let results = try await search(for: item, language: preferred)
            try Task.checkCancellation()
            // One automatic download; alternatives are downloaded only when explicitly selected.
            guard generation == session, selectionRevision == revision, let result = results.first else { return }
            let id = try await register(result, into: engine, session: session)
            guard generation == session, selectionRevision == revision,
                  engine.activeSubtitleTrackIndex == initialTrack || engine.activeSubtitleTrackIndex == id else { return }
            engine.selectSubtitleTrack(index: id)
        } catch { /* Online subtitles must never interrupt playback. Manual search shows errors. */ }
    }

    private func register(_ result: OpenSubtitlesResult, into engine: AetherEngine, session: UUID) async throws -> Int {
        guard generation == session else { throw CancellationError() }
        guard UserDefaults.standard.bool(forKey: "openSubtitlesEnabled") else { throw SubtitleLookupError.disabled }
        if let id = tracks[result.fileID] { return id }
        let revision = selectionRevision
        let url = try await client.download(fileID: result.fileID)
        try Task.checkCancellation()
        guard generation == session else { throw CancellationError() }
        guard UserDefaults.standard.bool(forKey: "openSubtitlesEnabled") else { throw SubtitleLookupError.disabled }
        if let id = tracks[result.fileID] { return id }
        // Aether reapplies preferences when registering. Preserve a manual choice made during download.
        let oldTrack = engine.activeSubtitleTrackIndex
        let wasActive = engine.isSubtitleActive
        let track = engine.addExternalSubtitleTrack(ExternalSubtitleTrack(
            url: url, name: result.displayName + " · OpenSubtitles", language: result.language))
        tracks[result.fileID] = track.id
        if selectionRevision != revision {
            if wasActive, let oldTrack { engine.selectSubtitleTrack(index: oldTrack) }
            else { engine.clearSubtitle() }
        }
        return track.id
    }
    private func score(_ value: OpenSubtitlesResult) -> Int {
        (value.hearingImpaired ? 10 : 0) + (value.forced ? 20 : 0)
    }
}

enum SubtitleLookupError: LocalizedError {
    case disabled, noIdentifier
    var errorDescription: String? {
        switch self {
        case .disabled: "Stel OpenSubtitles in via Instellingen → Account."
        case .noIdentifier: "Deze video heeft geen IMDb-identificatie om ondertitels te zoeken."
        }
    }
}
