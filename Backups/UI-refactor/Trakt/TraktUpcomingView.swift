import SwiftUI
import Foundation

@MainActor
struct TraktUpcomingView: View {
    @ObservedObject private var store = TraktStore.shared

    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var focusedCardID: String?
    @FocusState private var refreshIsFocused: Bool

    @State private var episodes: [VeyraUpcomingEpisode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var missingDates = 0

    @State private var refreshID = UUID()
    @State private var requestID = UUID()
    @State private var dataOwner: String?
    @State private var lastLoadedAt: Date?

    private var accountKey: String {
        guard store.isConnected else {
            return "disconnected"
        }

        if let id = store.user?.ids.trakt {
            return "trakt:\(id)"
        }

        if let username = store.user?.username {
            return "user:\(username)"
        }

        return "connected:pending"
    }

    private var loadKey: String {
        "\(accountKey):\(refreshID.uuidString)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            TimelineView(
                .periodic(from: .now, by: 60)
            ) { context in
                let upcoming = upcomingEpisodes(
                    at: context.date
                )

                if !store.isConnected {
                    Text(
                        "Koppel Trakt via Instellingen om je planning te zien."
                    )
                    .foregroundStyle(.secondary)
                } else if isLoading && upcoming.isEmpty {
                    ProgressView("Trakt-kalender laden...")
                } else if upcoming.isEmpty {
                    Text(
                        errorMessage == nil
                            ? "Geen geplande afleveringen in de komende 30 dagen."
                            : "De Trakt-kalender kon niet worden geladen."
                    )
                    .foregroundStyle(.secondary)
                } else {
                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {
                        LazyHStack(
                            alignment: .top,
                            spacing: 28
                        ) {
                            ForEach(upcoming) { item in
                                NavigationLink {
                                    // Alleen de seriepagina openen.
                                    // Een geplande uitzending start
                                    // niet automatisch een stream.
                                    TraktDestinationView(
                                        entry: TraktEntry(
                                            show: item.show
                                        )
                                    )
                                } label: {
                                    VeyraUpcomingCard(
                                        item: item,
                                        now: context.date,
                                        isFocused:
                                            focusedCardID == item.id
                                    )
                                }
                                .buttonStyle(
                                    VeyraUpcomingButtonStyle()
                                )
                                .focused(
                                    $focusedCardID,
                                    equals: item.id
                                )
                                .focusEffectDisabled()
                                .accessibilityElement(
                                    children: .ignore
                                )
                                .accessibilityLabel(
                                    "\(item.showTitle), \(item.episodeCode), \(item.episodeTitle)"
                                )
                                .accessibilityValue(
                                    "Gepland: \(VeyraUpcomingDates.display(item.airDate))"
                                )
                                .accessibilityHint(
                                    "Opent de seriepagina"
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                    }
                    .frame(height: 330)
                }
            }

            if store.isConnected,
               let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            if store.isConnected,
               dataOwner == accountKey,
               missingDates > 0 {
                Text(
                    "Voor \(missingDates) kalenderitems ontbreekt een geldige uitzenddatum."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .task(id: loadKey) {
            await loadUpcoming()
        }
        .onChange(of: scenePhase) { _, phase in
            guard
                phase == .active,
                store.isConnected
            else {
                return
            }

            let needsRefresh = lastLoadedAt.map {
                Date().timeIntervalSince($0) > 900
            } ?? true

            if needsRefresh && !isLoading {
                refreshID = UUID()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 18) {
            Text("BINNENKORT")
                .font(
                    .system(
                        size: 26,
                        weight: .semibold
                    )
                )
                .tracking(4)
                .foregroundStyle(.cyan)
                .accessibilityAddTraits(.isHeader)

            Text("Komende 30 dagen")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)
            
            // Refresh button removed as per instructions
        }
    }

    // MARK: - Zichtbare afleveringen

    private func upcomingEpisodes(
        at now: Date
    ) -> [VeyraUpcomingEpisode] {
        guard
            store.isConnected,
            dataOwner == accountKey
        else {
            return []
        }

        let end = Calendar.current.date(
            byAdding: .day,
            value: 30,
            to: now
        ) ?? now.addingTimeInterval(30 * 86_400)

        return VeyraUpcomingEpisode.nextPerShow(
            episodes,
            after: now,
            before: end
        )
    }

    // MARK: - Kalender laden

    private func loadUpcoming() async {
        let currentRequest = UUID()
        requestID = currentRequest

        let owner = accountKey

        guard store.isConnected else {
            episodes = []
            dataOwner = nil
            errorMessage = nil
            missingDates = 0
            lastLoadedAt = nil
            isLoading = false
            return
        }

        if dataOwner != owner {
            episodes = []
            missingDates = 0
            lastLoadedAt = nil
        }

        isLoading = true
        errorMessage = nil

        defer {
            if requestID == currentRequest {
                isLoading = false
            }
        }

        do {
            let start = VeyraUpcomingDates.requestDay(
                Date()
            )

            // 31 UTC-kalenderdagen dekken ook het resterende
            // deel van vandaag. De rij filtert daarna op
            // de komende 30 dagen vanaf het huidige moment.
            let response: [VeyraUpcomingCalendarEntry] =
                try await store.client.request(
                    "calendars/my/shows/\(start)/31"
                )

            try Task.checkCancellation()

            guard
                requestID == currentRequest,
                store.isConnected,
                accountKey == owner
            else {
                return
            }

            var resolved: [VeyraUpcomingEpisode] = []
            var invalidDates = 0

            for value in response {
                guard
                    let rawDate = value.firstAired,
                    let date = VeyraUpcomingDates.parse(
                        rawDate
                    )
                else {
                    invalidDates += 1
                    continue
                }

                resolved.append(
                    VeyraUpcomingEpisode(
                        show: value.show,
                        episode: value.episode,
                        airDate: date
                    )
                )
            }

            episodes = resolved
            missingDates = invalidDates
            dataOwner = owner
            lastLoadedAt = Date()
        } catch is CancellationError {
            // Navigeren of van account wisselen is geen fout.
        } catch {
            guard
                !Task.isCancelled,
                requestID == currentRequest,
                store.isConnected,
                accountKey == owner
            else {
                return
            }

            errorMessage =
                "Trakt-kalender: \(error.localizedDescription)"
        }
    }
}

// MARK: - Trakt-kalenderantwoord

private struct VeyraUpcomingCalendarEntry: Decodable {
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
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        // Ondersteunt zowel convertFromSnakeCase
        // als een decoder met standaardinstellingen.
        firstAired = try container.decodeIfPresent(
            String.self,
            forKey: .firstAired
        ) ?? container.decodeIfPresent(
            String.self,
            forKey: .firstAiredSnake
        )

        show = try container.decode(
            TraktMedia.self,
            forKey: .show
        )

        episode = try container.decode(
            TraktMedia.self,
            forKey: .episode
        )
    }
}

// MARK: - Afleveringsmodel voor de rij

private struct VeyraUpcomingEpisode: Identifiable {
    let show: TraktMedia
    let episode: TraktMedia
    let airDate: Date

    var showID: String {
        if let id = show.ids.trakt {
            return "trakt:\(id)"
        }

        if let id = show.ids.tmdb {
            return "tmdb:\(id)"
        }

        if let id = show.ids.imdb, !id.isEmpty {
            return "imdb:\(id)"
        }

        if let slug = show.ids.slug, !slug.isEmpty {
            return "slug:\(slug)"
        }

        return "title:\(show.title ?? ""):\(show.year ?? 0)"
    }

    var id: String {
        if let id = episode.ids.trakt {
            return "episode:\(id)"
        }

        return "\(showID):s\(episode.season ?? -1):e\(episode.number ?? -1)"
    }

    var showTitle: String {
        show.title ?? "Serie"
    }

    var episodeTitle: String {
        if let title = episode.title,
           !title.trimmingCharacters(
                in: .whitespacesAndNewlines
           ).isEmpty {
            return title
        }

        if let number = episode.number {
            return "Aflevering \(number)"
        }

        return "Volgende aflevering"
    }

    var episodeCode: String {
        guard
            let season = episode.season,
            let number = episode.number
        else {
            return "Aflevering"
        }

        return String(
            format: "S%02dE%02d",
            season,
            number
        )
    }

    static func nextPerShow(
        _ values: [Self],
        after now: Date,
        before end: Date
    ) -> [Self] {
        let sorted = values.filter {
            $0.airDate > now && $0.airDate < end
        }
        .sorted {
            if $0.airDate != $1.airDate {
                return $0.airDate < $1.airDate
            }

            if $0.showID != $1.showID {
                return $0.showID < $1.showID
            }

            if $0.episode.season != $1.episode.season {
                return ($0.episode.season ?? 0)
                    < ($1.episode.season ?? 0)
            }

            return ($0.episode.number ?? 0)
                < ($1.episode.number ?? 0)
        }

        // Eén eerstvolgende geplande aflevering per serie.
        // Geen maximumaantal series in deze rij.
        var seen = Set<String>()

        return sorted.filter {
            seen.insert($0.showID).inserted
        }
    }
}

// MARK: - Brede kaart

@MainActor
private struct VeyraUpcomingCard: View {
    let item: VeyraUpcomingEpisode
    let now: Date
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                VeyraUpcomingArtwork(item: item)

                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.80)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom) {
                    Text(item.episodeCode)
                        .font(
                            .system(
                                size: 16,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    Color.black.opacity(0.55)
                                )
                        )

                    Spacer(minLength: 8)

                    Text(
                        VeyraUpcomingDates.countdown(
                            to: item.airDate,
                            from: now
                        )
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color(
                            red: 0.01,
                            green: 0.07,
                            blue: 0.11
                        )
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.cyan)
                    )
                }
                .padding(12)
            }
            .frame(width: 360, height: 203)
            .clipped()
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .strokeBorder(
                    isFocused
                        ? Color.cyan
                        : Color.clear,
                    lineWidth: 3
                )
                .allowsHitTesting(false)
            }

            Text(item.showTitle)
                .font(
                    .system(
                        size: 21,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(item.episodeTitle)
                .font(.system(size: 17))
                .foregroundStyle(
                    .white.opacity(0.65)
                )
                .lineLimit(1)

            Text(
                VeyraUpcomingDates.display(
                    item.airDate
                )
            )
            .font(.system(size: 15))
            .foregroundStyle(
                .cyan.opacity(0.85)
            )
            .lineLimit(1)
        }
        .frame(width: 360, alignment: .leading)
        .multilineTextAlignment(.leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Geen witte selectieachtergrond

private struct VeyraUpcomingButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .opacity(
                configuration.isPressed ? 0.85 : 1.0
            )
    }
}

// MARK: - Afleveringsbeeld

@MainActor
private struct VeyraUpcomingArtwork: View {
    let item: VeyraUpcomingEpisode

    @State private var imageURL: URL?
    @State private var isLoading = true
    @State private var requestID = UUID()

    private var artworkKey: String {
        "\(item.show.ids.tmdb ?? 0):\(item.episode.season ?? -1):\(item.episode.number ?? -1)"
    }

    var body: some View {
        ZStack {
            Color(
                red: 0.03,
                green: 0.10,
                blue: 0.16
            )

            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    case .empty:
                        ProgressView()

                    case .failure:
                        placeholder

                    @unknown default:
                        placeholder
                    }
                }
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .frame(width: 360, height: 203)
        .clipped()
        .task(id: artworkKey) {
            await loadArtwork()
        }
    }

    private var placeholder: some View {
        Image(systemName: "tv")
            .font(
                .system(
                    size: 44,
                    weight: .light
                )
            )
            .foregroundStyle(
                .cyan.opacity(0.45)
            )
    }

    private func loadArtwork() async {
        let currentRequest = UUID()
        requestID = currentRequest

        imageURL = nil
        isLoading = true

        defer {
            if requestID == currentRequest {
                isLoading = false
            }
        }

        guard
            let showID = item.show.ids.tmdb,
            showID > 0,
            let service = SeriesService()
        else {
            return
        }

        // Gebruik de bestaande metadataservice.
        // Probeer eerst een beeld van deze aflevering.
        if let season = item.episode.season,
           let number = item.episode.number {
            do {
                let details = try await service.season(
                    seriesID: showID,
                    seasonNumber: season
                )

                try Task.checkCancellation()

                guard requestID == currentRequest else {
                    return
                }

                if let episode = details.episodes.first(
                    where: {
                        $0.episodeNumber == number
                    }
                ),
                   let url = makeImageURL(
                    path: episode.stillPath,
                    size: "original"
                   ) {
                    imageURL = url
                    return
                }
            } catch {
                if Task.isCancelled {
                    return
                }

                // Een toekomstige aflevering heeft
                // mogelijk nog geen afleveringsbeeld.
            }
        }

        // Anders gebruiken we de brede serieafbeelding.
        do {
            try Task.checkCancellation()

            let details = try await service.seriesDetails(
                id: showID
            )

            try Task.checkCancellation()

            guard requestID == currentRequest else {
                return
            }

            imageURL = makeImageURL(
                path: details.backdropPath,
                size: "w780"
            )
        } catch {
            // De kaart blijft bruikbaar zonder afbeelding.
        }
    }

    private func makeImageURL(
        path: String?,
        size: String
    ) -> URL? {
        guard let path else {
            return nil
        }

        let clean = path
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "/")
            )

        guard
            !clean.isEmpty,
            let base = URL(
                string:
                    "https://image.tmdb.org/t/p/\(size)"
            )
        else {
            return nil
        }

        return base.appendingPathComponent(clean)
    }
}

// MARK: - Datums en aftellen

private enum VeyraUpcomingDates {
    static func parse(
        _ value: String
    ) -> Date? {
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [
            .withInternetDateTime
        ]

        return formatter.date(from: value)
    }

    static func requestDay(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()

        formatter.calendar = Calendar(
            identifier: .gregorian
        )

        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )

        formatter.timeZone = TimeZone(
            secondsFromGMT: 0
        )

        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: date)
    }

    static func display(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()

        formatter.locale = Locale(
            identifier: "nl_BE"
        )

        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "EEE d MMM, HH:mm"

        return formatter.string(from: date)
    }

    static func countdown(
        to date: Date,
        from now: Date
    ) -> String {
        let seconds = date.timeIntervalSince(now)

        if seconds <= 0 {
            return "Uitzendmoment bereikt"
        }

        if seconds < 3_600 {
            let minutes = max(
                1,
                Int(ceil(seconds / 60))
            )

            return "Over \(minutes) min"
        }

        if seconds < 86_400 {
            let hours = Int(
                ceil(seconds / 3_600)
            )

            return "Over \(hours) uur"
        }

        let calendar = Calendar.current

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        return days <= 1
            ? "Morgen"
            : "Over \(days) dagen"
    }
}
