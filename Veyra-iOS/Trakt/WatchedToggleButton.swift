import SwiftUI

/// Compacte knop om een film/serie in één tik als bekeken/niet bekeken te
/// markeren bij Trakt (het oog-symbool) -- naast Afspelen/Watchlist/
/// Favoriet. Voor series is dit "de hele serie" net als het lang-indruk-menu
/// via `.traktMarkWatchedMenu(_:)`; per-aflevering bekeken-status blijft op
/// de afleveringenlijst zelf.
struct WatchedToggleButton: View {
    let item: MediaItem

    @ObservedObject private var traktStore = TraktStore.shared
    @State private var isUpdating = false

    private var isWatched: Bool { traktStore.isWatched(item) }

    var body: some View {
        Button {
            toggle()
        } label: {
            Image(systemName: isWatched ? "eye.fill" : "eye")
                .font(.headline)
                .frame(width: 24)
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.bordered)
        .tint(VeyraColors.cyan)
        .disabled(isUpdating)
        .accessibilityLabel(isWatched ? "Markeer als niet bekeken" : "Markeer als bekeken")
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
