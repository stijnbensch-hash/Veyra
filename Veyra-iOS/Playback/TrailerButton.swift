import SwiftUI

/// Knop om de YouTube-trailer van de film/serie op te halen via TMDB en af
/// te spelen in een volledig-scherm webweergave (`TrailerSheet`, in
/// Shared/Playback). Gebruikt geen AetherEngine: TMDB geeft enkel een
/// YouTube-sleutel terug, geen rechtstreekse streambron.
struct TrailerButton: View {
    let tmdbID: Int?
    let isShow: Bool

    /// `true` toont enkel het filmsymbool (vierkante knop, bedoeld om naast
    /// Watched/Favoriet/Watchlist te staan); `false` toont de volledige
    /// tekst + symbool over de volle breedte, naast "Afspelen".
    var compact = false

    @State private var youtubeKey: String?
    @State private var isLoading = false
    @State private var isPresentingPlayer = false
    @State private var showUnavailableAlert = false

    var body: some View {
        if let tmdbID {
            Button {
                Task { await playOrFetch(tmdbID: tmdbID) }
            } label: {
                if compact {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "film")
                        }
                    }
                    .font(.headline)
                    .frame(width: 24)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Label("Trailer", systemImage: "film")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.bordered)
            .tint(VeyraColors.cyan)
            .disabled(isLoading)
            .accessibilityLabel("Speel trailer af")
            .fullScreenCover(isPresented: $isPresentingPlayer) {
                if let youtubeKey {
                    TrailerSheet(youtubeKey: youtubeKey)
                }
            }
            .alert("Geen trailer beschikbaar", isPresented: $showUnavailableAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func playOrFetch(tmdbID: Int) async {
        if youtubeKey != nil {
            isPresentingPlayer = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        let key = isShow
            ? await MetadataTrailerService.youtubeKey(forSeriesTmdbID: tmdbID)
            : await MetadataTrailerService.youtubeKey(forMovieTmdbID: tmdbID)

        youtubeKey = key
        if key != nil {
            isPresentingPlayer = true
        } else {
            showUnavailableAlert = true
        }
    }
}
