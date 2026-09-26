import SwiftUI

/// Rij met films/series "van hetzelfde type/genre" als het huidige item --
/// hoort altijd helemaal onderaan een film-/seriedetailscherm, zowel op
/// tvOS als iOS. Navigeert via `ShelfItemDestination`, dezelfde route die de
/// Home-planken al gebruiken, zodat een film naar `MovieDetailView` en een
/// serie naar `SeriesDetailView` gaat.
struct SimilarTitlesRow: View {
    let item: MediaItem

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
                            NavigationLink {
                                ShelfItemDestination(item: related)
                            } label: {
                                VeyraPosterCard(
                                    title: related.title,
                                    url: related.posterURL,
                                    symbol: related.type == .movie ? "film" : "tv",
                                    width: posterWidth,
                                    genre: related.genre,
                                    rating: related.rating
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
