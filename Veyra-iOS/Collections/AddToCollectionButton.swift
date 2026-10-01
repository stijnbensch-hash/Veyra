import SwiftUI

/// Knop om "Toevoegen aan collectie" te openen -- de iOS-tegenhanger van
/// `Veyra/App/tvOS/Collections/AddToCollectionButton.swift`. Geen toggle zoals
/// Favoriet/Watchlist: een film kan in meerdere collecties tegelijk zitten (spec §19), dus dit
/// opent altijd de kies-lijst (`VeyraAddToCollectionSheet`) i.p.v. direct te schakelen.
struct AddToCollectionButton: View {
    let item: MediaItem

    /// `true` toont enkel het symbool (vierkante knop, naast Favoriet/Watchlist); `false` toont
    /// de volledige tekst + symbool over de volle breedte.
    var compact = false

    @ObservedObject private var store = VeyraCollectionStore.shared
    @State private var showSheet = false

    private var isInAnyCollection: Bool { !store.collectionsContaining(item).isEmpty }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            if compact {
                Image(systemName: isInAnyCollection ? "rectangle.stack.fill.badge.plus" : "rectangle.stack.badge.plus")
                    .font(.headline)
                    .frame(width: 24)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
            } else {
                Label("Toevoegen aan collectie", systemImage: "rectangle.stack.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .buttonStyle(.bordered)
        .tint(VeyraColors.cyan)
        .accessibilityLabel("Toevoegen aan collectie")
        .sheet(isPresented: $showSheet) {
            NavigationStack { VeyraAddToCollectionSheet(item: item) }
        }
    }
}
