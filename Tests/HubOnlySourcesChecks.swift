import Foundation

// De protocolsignatuur heeft dit UI/playbackmodel nodig; deze test maakt
// geen speler. Store, registry, bronvolgorde en Hub-client zijn productiecode.
struct PlayableSource: Sendable {}

final class HubFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url,
              url.host == "hub.fixture.invalid",
              request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token" else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body: String
        if url.path.hasSuffix("/streams") {
            body = #"{"streams":[{"addonID":"a","addonName":"Hub-addon A","name":"1080p","url":"https://play.fixture.invalid/a"},{"addonID":"b","addonName":"Hub-addon B","name":"720p","url":"https://play.fixture.invalid/b"}]}"#
        } else if url.path.hasSuffix("/subtitles") {
            body = #"{"subtitles":[{"addonID":"a","addonName":"Hub-addon A","lang":"nl","url":"https://play.fixture.invalid/nl.srt"}]}"#
        } else if url.path.hasSuffix("/progress") {
            body = #"{"found":true,"positionSeconds":120,"durationSeconds":3600}"#
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct HubOnlySourcesChecks {
    @MainActor static func main() async throws {
        let suite = "Veyra.HubOnlySourcesChecks.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AddonStore(defaults: defaults)
        let records = [
            AddonManifest(name: "Legacy streaming", kind: .aioStreams, baseURL: URL(string: "https://local.fixture.invalid")!),
            AddonManifest(name: "Legacy torrent", kind: .torrent, baseURL: URL(string: "https://torrent.fixture.invalid")!),
            AddonManifest(name: "Hub metadata", kind: .aioMetadata, baseURL: URL(string: "https://hub.fixture.invalid/metadata")!),
        ]
        try store.save(records)
        let originalData = defaults.data(forKey: "veyra.addons.installed")
        let registry = AddonRegistry(store: store)
        precondition(registry.registeredProviders().isEmpty, "Oude records mogen geen rechtstreekse providers activeren")
        precondition(registry.providers().isEmpty)
        precondition(registry.streamProviderNames().isEmpty)
        precondition(store.load() == records, "Metadata en gesynchroniseerde configuratie behouden")
        precondition(store.enabledAddons().contains { $0.kind == .aioMetadata })
        precondition(defaults.data(forKey: "veyra.addons.installed") == originalData)

        let oldOrder = ["iptv", "addons", "mediaServers"]
        let storedOrder = try JSONEncoder().encode(oldOrder)
        defaults.set(storedOrder, forKey: SourceOrderDefaults.categoryOrderKey)
        precondition(SourceOrderDefaults.loadCategoryOrder(from: defaults) == [.iptv, .mediaServers])
        precondition(defaults.data(forKey: SourceOrderDefaults.categoryOrderKey) == storedOrder)
        defaults.removeObject(forKey: SourceOrderDefaults.categoryOrderKey)
        precondition(SourceOrderDefaults.loadCategoryOrder(from: defaults) == [.mediaServers, .iptv])

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HubFixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let account = MediaServerAccount(name: "Hub", kind: .jellyfin,
            serverURL: URL(string: "https://hub.fixture.invalid")!, username: "fixture", userID: "fixture",
            accessToken: "fixture-token", isVeyraHub: true)
        let client = VeyraHubNativeClient(account: account, session: session)
        let episode = MediaItem(title: "Fixture", type: .series, imdbID: "tt1234567", seasonNumber: 2, episodeNumber: 3)
        let mediaID = VeyraHubNativeClient.nativeMediaID(for: episode)
        precondition(mediaID == "tt1234567:2:3")
        let streams = try await client.streams(type: .series, id: mediaID!)
        precondition(streams.map(\.addonName) == ["Hub-addon A", "Hub-addon B"], "Hub-bronnen en addonidentiteit behouden")
        // Hub-bronnen behouden hun binnenkomende volgorde zolang er geen
        // lokale Bronvolgorde is ingesteld...
        let unordered = SourceOrderDefaults.sortedByOriginOrder(streams, order: [], originName: { $0.addonName }, isFromHub: { _ in true })
        precondition(unordered == streams, "Zonder Bronvolgorde blijft de binnenkomende hub-volgorde behouden")
        // ...maar een expliciet ingestelde Bronvolgorde geldt ook voor
        // hub-addons, omdat VeyraHub's eigen API-volgorde niet altijd de op
        // VeyraHub zelf ingestelde addonvolgorde blijkt te volgen.
        let ordered = SourceOrderDefaults.sortedByOriginOrder(streams, order: ["Hub-addon B", "Hub-addon A"], originName: { $0.addonName }, isFromHub: { _ in true })
        precondition(ordered == Array(streams.reversed()), "Bronvolgorde overschrijft ook de volgorde van hub-addons")
        let subtitles = try await client.subtitles(type: .series, id: mediaID!)
        precondition(subtitles.count == 1 && subtitles[0].lang == "nl")
        let progress = try await client.progress(type: .series, id: mediaID!)
        precondition(progress.found && progress.positionSeconds == 120)
        print("PASS: oude directe addons inactief; metadata/configuratie behouden; mediaserver/IPTV-categorieën behouden; Hub-streams, volgorde, ondertitels en voortgang behouden.")
    }
}
