import SwiftUI

/// Programmatijd voor een live stream. Deze balk is bewust niet bedienbaar:
/// een XMLTV-uitzending zegt niets over de seekmogelijkheden van de stream.
struct LivePlayerEPGTimeline: View {
    let source: PlayableSource
    @StateObject private var guide: LivePlayerEPGModel

    init(source: PlayableSource) {
        self.source = source
        _guide = StateObject(wrappedValue: LivePlayerEPGModel(source: source))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let now = context.date
            let current = guide.programmes.first { $0.isOnAir(at: now) }
            let next = guide.programmes.first { $0.start >= (current?.end ?? now) }

            VStack(alignment: .leading, spacing: 7) {
                if let current {
                    HStack(spacing: 8) {
                        Text("NU")
                            .foregroundStyle(VeyraColors.cyan)
                        Text(current.title)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(clock(current.start))–\(clock(current.end))")
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    GeometryReader { geometry in
                        let duration = current.end.timeIntervalSince(current.start)
                        let fraction = duration > 0
                            ? min(1, max(0, now.timeIntervalSince(current.start) / duration))
                            : 0
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.25))
                            Capsule().fill(VeyraColors.red)
                                .frame(width: geometry.size.width * CGFloat(fraction))
                        }
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)
                } else {
                    HStack(spacing: 8) {
                        Circle().fill(VeyraColors.red).frame(width: 8, height: 8)
                        Text("LIVE")
                        if next == nil {
                            Text("Geen programmainformatie beschikbaar")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer(minLength: 0)
                    }
                }

                if let next {
                    HStack(spacing: 8) {
                        Text("HIERNA")
                            .foregroundStyle(VeyraColors.cyan)
                        Text(next.title)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(clock(next.start))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            #if os(tvOS)
            .font(.system(size: 21, weight: .semibold))
            #else
            .font(.subheadline.weight(.semibold))
            #endif
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
        }
        .task(id: source.id) {
            guard source.kind == .liveTV, source.epgChannelID != nil else { return }
            await guide.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1_800)) }
                catch { break }
                await guide.refresh()
            }
        }
    }

    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

@MainActor
private final class LivePlayerEPGModel: ObservableObject {
    @Published private(set) var programmes: [VeyraEPGProgramme] = []

    private let source: PlayableSource
    private let epgService = VeyraEPGService()
    private let configurationStore = IPTVConfigurationStore()
    private var lastNetworkLoad: Date?

    init(source: PlayableSource) {
        self.source = source
        programmes = source.epgProgrammes.sorted { $0.start < $1.start }
        if !programmes.isEmpty { lastNetworkLoad = Date() }
    }

    func refresh() async {
        guard let channelID = source.epgChannelID?
            .trimmingCharacters(in: .whitespacesAndNewlines), !channelID.isEmpty,
            let providers = try? configurationStore.loadProviders()
        else { return }

        let provider: IPTVStoredProvider?
        if let name = source.providerName, name != "IPTV" {
            provider = providers.first { $0.displayName == name }
        } else if let activeID = try? configurationStore.activeProviderID() {
            provider = providers.first { $0.id == activeID }
        } else {
            provider = nil
        }
        guard let provider else { return }

        let now = Date()
        let cacheKey = "live-guide-v1-\(provider.configuration.providerIdentifier)"
        let cached = IPTVDiskCache.read([String: [VeyraEPGProgramme]].self, key: cacheKey)
        if let cached,
           let cachedProgrammes = cached.value[channelID], !cachedProgrammes.isEmpty,
           (programmes.isEmpty || cached.savedAt > (lastNetworkLoad ?? .distantPast)) {
            programmes = cachedProgrammes.sorted { $0.start < $1.start }
        }

        let hasUpcoming = programmes.contains { $0.end > now }
        let cacheIsFresh = cached.map { now.timeIntervalSince($0.savedAt) < 3_600 } ?? false
        if hasUpcoming && cacheIsFresh { return }
        if let lastNetworkLoad, now.timeIntervalSince(lastNetworkLoad) < 1_800 { return }
        lastNetworkLoad = now

        do {
            let url: URL
            switch provider.configuration {
            case .xtream(let account):
                let base = account.serverURL.appendingPathComponent("xmltv.php")
                guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return }
                parts.queryItems = [
                    URLQueryItem(name: "username", value: account.username),
                    URLQueryItem(name: "password", value: account.password)
                ]
                guard let feedURL = parts.url else { return }
                url = feedURL
            case .m3u(let account):
                url = try await epgService.discoverSource(in: account.playlistURL)
            }

            let data = try await epgService.load(
                url: url,
                channelIDs: [channelID],
                from: now.addingTimeInterval(-3_600),
                to: now.addingTimeInterval(2 * 86_400)
            )
            try Task.checkCancellation()
            programmes = (data.programmes[channelID] ?? []).sorted { $0.start < $1.start }
        } catch {
            // Behoud beschikbare cached EPG bij een tijdelijk onbereikbare bron.
        }
    }
}
