import SwiftUI

enum TraktLibraryKind {
    case playback, watchlist, history, ratings
    var title: String {
        switch self {
        case .playback: return "Verder kijken"
        case .watchlist: return "Watchlist"
        case .history: return "Kijkgeschiedenis"
        case .ratings: return "Beoordelingen"
        }
    }
}

struct TraktLibraryView: View {
    let kind: TraktLibraryKind
    @ObservedObject private var store = TraktStore.shared
    @State private var extraHistory: [TraktEntry] = []
    @State private var page = 1
    @State private var hasMore = true
    @State private var loading = false
    @State private var error: String?
    private var entries: [TraktEntry] {
        switch kind {
        case .playback: return store.playback
        case .watchlist: return store.watchlist
        case .history: return store.history + extraHistory
        case .ratings: return store.ratings
        }
    }
    var body: some View {
        List {
            Section(kind.title) {
                if entries.isEmpty { Text(store.isSyncing ? "Gegevens laden…" : "Nog geen titels.") }
                ForEach(entries, id: \.rowID) { entry in
                    NavigationLink { TraktDestinationView(entry: entry) } label: { TraktEntryLabel(entry: entry) }
                }
                if kind == .history && hasMore && store.history.count >= 100 {
                    Button(loading ? "Laden…" : "Oudere kijkgeschiedenis laden") {
                        loading = true
                        Task {
                            do {
                                let next = try await store.historyPage(page + 1)
                                let existing = Set(entries.map(\.rowID))
                                extraHistory += next.filter { !existing.contains($0.rowID) }
                                page += 1; hasMore = next.count == 100
                            } catch { self.error = error.localizedDescription }
                            loading = false
                        }
                    }.disabled(loading)
                }
            }
            if kind == .playback && !store.upNext.isEmpty {
                Section("Volgende afleveringen") {
                    ForEach(store.upNext.compactMap(\.entry), id: \.rowID) { entry in
                        NavigationLink { TraktDestinationView(entry: entry) } label: { TraktEntryLabel(entry: entry) }
                    }
                }
            }
            if let error = error ?? store.errorMessage { Text(error).foregroundStyle(.orange) }
            Button("Vernieuwen") {
                Task { extraHistory = []; page = 1; hasMore = true; await store.refresh() }
            }.disabled(store.isSyncing)
        }
        .task { await store.refreshIfNeeded() }
    }
}

struct TraktEntryLabel: View {
    let entry: TraktEntry
    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: entry.movie != nil ? "film" : "tv")
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title).lineLimit(2)
                if let progress = entry.progress, progress.isFinite {
                    Text("\(Int(progress))% bekeken").font(.caption).foregroundStyle(.secondary)
                } else if let rating = entry.rating {
                    Text("\(rating)/10").font(.caption).foregroundStyle(.secondary)
                } else if let date = entry.watchedAt {
                    Text("Bekeken op \(date.prefix(10))").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(.vertical, 10)
    }
}

struct TraktListView: View {
    let list: TraktList
    @ObservedObject private var store = TraktStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [TraktEntry] = []
    @State private var loading = true
    @State private var error: String?
    @State private var editedName = ""
    @State private var confirmDelete = false
    @State private var entryToRemove: TraktEntry?
    @State private var saving = false
    var body: some View {
        List {
            Section(store.lists.first(where: { $0.id == list.id })?.name ?? list.name) {
                if loading { ProgressView("Lijst laden…") }
                else if entries.isEmpty { Text("Deze lijst is leeg.") }
                ForEach(entries, id: \.rowID) { entry in
                    HStack {
                        NavigationLink { TraktDestinationView(entry: entry) } label: { TraktEntryLabel(entry: entry) }
                        Button("Verwijderen", role: .destructive) { entryToRemove = entry }
                    }
                }
            }
            Section("Lijst beheren") {
                TextField("Naam", text: $editedName)
                Button("Naam opslaan") {
                    perform { try await store.renameList(list, name: editedName) }
                }.disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Lijst verwijderen", role: .destructive) { confirmDelete = true }
                Button("Vernieuwen") { Task { await load() } }
            }.disabled(saving || loading)
            if let error { Text(error).foregroundStyle(.orange) }
        }
        .task { editedName = list.name; await load() }
        .confirmationDialog("Deze lijst definitief uit Trakt verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Lijst verwijderen", role: .destructive) {
                perform { try await store.deleteList(list); dismiss() }
            }
        }
        .confirmationDialog("Titel uit deze lijst verwijderen?", isPresented: Binding(get: { entryToRemove != nil }, set: { if !$0 { entryToRemove = nil } }), titleVisibility: .visible) {
            if let entry = entryToRemove {
                Button("Verwijderen", role: .destructive) {
                    perform { try await store.remove(entry, from: list); await load() }
                }
            }
        }
    }
    private func load() async {
        loading = true; error = nil
        do { entries = try await store.listItems(list) } catch { self.error = error.localizedDescription }
        loading = false
    }
    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        saving = true; error = nil
        Task {
            do { try await action() } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}

/// Resolve Trakt IDs through the existing metadata services before entering Veyra's detail flow.
struct TraktDestinationView: View {
    let entry: TraktEntry
    @State private var movie: MediaItem?
    @State private var series: TMDBSeries?
    @State private var details: TMDBSeriesDetails?
    @State private var episode: TMDBEpisode?
    @State private var season: TMDBSeason?
    @State private var error: String?
    var body: some View {
        Group {
            if let movie { MovieDetailView(movie: movie) }
            else if let details, let episode { EpisodeView(series: details, episode: episode) }
            else if let details, let season { SeasonView(series: details, season: season) }
            else if let series { SeriesDetailView(series: series) }
            else if let error {
                VStack(spacing: 24) {
                    Text(error)
                    Button("Opnieuw proberen") { Task { await resolve() } }
                }.padding(70)
            } else { ProgressView("Titel openen…") }
        }
        .task { await resolve() }
    }
    private func resolve() async {
        error = nil
        do {
            if let film = entry.movie, let id = film.ids.tmdb {
                guard let service = TMDBService() else { throw TraktError.configuration }
                movie = try await service.mediaItem(forMovieID: id)
            } else if let show = entry.show, let id = show.ids.tmdb {
                guard let service = SeriesService() else { throw TraktError.configuration }
                let value = try await service.seriesDetails(id: id)
                if let ep = entry.episode, let number = ep.number, let seasonNumber = ep.season {
                    let seasonData = try await service.season(seriesID: id, seasonNumber: seasonNumber)
                    guard let resolved = seasonData.episodes.first(where: { $0.episodeNumber == number }) else { throw TraktError.missingMedia }
                    details = value; episode = resolved
                } else if let seasonNumber = entry.season?.number,
                          let resolved = value.seasons.first(where: { $0.seasonNumber == seasonNumber }) {
                    details = value; season = resolved
                } else {
                    series = TMDBSeries(id: id, name: value.name, overview: value.overview,
                                        posterPath: value.posterPath, backdropPath: value.backdropPath,
                                        firstAirDate: value.firstAirDate, voteAverage: value.voteAverage)
                }
            } else { throw TraktError.missingMedia }
        } catch { self.error = error.localizedDescription }
    }
}
