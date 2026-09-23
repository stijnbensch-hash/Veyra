import Foundation

/// Eén logo-resultaat, uit de iptv-org-database (github.com/iptv-org/api)
/// of de tv-logo/tv-logos-repo (github.com/tv-logo/tv-logos) — `source`
/// onderscheidt de twee zodat de UI kan tonen waar een logo vandaan komt.
struct IPTVOrgLogoResult: Identifiable, Hashable {
    let id: String
    let channelName: String
    let country: String?
    let logoURL: URL
    var source: String = "iptv-org"
}

/// Doorzoekbare, gratis logo-database van het open-source iptv-org-project.
/// Haalt eenmalig `channels.json` (naam/land per zender-id) en `logos.json`
/// (logo-URL's per zender-id) op via GitHub Pages, en houdt ze in het
/// geheugen voor de rest van de sessie.
///
/// Bron: https://github.com/iptv-org/api — publiek, geen API-sleutel nodig.
/// De onderliggende logo's komen uit de gekoppelde iptv-org-repositories
/// (database/iptv/epg), elk met hun eigen licentie; dit is een vrijwillige
/// gemeenschapsverzameling, geen garantie op rechtenvrij gebruik per logo.
actor IPTVOrgLogoDirectory {
    static let shared = IPTVOrgLogoDirectory()

    private let channelsURL = URL(string: "https://iptv-org.github.io/api/channels.json")!
    private let logosURL = URL(string: "https://iptv-org.github.io/api/logos.json")!

    private var logosByChannelID: [String: [IPTVOrgLogoResult]] = [:]
    private var isLoaded = false
    private var loadingTask: Task<Void, Error>?

    private struct RawChannel: Decodable {
        let id: String
        let name: String
        let country: String?
    }

    private struct RawLogo: Decodable {
        let channel: String
        let url: String
    }

    func search(query: String, limit: Int = 40) async throws -> [IPTVOrgLogoResult] {
        try await ensureLoaded()

        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }

        var matches: [IPTVOrgLogoResult] = []
        for (channelID, results) in logosByChannelID {
            let matchesQuery = channelID.lowercased().contains(needle)
                || results.contains { $0.channelName.lowercased().contains(needle) }
            if matchesQuery {
                matches.append(contentsOf: results)
            }
        }

        return Array(matches.sorted { $0.channelName < $1.channelName }.prefix(limit))
    }

    private func ensureLoaded() async throws {
        if isLoaded { return }

        if let loadingTask {
            try await loadingTask.value
            return
        }

        let task = Task { [channelsURL, logosURL] in
            do {
                async let channelsFetch = URLSession.shared.data(from: channelsURL)
                async let logosFetch = URLSession.shared.data(from: logosURL)
                let ((channelsData, _), (logosData, _)) = try await (channelsFetch, logosFetch)

                let channels = try JSONDecoder().decode([RawChannel].self, from: channelsData)
                let logos = try JSONDecoder().decode([RawLogo].self, from: logosData)

                var namesByID: [String: String] = [:]
                var countriesByID: [String: String] = [:]
                for channel in channels {
                    namesByID[channel.id] = channel.name
                    countriesByID[channel.id] = channel.country
                }

                var grouped: [String: [IPTVOrgLogoResult]] = [:]
                for logo in logos {
                    guard let url = URL(string: logo.url) else { continue }
                    let name = namesByID[logo.channel] ?? logo.channel
                    let result = IPTVOrgLogoResult(
                        id: "\(logo.channel)#\(logo.url)",
                        channelName: name,
                        country: countriesByID[logo.channel],
                        logoURL: url
                    )
                    grouped[logo.channel, default: []].append(result)
                }

                await self.finishLoading(grouped)
            } catch {
                await self.failLoading()
                throw error
            }
        }

        loadingTask = task
        try await task.value
    }

    private func finishLoading(_ grouped: [String: [IPTVOrgLogoResult]]) {
        logosByChannelID = grouped
        isLoaded = true
        loadingTask = nil
    }

    /// Zorgt dat een mislukte laadpoging (bv. geen netwerk) niet blijvend
    /// blokkeert — een volgende zoekopdracht probeert gewoon opnieuw te laden.
    private func failLoading() {
        loadingTask = nil
    }
}
