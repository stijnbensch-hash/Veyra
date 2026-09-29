import SwiftUI

/// Rij met films/series "van hetzelfde type/genre" als het huidige item --
/// hoort altijd helemaal onderaan een film-/seriedetailscherm, zowel op
/// tvOS als iOS. Navigeert via `ShelfItemDestination`, dezelfde route die de
/// Home-planken al gebruiken, zodat een film naar `MovieDetailView` en een
/// serie naar `SeriesDetailView` gaat.
struct SimilarTitlesRow: View {
    let item: MediaItem

    // Navigatie via de centrale `openMediaDetail`-omgevingsactie (MediaNavigation.swift)
    // i.p.v. `NavigationLink` + eigen destination: deze rij zit onderaan een detailscherm
    // dat zelf al ergens in een NavigationStack met andere `MediaItem`-navigatie hangt
    // (Home-planken, Zoeken, ...), en een tweede destination voor hetzelfde type botst
    // daarmee zodra beide gemonteerd zijn.
    @Environment(\.openMediaDetail) private var openMediaDetail

    @State private var items: [MediaItem] = []

    var body: some View {
        // Niets tonen zolang er niets (meer) gevonden is -- in tegenstelling
        // tot een door de gebruiker aangemaakte plank hoort dit altijd
        // onopvallend te blijven i.p.v. als een lege sectie/foutmelding te
        // ogen wanneer TMDB voor deze titel niets vergelijkbaars teruggeeft.
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                VeyraSectionHeader(title: "Vergelijkbaar")
#if !os(tvOS)
                    .padding(.horizontal)
#endif

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: VeyraSpacing.rail) {
                        ForEach(items) { related in
                            Button { openMediaDetail(related) } label: {
                                VeyraPosterCard(
                                    title: related.title,
                                    url: related.posterURL,
                                    symbol: related.type == .movie ? "film" : "tv",
                                    width: posterWidth,
                                    genre: related.genre,
                                    rating: related.rating,
                                    year: String(related.releaseDate?.prefix(4) ?? ""),
                                    tmdbID: related.tmdbID,
                                    isMovie: related.type == .movie
                                )
                            }
#if os(tvOS)
                            .buttonStyle(VeyraPosterFocusStyle(cornerRadius: VeyraRadius.poster))
#else
                            .buttonStyle(.plain)
#endif
                        }
                    }
#if os(tvOS)
                    .padding(12)
#else
                    .padding(.horizontal)
#endif
                }
#if os(tvOS)
                .scrollClipDisabled()
#endif
            }
            .task(id: item.tmdbID) { await load() }
        } else {
            Color.clear.frame(width: 0, height: 0)
                .task(id: item.tmdbID) { await load() }
        }
    }

    private var posterWidth: CGFloat {
#if os(tvOS)
        240
#else
        130
#endif
    }

    private var sectionSpacing: CGFloat {
#if os(tvOS)
        20
#else
        12
#endif
    }

    private func load() async {
        items = await SimilarTitlesService.similarItems(for: item)
    }
}
