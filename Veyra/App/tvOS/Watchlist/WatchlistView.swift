import SwiftUI

/// "Kijklijst" hoofdmenu-tab: de Trakt-watchlist van de gekoppelde gebruiker,
/// met "Films"/"Series"-knoppen om te wisselen (zoals bij streamingdiensten)
/// i.p.v. alles door elkaar -- de rasterweergave zelf is dezelfde als de
/// Films-tab (zie `MoviesView.swift`), inclusief genre/beoordeling-badge en
/// jaartal.
struct WatchlistView: View {
    // Navigatie via de centrale `openMediaDetail`-omgevingsactie, net als
    // `ShelfRowView` -- werkt voor films én series zonder eigen destination.
    @Environment(\.openMediaDetail) private var openMediaDetail
    @ObservedObject private var trakt = TraktStore.shared

    @State private var movies: [MediaItem] = []
    @State private var series: [MediaItem] = []
    @State private var isLoading = true
    @State private var selectedKind: MediaType = .movie

    private let railSpacing: CGFloat = 32
    private let gridPosterWidth: CGFloat = 240

    var body: some View {
        ZStack(alignment: .top) {
            VeyraArtworkBackground(url: nil)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    VeyraSectionHeader(title: "Kijklijst", subtitle: "Trakt")

                    if trakt.isConnected, !isLoading, !(movies.isEmpty && series.isEmpty) {
                        kindPicker
                    }

                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 36)
                .padding(.bottom, 50)
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .scrollClipDisabled()
        }
        .task { await trakt.refreshIfNeeded() }
        .task(id: reloadKey) { await load() }
    }

    // Herlaadt zodra de koppeling of het aantal items in de watchlist
    // verandert (bv. een item elders, of hier via het lang-indruk-menu,
    // toegevoegd/verwijderd).
    private var reloadKey: String {
        "\(trakt.isConnected)-\(trakt.watchlist.count)"
    }

    // "Films"/"Series"-knoppen om tussen de twee te wisselen, in plaats van
    // beide onder elkaar te tonen -- zoals de vertrouwde indeling bij
    // streamingdiensten.
    private var kindPicker: some View {
        HStack(spacing: 14) {
            kindButton("Films", kind: .movie, count: movies.count)
            kindButton("Series", kind: .series, count: series.count)
        }
    }

    private func kindButton(_ title: String, kind: MediaType, count: Int) -> some View {
        let isSelected = selectedKind == kind
        return Button {
            selectedKind = kind
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .frame(height: 54)
            .background {
                if isSelected {
                    // Zelfde cyaan->rood-verloop als de geselecteerde tab in de
                    // hoofdnavigatie (`VeyraTopNavigation`) -- geen effen/witte vlek.
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [VeyraColors.cyan.opacity(0.22), VeyraColors.cyan.opacity(0.08), VeyraColors.red.opacity(0.09)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .overlay(Capsule().strokeBorder(VeyraColors.ice.opacity(0.35)))
                } else {
                    Capsule().strokeBorder(Color.white.opacity(0.16))
                }
            }
        }
        .buttonStyle(KindChipButtonStyle())
        .disabled(count == 0)
        .opacity(count == 0 ? 0.4 : 1)
    }

    /// Onderdrukt tvOS' eigen (witte) focus-gloed op deze knoppen -- die overstemde de
    /// cyaan/rode kaartkleuren hierboven volledig zodra de knop focus kreeg. Zelfde
    /// aanpak als elders in de app (bv. `VeyraNavigationButtonStyle`): een eigen, subtiel
    /// cyaan kader + lichte vergroting bij focus i.p.v. het systeem-effect.
    private struct KindChipButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            Inner(configuration: configuration)
        }

        private struct Inner: View {
            let configuration: ButtonStyleConfiguration
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .overlay(
                        Capsule().strokeBorder(VeyraColors.cyan, lineWidth: isFocused ? 2.5 : 0)
                    )
                    .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.5) : .clear, radius: 12)
                    .scaleEffect(isFocused ? 1.05 : (configuration.isPressed ? 0.97 : 1))
                    .animation(.easeOut(duration: 0.16), value: isFocused)
                    .focusEffectDisabled()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Kijklijst laden…")
                .font(.title3)

            Spacer()

        } else if !trakt.isConnected {
            VStack(alignment: .leading, spacing: 14) {
                Text("Niet verbonden met Trakt")
                    .font(.title2)

                Text("Koppel je Trakt-account bij Account om je kijklijst hier te zien.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

        } else if movies.isEmpty && series.isEmpty {
            Text("Je kijklijst is leeg.")
                .foregroundStyle(.secondary)

            Spacer()

        } else {
            let items = selectedKind == .movie ? movies : series
            if items.isEmpty {
                Text(selectedKind == .movie ? "Geen films op je kijklijst." : "Geen series op je kijklijst.")
                    .foregroundStyle(.secondary)

                Spacer()
            } else {
                grid(items)
            }
        }
    }

    @ViewBuilder
    private func grid(_ items: [MediaItem]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: gridPosterWidth, maximum: gridPosterWidth + 40), spacing: railSpacing)
            ],
            spacing: 40
        ) {
            ForEach(items) { item in
                card(item)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 16)
    }

    private func card(_ item: MediaItem) -> some View {
        Button { openMediaDetail(item) } label: {
            VeyraPosterCard(
                title: item.title,
                url: item.posterURL,
                symbol: item.type == .movie ? "film" : "tv",
                width: gridPosterWidth,
                genre: item.genre,
                rating: item.rating,
                year: String(item.releaseDate?.prefix(4) ?? ""),
                tmdbID: item.tmdbID,
                isMovie: item.type == .movie
            )
        }
        .buttonStyle(VeyraPosterFocusStyle(cornerRadius: VeyraRadius.poster))
        .reportsHero(.mediaItem(item))
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
