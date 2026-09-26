import Foundation

/// Haalt actuele EPG-programma's op voor de kanalen in een eigen Live TV-map
/// (`LiveTVFolder`) -- los van `VeyraEPGStore`, die zelf maar één "actieve"
/// provider tegelijk volgt (zie `VeyraEPGStore.selectProvider`). Een map kan
/// juist kanalen uit meerdere providers bevatten, dus deze loader groepeert
/// de kanalen per provider, bouwt voor elke provider zelf de xmltv-bron op
/// (dezelfde aanpak als `VeyraEPGStore.reload`) en haalt per provider maar
/// één keer de gids op -- gematcht op elk kanaal se eigen `tvgID`
/// (`ShelfIPTVChannel.tvgID`, alleen gezet voor live-kanalen).
@MainActor
final class LiveTVFolderEPGLoader: ObservableObject {
    @Published private(set) var programmesByTvgID: [String: [VeyraEPGProgramme]] = [:]
    @Published private(set) var isLoading = false

    private let epgService = VeyraEPGService()
    private let configStore = IPTVConfigurationStore()

    /// Ophalen voor alle live-kanalen in `channels` die een `tvgID` hebben.
    /// Kanalen zonder `tvgID` (VOD/series, of oudere mappen van vóór dit
    /// veld) worden gewoon overgeslagen -- die tonen dan geen "nu"-balk.
    func load(channels: [ShelfIPTVChannel]) async {
        let liveWithTvgID = channels.filter { channel in
            (channel.kind ?? .live) == .live && (channel.tvgID?.isEmpty == false)
        }
        guard !liveWithTvgID.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        guard let providers = try? configStore.loadProviders() else { return }
        let idsByProvider = Dictionary(grouping: liveWithTvgID, by: \.providerName)
            .compactMapValues { channelsForProvider -> (IPTVStoredConfiguration, Set<String>)? in
                guard let provider = providers.first(where: { $0.displayName == channelsForProvider.first?.providerName }) else {
                    return nil
                }
                let ids = Set(channelsForProvider.compactMap(\.tvgID))
                return (provider.configuration, ids)
            }

        let now = Date()
        let windowEnd = now.addingTimeInterval(6 * 3600)
        let epgService = epgService

        let merged = await withTaskGroup(of: [String: [VeyraEPGProgramme]].self) { group in
            for (_, entry) in idsByProvider {
                let (configuration, ids) = entry
                group.addTask {
                    do {
                        let source = try await Self.xmltvURL(for: configuration, epgService: epgService)
                        let data = try await epgService.load(url: source, channelIDs: ids, from: now, to: windowEnd)
                        return data.programmes
                    } catch {
                        return [:]
                    }
                }
            }

            var result: [String: [VeyraEPGProgramme]] = [:]
            for await partial in group {
                for (id, programmes) in partial {
                    result[id, default: []].append(contentsOf: programmes)
                }
            }
            return result
        }

        programmesByTvgID = merged
    }

    private static func xmltvURL(for configuration: IPTVStoredConfiguration, epgService: VeyraEPGService) async throws -> URL {
        switch configuration {
        case .xtream(let value):
            let base = value.serverURL.appendingPathComponent("xmltv.php")
            guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
                throw VeyraEPGError.invalidURL
            }
            parts.queryItems = [
                URLQueryItem(name: "username", value: value.username),
                URLQueryItem(name: "password", value: value.password)
            ]
            guard let url = parts.url else { throw VeyraEPGError.invalidURL }
            return url
        case .m3u(let value):
            return try await epgService.discoverSource(in: value.playlistURL)
        }
    }

    func currentProgramme(for channel: ShelfIPTVChannel, at date: Date = .now) -> VeyraEPGProgramme? {
        guard let tvgID = channel.tvgID else { return nil }
        return programmesByTvgID[tvgID]?.first { $0.isOnAir(at: date) }
    }

    func nextProgramme(for channel: ShelfIPTVChannel, after date: Date = .now) -> VeyraEPGProgramme? {
        guard let tvgID = channel.tvgID else { return nil }
        return programmesByTvgID[tvgID]?
            .filter { $0.start >= date }
            .min { $0.start < $1.start }
    }
}
