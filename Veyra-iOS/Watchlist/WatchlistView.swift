import SwiftUI

/// "Kijklijst" hoofdmenu-tab (iOS/iPad): de Trakt-watchlist van de gekoppelde
/// gebruiker, met "Films"/"Series"-knoppen om te wisselen (zoals bij
/// streamingdiensten) i.p.v. alles door elkaar -- de rasterweergave zelf is
/// dezelfde als de Films-tab (zie `Movies/MoviesView.swift`), inclusief
/// genre/beoordeling-badge en jaartal.
struct WatchlistView: View {
    @Environment(\.openMediaDetail) private var openMediaDetail
    @ObservedObject private var trakt = TraktStore.shared
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var movies: [MediaItem] = []
    @State private var series: [MediaItem] = []
    @State private var isLoading = true
    @State private var selectedKind: MediaType = .movie

    private var metrics: VeyraPosterMetrics { VeyraPosterMetrics(regular: sizeClass == .regular) }
    private var columns: [GridItem] { metrics.columns }

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraArtworkBackground(url: nil)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if trakt.isConnected, !isLoading, !(movies.isEmpty && series.isEmpty) {
                            kindPicker
                                .padding(.horizontal)
                        }

                        content
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Kijklijst")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await trakt.refreshIfNeeded() }
        .task(id: reloadKey) { await load() }
    }

    private var reloadKey: String {
        "\(trakt.isConnected)-\(trakt.watchlist.count)"
    }

    // "Films"/"Series"-knoppen om tussen de twee te wisselen, in plaats van
    // beide onder elkaar te tonen -- zoals de vertrouwde indeling bij
    // streamingdiensten.
    private var kindPicker: some View {
        HStack(spacing: 10) {
            kindButton("Films", kind: .movie, count: movies.count)
            kindButton("Series", kind: .series, count: series.count)
            Spacer()
        }
    }

    private func kindButton(_ title: String, kind: MediaType, count: Int) -> some View {
        let isSelected = selectedKind == kind
        return Button {
            selectedKind = kind
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background {
                if isSelected {
                    // Zelfde cyaan->rood-verloop als de geselecteerde hoofdmenu-tab
                    // (tvOS' `VeyraTopNavigation`) -- geen effen/witte vlek.
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [VeyraColors.cyan.opacity(0.28), VeyraColors.cyan.opacity(0.10), VeyraColors.red.opacity(0.12)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .overlay(Capsule().strokeBorder(VeyraColors.ice.opacity(0.4)))
                } else {
                    Capsule().strokeBorder(Color.white.opacity(0.18))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .opacity(count == 0 ? 0.4 : 1)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Kijklijst laden…")
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)

        } else if !trakt.isConnected {
            VStack(alignment: .leading, spacing: 10) {
                Text("Niet verbonden met Trakt")
                    .font(.headline)

                Text("Koppel je Trakt-account bij Account om je kijklijst hier te zien.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

        } else if movies.isEmpty && series.isEmpty {
            Text("Je kijklijst is leeg.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

        } else {
            let items = selectedKind == .movie ? movies : series
            if items.isEmpty {
                Text(selectedKind == .movie ? "Geen films op je kijklijst." : "Geen series op je kijklijst.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                LazyVGrid(columns: columns, spacing: metrics.rowSpacing) {
                    ForEach(items) { item in
                        card(item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func card(_ item: MediaItem) -> some View {
        Button { openMediaDetail(item) } label: {
            VeyraPosterCard(
                title: item.title,
                url: item.posterURL,
                symbol: item.type == .movie ? "film" : "tv",
                width: metrics.posterWidth,
                genre: item.genre,
                rating: item.rating,
                year: String(item.releaseDate?.prefix(4) ?? ""),
                tmdbID: item.tmdbID,
                isMovie: item.type == .movie
            )
        }
        .buttonStyle(.plain)
        .traktMarkWatchedMenu(item) {
            Button(role: .destructive) {
                Task { try? await trakt.setWatchlist(item, included: false) }
            } label: {
                Label("Verwijderen van kijklijst", systemImage: "bookmark.slash")
            }
        }
    }

    private func load() async {
        isLoading = true

        guard trakt.isConnected else {
            movies = []
            series = []
            isLoading = false
            return
        }

        async let fetchedMovies = ShelfCatalogService.items(
            for: Shelf(title: "Kijklijst", source: .trakt(list: .watchlist, kind: .movie))
        )
        async let fetchedSeries = ShelfCatalogService.items(
            for: Shelf(title: "Kijklijst", source: .trakt(list: .watchlist, kind: .series))
        )

        movies = await fetchedMovies
        series = await fetchedSeries
        isLoading = false
    }
}
