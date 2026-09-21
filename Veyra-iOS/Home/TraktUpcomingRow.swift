import SwiftUI

/// "Binnenkort" op de iOS Home-tab: dezelfde Trakt-kalendergegevens als de
/// tvOS-rij (`TraktUpcomingView`), maar met een eenvoudige, native iOS-rij
/// zonder focus-effecten. Tikken opent alleen de seriepagina (geen auto-play).
struct TraktUpcomingRow: View {
    @ObservedObject private var store = TraktStore.shared
    @AppStorage(GeneralSettingsDefaults.showUpcomingKey) private var showUpcoming = true

    @State private var episodes: [VeyraUpcomingEpisodeIOS] = []
    @State private var isLoading = false
    @State private var dataOwner: String?
    @State private var destination: TMDBSeries?

    private var accountKey: String {
        guard store.isConnected else { return "disconnected" }
        if let id = store.user?.ids.trakt { return "trakt:\(id)" }
        if let username = store.user?.username { return "user:\(username)" }
        return "connected:pending"
    }

    private var upcoming: [VeyraUpcomingEpisodeIOS] {
        guard store.isConnected, dataOwner == accountKey else { return [] }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 86_400)
        return VeyraUpcomingEpisodeIOS.nextPerShow(episodes, after: now, before: end)
    }

    var body: some View {
        Group {
            if showUpcoming && store.isConnected && !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    VeyraSectionHeader(title: "Binnenkort")
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(upcoming) { item in
                                Button {
                                    destination = TMDBSeries(
                                        id: item.showID,
                                        name: item.showTitle,
                                        overview: nil,
                                        posterPath: nil,
                                        backdropPath: nil,
                                        firstAirDate: nil,
                                        voteAverage: nil,
                                        genreIDs: nil
                                    )
                                } label: {
                                    VeyraUpcomingCardIOS(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .task(id: accountKey) {
            await loadUpcoming()
        }
        .navigationDestination(item: $destination) { series in
            SeriesDetailView(series: series)
        }
    }

    private func loadUpcoming() async {
        guard store.isConnected else {
            episodes = []
            dataOwner = nil
            return
        }

        let owner = accountKey
        isLoading = true
        defer { isLoading = false }

        do {
            let start = VeyraUpcomingDatesIOS.requestDay(Date())
            let response: [VeyraUpcomingCalendarEntryIOS] =
                try await store.client.request("calendars/my/shows/\(start)/31")

            guard store.isConnected, accountKey == owner else { return }

            var resolved: [VeyraUpcomingEpisodeIOS] = []
            for value in response {
                guard let rawDate = value.firstAired,
                      let date = VeyraUpcomingDatesIOS.parse(rawDate) else { continue }
                resolved.append(VeyraUpcomingEpisodeIOS(show: value.show, episode: value.episode, airDate: date))
            }

            episodes = resolved
            dataOwner = owner
        } catch {
            // De rij blijft eenvoudigweg leeg als de kalender niet geladen kan worden.
        }
    }
}

// MARK: - Trakt-kalenderantwoord

private struct VeyraUpcomingCalendarEntryIOS: Decodable {
    let firstAired: String?
    let show: TraktMedia
    let episode: TraktMedia

    private enum CodingKeys: String, CodingKey {
        case firstAired
        case firstAiredSnake = "first_aired"
        case show
        case episode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstAired = try container.decodeIfPresent(String.self, forKey: .firstAired)
            ?? container.decodeIfPresent(String.self, forKey: .firstAiredSnake)
        show = try container.decode(TraktMedia.self, forKey: .show)
        episode = try container.decode(TraktMedia.self, forKey: .episode)
    }
}

// MARK: - Afleveringsmodel voor de rij

private struct VeyraUpcomingEpisodeIOS: Identifiable {
    let show: TraktMedia
    let episode: TraktMedia
    let airDate: Date

    var showID: Int { show.ids.tmdb ?? 0 }

    var showIdentity: String {
        if let id = show.ids.trakt { return "trakt:\(id)" }
        if let id = show.ids.tmdb { return "tmdb:\(id)" }
        if let id = show.ids.imdb, !id.isEmpty { return "imdb:\(id)" }
        if let slug = show.ids.slug, !slug.isEmpty { return "slug:\(slug)" }
        return "title:\(show.title ?? ""):\(show.year ?? 0)"
    }

    var id: String {
        if let id = episode.ids.trakt { return "episode:\(id)" }
        return "\(showIdentity):s\(episode.season ?? -1):e\(episode.number ?? -1)"
    }

    var showTitle: String { show.title ?? "Serie" }

    var episodeTitle: String {
        if let title = episode.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let number = episode.number { return "Aflevering \(number)" }
        return "Volgende aflevering"
    }

    var episodeCode: String {
        guard let season = episode.season, let number = episode.number else { return "Aflevering" }
        return String(format: "S%02dE%02d", season, number)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(airDate)
    }

    static func nextPerShow(_ values: [Self], after now: Date, before end: Date) -> [Self] {
        let sorted = values.filter { $0.airDate > now && $0.airDate < end }
            .sorted {
                if $0.airDate != $1.airDate { return $0.airDate < $1.airDate }
                return $0.showIdentity < $1.showIdentity
            }
        var seen = Set<String>()
        return sorted.filter { seen.insert($0.showIdentity).inserted }
    }
}

// MARK: - Kaart

private struct VeyraUpcomingCardIOS: View {
    let item: VeyraUpcomingEpisodeIOS

    @State private var imageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        ZStack {
                            VeyraColors.surface
                            Image(systemName: "tv")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 220, height: 124)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.05), .black.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    VeyraPosterBadge(title: item.episodeCode, fontSize: 11)
                        .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    if item.isToday {
                        VeyraPosterBadge(title: "Vandaag", accent: VeyraColors.red, fontSize: 11)
                            .padding(8)
                    }
                }
            }

            Text(item.showTitle)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Text(VeyraUpcomingDatesIOS.display(item.airDate))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 220, alignment: .leading)
        .task { await loadArtwork() }
    }

    @MainActor
    private func loadArtwork() async {
        guard item.showID > 0, let service = SeriesService() else { return }
        do {
            let details = try await service.seriesDetails(id: item.showID)
            if let path = details.backdropPath, !path.isEmpty {
                imageURL = URL(string: "https://image.tmdb.org/t/p/w780\(path)")
            }
        } catch {
            // Kaart blijft bruikbaar zonder afbeelding.
        }
    }
}

// MARK: - Datums

private enum VeyraUpcomingDatesIOS {
    static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func requestDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func display(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_BE")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "EEE d MMM, HH:mm"
        return formatter.string(from: date)
    }
}
