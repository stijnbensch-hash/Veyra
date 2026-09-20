import SwiftUI

/// Knop om een film of serie toe te voegen aan of te verwijderen uit de
/// Trakt-watchlist. Hoort thuis op de infopagina (`MovieDetailView`,
/// `SeriesDetailView`) — niet op de posters zelf, op verzoek van de
/// gebruiker verplaatst vanaf de Films/Series-rasters.
struct WatchlistToggleButton: View {
    let item: MediaItem

    /// `true` toont enkel het bladwijzersymbool (vierkante knop, bedoeld om
    /// naast de "Afspelen"-knop te staan); `false` toont de volledige
    /// tekst + symbool over de volle breedte.
    var compact = false

    @ObservedObject private var traktStore = TraktStore.shared
    @State private var isUpdating = false

    private var isWatchlisted: Bool { traktStore.isWatchlisted(item) }

    var body: some View {
        Button {
            toggle()
        } label: {
            if compact {
                Image(systemName: isWatchlisted ? "bookmark.fill" : "bookmark")
                    .font(.headline)
                    .frame(width: 24)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
            } else {
                Label(
                    isWatchlisted ? "Verwijder uit watchlist" : "Voeg toe aan watchlist",
                    systemImage: isWatchlisted ? "bookmark.fill" : "bookmark"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.bordered)
        .tint(VeyraColors.cyan)
        .disabled(isUpdating)
        .accessibilityLabel(isWatchlisted ? "Verwijder uit watchlist" : "Voeg toe aan watchlist")
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
