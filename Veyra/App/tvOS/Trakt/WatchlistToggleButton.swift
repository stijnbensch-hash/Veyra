import SwiftUI

/// Knop om een film, serie of aflevering toe te voegen aan of te
/// verwijderen uit de Trakt-watchlist — de tvOS-tegenhanger van de
/// gelijknamige component op iOS (`Veyra-iOS/Trakt/WatchlistToggleButton.swift`),
/// met dezelfde `TraktStore`-API. Verschijnt naast de "AFSPELEN"-knop op de
/// film-/aflevering-infopagina en bij de series-infopagina.
struct WatchlistToggleButton: View {
    let item: MediaItem

    @ObservedObject private var traktStore = TraktStore.shared
    @State private var isUpdating = false

    private var isWatchlisted: Bool { traktStore.isWatchlisted(item) }

    var body: some View {
        if item.canSyncTrakt {
            Button {
                toggle()
            } label: {
                VeyraActionLabel(
                    title: isWatchlisted ? "OP WATCHLIST" : "WATCHLIST",
                    symbol: isWatchlisted ? "bookmark.fill" : "bookmark"
                )
            }
            .buttonStyle(VeyraFocusButtonStyle())
            .disabled(isUpdating)
            .accessibilityLabel(isWatchlisted ? "Verwijder uit watchlist" : "Voeg toe aan watchlist")
        }
    }

    private func toggle() {
        guard !isUpdating else { return }
        isUpdating = true

        Task {
            defer { isUpdating = false }
            try? await traktStore.setWatchlist(item, included: !isWatchlisted)
        }
    }
}
