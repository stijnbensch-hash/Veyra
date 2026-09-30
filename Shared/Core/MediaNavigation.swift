// MediaNavigation.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
//
// Eén centrale plek om een `MediaItem` te openen (details of meteen afspelen),
// i.p.v. dat elk scherm z'n eigen `@State` + `.navigationDestination(item:)`
// voor hetzelfde type registreert. Met meerdere gelijktijdig gemonteerde
// bronnen in dezelfde `NavigationStack` (bv. de Home-planken, "Vergelijkbaar"
// onderaan een detailscherm, Zoeken) botsen zulke lokale destinations met
// elkaar zodra er meer dan één actief is -- dat liet "terug naar Home"
// vastlopen (zie ShelfRowView-fix). Eén `NavigationStack` registreert deze
// twee destinations daarom precies éénmaal via `.mediaNavigationRoot()`, en
// alle onderliggende schermen roepen enkel de omgevingsvariabelen hieronder
// aan om te navigeren.
//
// Op tvOS is er maar één `NavigationStack` voor de hele app (`ContentView`),
// dus daar hoeft dit maar op één plek te staan. Op iOS/iPadOS/macOS heeft elk
// tabblad (Home/Films/Series/Zoeken) zijn eigen `NavigationStack`, dus daar
// past elk tabblad dit toe op zijn eigen root.
//
// BELANGRIJKE SwiftUI-valkuil: een view kan de omgevingswaarde die het via
// `.mediaNavigationRoot()` op zijn EIGEN `body`-uitvoer zet, niet met een
// gewone `@Environment`-property op zichzelf terug uitlezen -- die property
// wordt al bepaald op basis van de omgeving die de view van zijn OUDER
// binnenkrijgt, dus vóór zijn eigen `.mediaNavigationRoot()` ooit toegepast
// is. Zo'n `@Environment(\.openMediaDetail)` blijft dan altijd de stille
// no-op default, en een tik doet letterlijk niets (geen crash, geen
// foutmelding). Trof `Films`/`Kijklijst`: die schermen zíjn zelf de root
// van hun `NavigationStack` én wilden ook zelf `openMediaDetail` aanroepen
// voor hun eigen rasterweergave -- opgelost door daar gewoon een directe
// `NavigationLink { ShelfItemDestination(item: item) }` te gebruiken i.p.v.
// de omgevingsactie. Onderliggende schermen (`ShelfRowView`, "Vergelijkbaar"
// onderaan een detailscherm) hebben dit niet: dat zijn echte child-views,
// verderop in de boom dan waar `.mediaNavigationRoot()` de waarde zet.

import SwiftUI

private struct OpenMediaDetailKey: EnvironmentKey {
    static let defaultValue: (MediaItem) -> Void = { _ in }
}

private struct PlayMediaItemKey: EnvironmentKey {
    static let defaultValue: (MediaItem) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Opent het detailscherm voor dit item (film/serie/IPTV-serie/live-kanaal
    /// -- `ShelfItemDestination` bepaalt zelf welk scherm dat is).
    var openMediaDetail: (MediaItem) -> Void {
        get { self[OpenMediaDetailKey.self] }
        set { self[OpenMediaDetailKey.self] = newValue }
    }

    /// Speelt dit item meteen af (bronkeuze, geen tussenliggend detailscherm)
    /// -- gebruikt door Instant Peek's "Afspelen"-knop.
    var playMediaItem: (MediaItem) -> Void {
        get { self[PlayMediaItemKey.self] }
        set { self[PlayMediaItemKey.self] = newValue }
    }
}

private struct MediaNavigationRootModifier: ViewModifier {
    @State private var detailItem: MediaItem?
    @State private var playItem: MediaItem?

    func body(content: Content) -> some View {
        content
            .environment(\.openMediaDetail, { detailItem = $0 })
            .environment(\.playMediaItem, { playItem = $0 })
            .navigationDestination(item: $detailItem) { item in
                ShelfItemDestination(item: item)
            }
            .navigationDestination(item: $playItem) { item in
                SourceSelectionView(item: item)
            }
    }
}

extension View {
    /// Registreert de twee `MediaItem`-destinations hierboven precies één
    /// keer voor de omringende `NavigationStack`. Toepassen op de inhoud van
    /// élke top-level `NavigationStack` (tvOS: `ContentView`; iOS: elk
    /// tabblad), nooit op onderliggende schermen zelf.
    func mediaNavigationRoot() -> some View {
        modifier(MediaNavigationRootModifier())
    }
}
