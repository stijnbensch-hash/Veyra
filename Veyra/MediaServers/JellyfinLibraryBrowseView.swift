import SwiftUI

// MARK: - Libraries

@MainActor
struct JellyfinLibrariesView: View {
    let account: MediaServerAccount

    @State private var libraries: [JellyfinLibrary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 260), spacing: 24)
    ]

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    header

                    if isLoading {
                        ProgressView("Bibliotheken laden…")
                            .padding(.top, 12)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                    } else if libraries.isEmpty {
                        Text("Geen bibliotheken gevonden op deze server.")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.62))
                    } else {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(libraries) { library in
                                NavigationLink {
                                    JellyfinItemsView(account: account, library: library)
                                } label: {
                                    libraryTile(library)
                                }
                                .buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.card))
                            }
                        }
                    }
                }
                .frame(maxWidth: 1400, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            await loadLibraries()
        }
    }

    private var header: some View {
        HStack(spacing: 22) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.cyan)
                .frame(width: 4, height: 66)

            VStack(alignment: .leading, spacing: 12) {
                Text(account.name)
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Kies een bibliotheek om te bekijken.")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()
        }
    }

    private func libraryTile(_ library: JellyfinLibrary) -> some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cyan.opacity(0.10))

                Image(systemName: library.symbol)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 60, height: 60)

            Text(library.name)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.cyan.opacity(0.6))
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .veyraGlass(radius: VeyraRadius.card)
    }

    private func loadLibraries() async {
        isLoading = true
        errorMessage = nil

        do {
            libraries = try await JellyfinService(account: account).libraries()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Items in a library

@MainActor
struct JellyfinItemsView: View {
    let account: MediaServerAccount
    let library: JellyfinLibrary

    @State private var items: [JellyfinItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 20)
    ]

    private var service: JellyfinService {
        JellyfinService(account: account)
    }

    private var includeItemTypes: [String] {
        library.collectionType == "tvshows"
            ? ["Series"]
            : ["Movie"]
    }

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    VeyraSectionHeader(title: library.name)

                    if isLoading {
                        ProgressView("Titels laden…")
                            .padding(.top, 12)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                    } else if items.isEmpty {
                        Text("Geen titels gevonden in deze bibliotheek.")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.62))
                    } else {
                        LazyVGrid(columns: columns, spacing: 28) {
                            ForEach(items) { item in
                                itemLink(item)
                            }
                        }
                    }
                }
                .frame(maxWidth: 1600, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            await loadItems()
        }
    }

    @ViewBuilder
    private func itemLink(_ item: JellyfinItem) -> some View {
        if item.isSeries {
            NavigationLink {
                JellyfinEpisodesView(account: account, series: item)
            } label: {
                poster(for: item)
            }
            .buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.poster))
        } else {
            NavigationLink {
                JellyfinPlaybackDestination(account: account, item: item)
            } label: {
                poster(for: item)
            }
            .buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.poster))
        }
    }

    private func poster(for item: JellyfinItem) -> some View {
        VeyraPosterCard(
            title: item.displayTitle,
            url: service.imageURL(for: item),
            symbol: item.isSeries ? "tv" : "film",
            width: 230
        )
    }

    private func loadItems() async {
        isLoading = true
        errorMessage = nil

        do {
            items = try await service.items(
                parentID: library.id,
                includeItemTypes: includeItemTypes
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Episodes of a series

@MainActor
struct JellyfinEpisodesView: View {
    let account: MediaServerAccount
    let series: JellyfinItem

    @State private var episodes: [JellyfinItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var service: JellyfinService {
        JellyfinService(account: account)
    }

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VeyraSectionHeader(title: series.name)

                    if isLoading {
                        ProgressView("Afleveringen laden…")
                            .padding(.top, 12)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                    } else if episodes.isEmpty {
                        Text("Geen afleveringen gevonden.")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.62))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(episodes) { episode in
                                NavigationLink {
                                    JellyfinPlaybackDestination(account: account, item: episode)
                                } label: {
                                    episodeRow(episode)
                                }
                                .buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.card))
                            }
                        }
                    }
                }
                .frame(maxWidth: 1200, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 50)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            await loadEpisodes()
        }
    }

    private func episodeRow(_ episode: JellyfinItem) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(episode.displayTitle)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)

                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.cyan)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .veyraGlass(radius: VeyraRadius.card)
    }

    private func loadEpisodes() async {
        isLoading = true
        errorMessage = nil

        do {
            episodes = try await service.episodes(seriesID: series.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Playback bridge

/// Bouwt de PlayableSource (en, waar mogelijk, een MediaItem voor
/// ondertitels/Trakt) op het moment van afspelen, zodat de rest van
/// de bibliotheek-navigatie synchroon en eenvoudig kan blijven.
@MainActor
struct JellyfinPlaybackDestination: View {
    let account: MediaServerAccount
    let item: JellyfinItem

    var body: some View {
        Group {
            if let url = JellyfinService(account: account).streamURL(for: item) {
                PlayerView(
                    source: PlayableSource(
                        name: item.displayTitle,
                        description: item.overview,
                        url: url,
                        kind: .direct,
                        providerName: account.name
                    ),
                    item: mediaItem
                )
            } else {
                VStack(spacing: 20) {
                    Text("Afspelen niet mogelijk")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Kon geen afspeel-URL opbouwen voor deze titel.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VeyraBackground())
            }
        }
    }

    private var mediaItem: MediaItem {
        MediaItem(
            title: item.isEpisode ? (item.seriesName ?? item.name) : item.name,
            type: item.isEpisode ? .series : .movie,
            seasonNumber: item.parentIndexNumber,
            episodeNumber: item.indexNumber,
            overview: item.overview,
            releaseDate: item.productionYear.map { String($0) }
        )
    }
}
