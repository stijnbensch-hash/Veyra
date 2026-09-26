import SwiftUI

/// Knop om een film of serie toe te voegen aan of te verwijderen uit de
/// Trakt-favorietenlijst -- de tvOS-tegenhanger van
/// `Veyra-iOS/Trakt/FavoriteToggleButton.swift`, met dezelfde
/// `TraktStore`-API (`sync/favorites`). Verschijnt naast de
/// "AFSPELEN"/Watchlist-knoppen op de film-/serie-infopagina.
struct FavoriteToggleButton: View {
    let item: MediaItem

    @ObservedObject private var traktStore = TraktStore.shared
    @State private var isUpdating = false

    private var isFavorited: Bool { traktStore.isFavorited(item) }

    var body: some View {
        if item.canSyncTrakt {
            Button {
                toggle()
            } label: {
                VeyraActionLabel(
                    title: isFavorited ? "FAVORIET" : "FAVORIET MAKEN",
                    symbol: isFavorited ? "heart.fill" : "heart",
                    compact: true
                )
            }
            .buttonStyle(VeyraFocusButtonStyle())
            .disabled(isUpdating)
            .accessibilityLabel(isFavorited ? "Verwijder uit favorieten" : "Maak favoriet")
        }
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
