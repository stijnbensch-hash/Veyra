import Foundation

/// Doorzoekbare, gratis logo-database van de community-repo
/// `tv-logo/tv-logos` (github.com/tv-logo/tv-logos) — een aanvulling op
/// iptv-org met vaak andere of extra zenders. Haalt eenmalig de volledige
/// bestandsboom op via de GitHub Git Trees API en houdt die in het
/// geheugen voor de rest van de sessie.
///
/// Bron: https://github.com/tv-logo/tv-logos — publiek, geen API-sleutel
/// nodig (wel onderhevig aan GitHub's onauthenticated rate limit van
/// ~60 verzoeken/uur; door de eenmalige caching blijft dat in de praktijk
/// geen probleem). Zender- en landnamen worden afgeleid uit bestandspaden
/// (`countries/<land>/<zender>.png`), niet uit een aparte "mooie naam"-
/// index zoals iptv-org die heeft — de weergavenaam is dus wat ruwer.
actor TVLogoRepoDirectory {
    static let shared = TVLogoRepoDirectory()

    private let treeURL = URL(
        string: "https://api.github.com/repos/tv-logo/tv-logos/git/trees/main?recursive=1"
    )!
    private let rawBaseURL = "https://raw.githubusercontent.com/tv-logo/tv-logos/main/"

    private var entries: [(channelName: String, country: String, logoURL: URL)] = []
    private var isLoaded = false
    private var loadingTask: Task<Void, Error>?

    private static let imageExtensions: Set<String> = ["png", "svg", "webp"]

    private struct TreeResponse: Decodable {
        let tree: [TreeEntry]
    }

    private struct TreeEntry: Decodable {
        let path: String
        let type: String
    }

    func search(query: String, limit: Int = 40) async throws -> [IPTVOrgLogoResult] {
        try await ensureLoaded()

        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }

        let matches = entries.filter { $0.channelName.lowercased().contains(needle) }

        return matches.prefix(limit).map { entry in
            IPTVOrgLogoResult(
                id: entry.logoURL.absoluteString,
                channelName: entry.channelName,
                country: entry.country,
                logoURL: entry.logoURL,
                source: "tv-logos"
            )
        }
    }

    private func ensureLoaded() async throws {
        if isLoaded { return }

        if let loadingTask {
            try await loadingTask.value
            return
        }

        let task = Task { [treeURL, rawBaseURL] in
            do {
                var request = URLRequest(url: treeURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(TreeResponse.self, from: data)

                var parsed: [(channelName: String, country: String, logoURL: URL)] = []
                for entry in response.tree {
                    guard entry.type == "blob", entry.path.hasPrefix("countries/") else { continue }

                    let ext = (entry.path as NSString).pathExtension.lowercased()
                    guard Self.imageExtensions.contains(ext) else { continue }

                    let components = entry.path.split(separator: "/")
                    guard components.count >= 3 else { continue }
                    let countrySlug = String(components[1])

                    let fileStem = (entry.path as NSString).lastPathComponent
                        .replacingOccurrences(of: ".\(ext)", with: "")

                    guard
                        let escapedPath = entry.path.addingPercentEncoding(
                            withAllowedCharacters: .urlPathAllowed
                        ),
                        let url = URL(string: rawBaseURL + escapedPath)
                    else { continue }

                    parsed.append((
                        channelName: Self.displayName(from: fileStem),
                        country: Self.displayName(from: countrySlug),
                        logoURL: url
                    ))
                }

                await self.finishLoading(parsed)
            } catch {
                await self.failLoading()
                throw error
            }
        }

        loadingTask = task
        try await task.value
    }

    private func finishLoading(_ parsed: [(channelName: String, country: String, logoURL: URL)]) {
        entries = parsed
        isLoaded = true
        loadingTask = nil
    }

    /// Zorgt dat een mislukte laadpoging (bv. geen netwerk) niet blijvend
    /// blokkeert — een volgende zoekopdracht probeert gewoon opnieuw te laden.
    private func failLoading() {
        loadingTask = nil
    }

    /// "bbc-one-uk" → "Bbc One Uk" — ruwe titel-case van de bestandsnaam,
    /// geen poging om een landcode-achtervoegsel te herkennen en te
    /// verwijderen (dat verschilt per bestand en een verkeerde gok is
    /// verwarrender dan de rauwe naam gewoon laten staan).
    private static func displayName(from slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
