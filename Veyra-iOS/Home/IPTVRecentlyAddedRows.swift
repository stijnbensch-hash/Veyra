import SwiftUI

// MARK: - Films

/// "IPTV nieuw toegevoegde films" op iOS Home. Zelfde gedeelde
/// IPTV-service/instellingen en schijf-cache als de tvOS-rij, met een
/// eenvoudige iOS-rij (geen focus-UI) als weergave.
struct IPTVHomeFilmsRow: View {
    @State private var items: [IPTVVODItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let posterWidth: CGFloat = 130

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                header
                ProgressView("Films laden…").padding(.horizontal)
            } else if let errorMessage, items.isEmpty {
                header
                Text(errorMessage).font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            } else if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(items.prefix(15)) { item in
                                NavigationLink {
                                    PlayerView(source: item.playableSource)
                                } label: {
                                    VeyraPosterCard(title: item.name, url: item.posterURL, symbol: "film", width: posterWidth)
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
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
            Task { await load(forceRefresh: true) }
        }
    }

    private var header: some View {
        VeyraSectionHeader(title: "IPTV nieuw toegevoegde films")
            .padding(.horizontal)
    }

    @MainActor
    private func load(forceRefresh: Bool = false) async {
        errorMessage = nil

        guard let configuration = try? IPTVConfigurationStore().load() else {
            isLoading = false
            return
        }

        let preferences = IPTVProviderPreferencesStore().load(for: configuration)
        let cacheKey = "recentlyAdded.vod.\(configuration.providerIdentifier)"

        if forceRefresh { items = [] }

        if items.isEmpty, let cached = IPTVDiskCache.read([IPTVVODItem].self, key: cacheKey)?.value {
            items = cached.filter { preferences.isVODItemVisible($0.id) }
        }

        isLoading = items.isEmpty

        guard case .xtream(let xtreamConfig) = configuration else {
            isLoading = false
            return
        }

        do {
            let service = IPTVService()
            let categories = try await service.loadXtreamVODCategories(configuration: xtreamConfig)
                .filter { preferences.isVODCategoryVisible($0.id) }

            var all: [IPTVVODItem] = []
            for category in categories {
                if let batch = try? await service.loadXtreamVOD(configuration: xtreamConfig, categoryID: category.id) {
                    all.append(contentsOf: batch.filter { preferences.isVODItemVisible($0.id) })
                }
            }

            var seen = Set<String>()
            let sorted = all.filter { seen.insert($0.id).inserted }
                .sorted { streamID(from: $0.id) > streamID(from: $1.id) }

            items = sorted
            IPTVDiskCache.write(sorted, key: cacheKey)
        } catch {
            if items.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func streamID(from id: String) -> Int {
        guard let value = id.split(separator: "-").last, let intID = Int(value) else { return 0 }
        return intID
    }
}

// MARK: - Series

/// "IPTV nieuw toegevoegde series" op iOS Home.
struct IPTVHomeSeriesRow: View {
    @State private var items: [XtreamSeriesItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let posterWidth: CGFloat = 130

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                header
                ProgressView("Series laden…").padding(.horizontal)
            } else if let errorMessage, items.isEmpty {
                header
                Text(errorMessage).font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            } else if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(items.prefix(15)) { item in
                                NavigationLink {
                                    IPTVSeriesEpisodesView(series: item)
                                } label: {
                                    VeyraPosterCard(title: item.name, url: item.coverURL, symbol: "tv", width: posterWidth)
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
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
            Task { await load(forceRefresh: true) }
        }
    }

    private var header: some View {
        VeyraSectionHeader(title: "IPTV nieuw toegevoegde series")
            .padding(.horizontal)
    }

    @MainActor
    private func load(forceRefresh: Bool = false) async {
        errorMessage = nil

        guard let configuration = try? IPTVConfigurationStore().load() else {
            isLoading = false
            return
        }

        let preferences = IPTVProviderPreferencesStore().load(for: configuration)
        let cacheKey = "recentlyAdded.series.\(configuration.providerIdentifier)"

        if forceRefresh { items = [] }

        if items.isEmpty, let cached = IPTVDiskCache.read([XtreamSeriesItem].self, key: cacheKey)?.value {
            items = cached.filter { preferences.isSeriesItemVisible(String($0.id)) }
        }

        isLoading = items.isEmpty

        guard case .xtream(let xtreamConfig) = configuration else {
            isLoading = false
            return
        }

        do {
            let allSeries = try await IPTVService().loadXtreamSeries(configuration: xtreamConfig, categoryID: nil)

            let visible = allSeries.filter { series in
                let categoryVisible: Bool
                if let categoryID = series.categoryID, !categoryID.isEmpty {
                    categoryVisible = preferences.isSeriesCategoryVisible(categoryID)
                } else {
                    categoryVisible = true
                }
                return categoryVisible && preferences.isSeriesItemVisible(String(series.id))
            }

            let sorted = visible.sorted { $0.id > $1.id }
            items = sorted
            IPTVDiskCache.write(sorted, key: cacheKey)
        } catch {
            if items.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - IPTV series episodes (iOS)

/// Toont de afleveringen van een IPTV (Xtream)-serie en speelt ze rechtstreeks af.
struct IPTVSeriesEpisodesView: View {
    let series: XtreamSeriesItem

    @State private var episodes: [XtreamSeriesEpisode] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            Group {
            if isLoading {
                ProgressView("Afleveringen laden…")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Afleveringen konden niet worden geladen").font(.headline)
                    Text(errorMessage).font(.subheadline).foregroundStyle(.secondary)
                    Button("Opnieuw proberen") { Task { await load() } }
                }
                .padding()
            } else if episodes.isEmpty {
                ContentUnavailableView("Geen afleveringen gevonden", systemImage: "tv")
            } else {
                List(groupedBySeason, id: \.season) { group in
                    Section("Seizoen \(group.season)") {
                        ForEach(group.episodes) { episode in
                            NavigationLink {
                                PlayerView(
                                    source: IPTVService().playableSource(for: episode, seriesName: series.name)
                                )
                            } label: {
                                Text("Afl. \(episode.episodeNumber) · \(episode.title)")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            }
        }
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var groupedBySeason: [(season: Int, episodes: [XtreamSeriesEpisode])] {
        let grouped = Dictionary(grouping: episodes, by: { $0.seasonNumber })
        return grouped.keys.sorted().map { season in
            (season, grouped[season]!.sorted { $0.episodeNumber < $1.episodeNumber })
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil

        guard
            let configuration = try? IPTVConfigurationStore().load(),
            case .xtream(let xtreamConfig) = configuration
        else {
            errorMessage = "Geen Xtream IPTV-provider ingesteld."
            isLoading = false
            return
        }

        do {
            let info = try await IPTVService().loadXtreamSeriesInfo(configuration: xtreamConfig, seriesID: series.id)
            episodes = info.episodes
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
