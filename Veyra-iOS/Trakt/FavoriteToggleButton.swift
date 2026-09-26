import SwiftUI

/// Knop om een film of serie toe te voegen aan of te verwijderen uit de
/// Trakt-favorietenlijst -- de iOS-tegenhanger van `WatchlistToggleButton`,
/// met dezelfde `TraktStore`-API (`sync/favorites`).
struct FavoriteToggleButton: View {
    let item: MediaItem

    /// `true` toont enkel het hartsymbool (vierkante knop, bedoeld om naast
    /// "Afspelen"/Watchlist te staan); `false` toont de volledige tekst +
    /// symbool over de volle breedte.
    var compact = false

    @ObservedObject private var traktStore = TraktStore.shared
    @State private var isUpdating = false

    private var isFavorited: Bool { traktStore.isFavorited(item) }

    var body: some View {
        Button {
            toggle()
        } label: {
            if compact {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.headline)
                    .frame(width: 24)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
            } else {
                Label(
                    isFavorited ? "Verwijder uit favorieten" : "Maak favoriet",
                    systemImage: isFavorited ? "heart.fill" : "heart"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.bordered)
        .tint(VeyraColors.red)
        .disabled(isUpdating)
        .accessibilityLabel(isFavorited ? "Verwijder uit favorieten" : "Maak favoriet")
    }

    private func toggle() {
        guard !isUpdating else { return }
        isUpdating = true

        Task {
            defer { isUpdating = false }
            try? await traktStore.setFavorite(item, included: !isFavorited)
        }
    }
}
