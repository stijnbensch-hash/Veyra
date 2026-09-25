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
/// Compacte "bekeken"-indicator: enkel een vinkje in een cirkel, zonder tekst — voor smalle postercards
/// (bv. de streamingdienst-catalogus op iOS) waar de tekstbadge van `VeyraWatchedBadge` niet past.
/// Bij een gedeeltelijk bekeken seizoen/serie valt dit terug op de tekstbadge van `VeyraWatchedBadge`
/// (via `partialDisplay`), want "X afleveringen te gaan" past niet in een los vinkje.
struct VeyraWatchedCheckmark: View {
    let target: TraktWatchedTarget
    var partialDisplay: VeyraWatchedPartialDisplay = .hidden
    @ObservedObject private var store = TraktStore.shared

    private var status: TraktWatchedStatus {
        guard store.isConnected else { return .none }
        return .resolve(target, movies: store.watchedMovies, shows: store.watchedShows, progress: store.upNext)
    }

    var body: some View {
        switch status {
        case .none:
            EmptyView()
        case .watched:
            checkmark
        case .partial:
            if partialDisplay == .hidden {
                EmptyView()
            } else {
                VeyraWatchedBadge(target: target, partialDisplay: partialDisplay)
            }
        }
    }

    // tvOS bekijk je van op de bank (10-foot UI) -- het kleine vinkje was
    // daar amper te onderscheiden van de poster zelf, dus flink groter dan
    // op iOS/iPadOS.
#if os(tvOS)
    private var checkmarkDiameter: CGFloat { 40 }
    private var checkmarkIconSize: CGFloat { 17 }
    private var checkmarkStrokeWidth: CGFloat { 2 }
#else
    private var checkmarkDiameter: CGFloat { 26 }
    private var checkmarkIconSize: CGFloat { 11 }
    private var checkmarkStrokeWidth: CGFloat { 1.5 }
#endif

    private var checkmark: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().stroke(VeyraColors.cyan.opacity(0.95), lineWidth: checkmarkStrokeWidth)
            Image(systemName: "checkmark")
                .font(.system(size: checkmarkIconSize, weight: .bold))
                .foregroundStyle(VeyraColors.cyan)
        }
        .frame(width: checkmarkDiameter, height: checkmarkDiameter)
        .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
        .accessibilityLabel("Bekeken")
    }
}

extension View {
    /// Compacte vinkje-badge i.p.v. de tekstbadge (zie `VeyraWatchedCheckmark`). `partialDisplay`
    /// bepaalt wat een gedeeltelijk bekeken seizoen/serie toont (standaard: niets).
    func traktWatchedCheckmark(_ target: TraktWatchedTarget, partialDisplay: VeyraWatchedPartialDisplay = .hidden) -> some View {
        overlay(alignment: .topTrailing) {
            VeyraWatchedCheckmark(target: target, partialDisplay: partialDisplay)
                .padding(7)
                .allowsHitTesting(false)
        }
    }

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
