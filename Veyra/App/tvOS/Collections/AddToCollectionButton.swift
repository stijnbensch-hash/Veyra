import SwiftUI

/// Knop om "Toevoegen aan collectie" te openen -- de tvOS-tegenhanger van
/// `Veyra-iOS/Collections/AddToCollectionButton.swift`. Verschijnt naast de
/// "AFSPELEN"/Watchlist/Favoriet-knoppen op de film-infopagina, zelfde opzet als
/// `FavoriteToggleButton`/`WatchlistToggleButton`. Geen toggle: een film kan in meerdere
/// collecties tegelijk zitten (spec §19), dus dit opent altijd de kies-lijst.
struct AddToCollectionButton: View {
    let item: MediaItem

    @ObservedObject private var store = VeyraCollectionStore.shared
    @State private var showSheet = false

    private var isInAnyCollection: Bool { !store.collectionsContaining(item).isEmpty }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            VeyraActionLabel(
                title: isInAnyCollection ? "IN COLLECTIE" : "COLLECTIE",
                symbol: isInAnyCollection ? "rectangle.stack.fill.badge.plus" : "rectangle.stack.badge.plus",
                compact: true
            )
        }
        .buttonStyle(VeyraFocusButtonStyle())
        .accessibilityLabel("Toevoegen aan collectie")
        .sheet(isPresented: $showSheet) {
            NavigationStack { VeyraAddToCollectionSheet(item: item) }
        }
    }
}
