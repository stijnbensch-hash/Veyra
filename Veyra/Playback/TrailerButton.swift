import SwiftUI
import UIKit

/// Knop om de YouTube-trailer van de film/serie op te halen via TMDB -- de
/// tvOS-tegenhanger van `Veyra-iOS/Playback/TrailerButton.swift`.
///
/// Anders dan op iOS kan dit geen ingesloten webweergave gebruiken: tvOS
/// heeft geen publiek WebKit-framework (geen `WKWebView`, geen Safari om
/// naar door te verwijzen), dus een trailer inline afspelen is hier niet
/// mogelijk. In plaats daarvan opent dit de trailer in de YouTube-app zelf
/// als die op het toestel staat; is die er niet, dan verschijnt een melding
/// in plaats van een stille mislukking.
struct TrailerButton: View {
    let tmdbID: Int?
    let isShow: Bool

    @State private var isLoading = false
    @State private var showUnavailableAlert = false
    @State private var alertMessage = ""

    var body: some View {
        if let tmdbID {
            Button {
                Task { await fetchAndOpen(tmdbID: tmdbID) }
            } label: {
                VeyraActionLabel(
                    title: isLoading ? "LADEN…" : "TRAILER",
                    symbol: "film",
                    compact: true
                )
            }
            .buttonStyle(VeyraFocusButtonStyle())
            .disabled(isLoading)
            .alert("Trailer", isPresented: $showUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func fetchAndOpen(tmdbID: Int) async {
        isLoading = true
        defer { isLoading = false }

        let key = isShow
            ? await MetadataTrailerService.youtubeKey(forSeriesTmdbID: tmdbID)
            : await MetadataTrailerService.youtubeKey(forMovieTmdbID: tmdbID)

        guard let key else {
            alertMessage = "Geen trailer beschikbaar voor deze titel."
            showUnavailableAlert = true
            return
        }

        guard let appURL = URL(string: "youtube://www.youtube.com/watch?v=\(key)"),
              UIApplication.shared.canOpenURL(appURL)
        else {
            alertMessage = "De YouTube-app staat niet op dit Apple TV -- installeer die om trailers te bekijken (Apple TV heeft geen ingebouwde browser om de trailer anders te tonen)."
            showUnavailableAlert = true
            return
        }

        await UIApplication.shared.open(appURL)
    }
}
