import SwiftUI

/// Knop om een film/serie in één klik als bekeken/niet bekeken te markeren
/// bij Trakt -- de tvOS-tegenhanger van
/// `Veyra-iOS/Trakt/WatchedToggleButton.swift`. Voor series markeert dit de
/// hele serie (alle uitgezonden afleveringen), net als het bestaande
/// lang-indruk-menu (`.traktMarkWatchedMenu(_:)`), dat hiernaast blijft
/// bestaan voor losse afleveringen.
struct WatchedToggleButton: View {
    let item: MediaItem

    @ObservedObject private var traktStore = TraktStore.shared
    @State private var isUpdating = false

    private var isWatched: Bool { traktStore.isWatched(item) }

    var body: some View {
        if item.canSyncTrakt {
            Button {
                toggle()
            } label: {
                VeyraActionLabel(
                    title: isWatched ? "BEKEKEN" : "MARKEER BEKEKEN",
                    symbol: isWatched ? "eye.fill" : "eye",
                    compact: true
                )
            }
            // Bij "bekeken" krijgt de knop zelf de cyaan actieve look, i.p.v.
            // een los badge linksboven op de hero-afbeelding.
            .buttonStyle(VeyraFocusButtonStyle(primary: isWatched))
            .disabled(isUpdating)
            .accessibilityLabel(isWatched ? "Markeer als niet bekeken" : "Markeer als bekeken")
        }
    }

    private func toggle() {
        guard !isUpdating else { return }
        isUpdating = true

        Task {
            defer { isUpdating = false }
            do {
                try await traktStore.setWatched(item, watched: !isWatched)
                print("[WatchedToggleButton] setWatched OK item=\(item.title) watched=\(!isWatched)")
            } catch {
                print("[WatchedToggleButton] setWatched FOUT item=\(item.title) watched=\(!isWatched): \(error)")
            }
        }
    }
}
