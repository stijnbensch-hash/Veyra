import Foundation

/// Houdt bij of de Home-tab op het hoofdscherm staat of dieper genavigeerd
/// is (bv. een geopende film/serie vanuit "Verder kijken" of vanuit de
/// hero-carrousel), zodat de zwevende zoek-/instellingenknoppen in
/// `ContentView` enkel op het hoofdscherm van Home zichtbaar zijn en niet
/// blijven hangen boven een geopende titel.
///
/// Er zijn meerdere onafhankelijke `.navigationDestination(item:)`-pushes
/// binnen de Home-tab (o.a. in `HomeView` zelf en in `ContinueWatchingRow`),
/// die elk hun eigen lokale @State-binding gebruiken en dus niet via één
/// gedeelde `NavigationPath` te volgen zijn. Elke bron meldt zich hier apart
/// aan/af; zolang minstens één bron actief is, staat Home niet op het
/// hoofdscherm.
@MainActor
final class HomeNavigationState: ObservableObject {
    static let shared = HomeNavigationState()

    @Published private var activePushSources: Set<String> = []

    var isAtRoot: Bool { activePushSources.isEmpty }

    private init() {}

    func setActive(_ active: Bool, source: String) {
        if active {
            activePushSources.insert(source)
        } else {
            activePushSources.remove(source)
        }
    }
}
