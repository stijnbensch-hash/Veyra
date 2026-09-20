import SwiftUI

enum VeyraWatchedPartialDisplay {
    case watchedCount
    case remaining
    case hidden
}

struct VeyraWatchedBadge: View {
    let target: TraktWatchedTarget
    var partialDisplay: VeyraWatchedPartialDisplay = .watchedCount
    @ObservedObject private var store = TraktStore.shared
    private var status: TraktWatchedStatus {
        guard store.isConnected else { return .none }
        return .resolve(target, movies: store.watchedMovies, shows: store.watchedShows, progress: store.upNext)
    }
    var body: some View {
        Group {
            switch status {
            case .none: EmptyView()
            case .watched:
                badge("Bekeken", symbol: "checkmark.circle.fill")
            case .partial(let count, let total):
                switch partialDisplay {
                case .watchedCount:
                    badge(total.map { "\(count)/\($0) bekeken" } ?? "\(count) bekeken", symbol: "circle.lefthalf.filled")
                case .remaining:
                    if let total {
                        let remaining = max(total - count, 0)
                        if remaining > 0 {
                            badge(
                                remaining == 1
                                    ? "1 aflevering te gaan"
                                    : "\(remaining) afleveringen te gaan",
                                symbol: "clock.fill"
                            )
                        }
                    }
                case .hidden:
                    EmptyView()
                }
            }
        }.allowsHitTesting(false)
    }
    private func badge(_ title: String, symbol: String) -> some View {
        VeyraPosterBadge(
            title: title,
            symbol: symbol,
            accent: VeyraColors.cyan,
            fontSize: 16
        )
            .accessibilityLabel("\(title) via Trakt")
    }
}
extension View {
    func traktWatched(
        _ target: TraktWatchedTarget,
        partialDisplay: VeyraWatchedPartialDisplay = .watchedCount
    ) -> some View {
        overlay(alignment: .topTrailing) {
            VeyraWatchedBadge(
                target: target,
                partialDisplay: partialDisplay
            )
            .padding(12)
        }
    }
}

// MARK: - Long-press "mark as watched" menu

private struct TraktMarkWatchedMenuModifier: ViewModifier {
    let item: MediaItem
    @ObservedObject private var store = TraktStore.shared

    func body(content: Content) -> some View {
        if store.isConnected && item.canSyncTrakt {
            content.contextMenu {
                let watched = store.isWatched(item)
                Button(watched ? "Markeer als niet bekeken" : "Markeer als bekeken") {
                    Task { try? await store.setWatched(item, watched: !watched) }
                }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Voegt een lang-indruk-menu toe waarmee een film of aflevering
    /// direct als bekeken/niet bekeken bij Trakt gemarkeerd kan worden.
    func traktMarkWatchedMenu(_ item: MediaItem) -> some View {
        modifier(TraktMarkWatchedMenuModifier(item: item))
    }
}
