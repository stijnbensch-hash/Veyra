import SwiftUI

extension View {
    @ViewBuilder
    func veyraHideNavigationBar() -> some View {
        #if os(iOS)
        // Bugfix (dubbele terugpijl in Zoeken): `.toolbar(.hidden, for: .navigationBar)` alleen
        // onderdrukt de balk/titel, maar niet altijd de systeem-terugknop zelf -- die blijft dan
        // als los element bestaan. Normaal valt dat onzichtbaar samen met de eigen
        // `BackButtonCircle()`-overlay (zelfde positie bij een gewone push), maar binnen een
        // `.sheet` (bv. Zoeken op iPhone) ligt de safe-area net anders, waardoor beide zichtbaar
        // naast/onder elkaar verschenen. `navigationBarBackButtonHidden` onderdrukt 'm expliciet.
        toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        #else
        self
        #endif
    }

    @ViewBuilder
    func veyraAlwaysEditing() -> some View {
        #if os(iOS)
        environment(\.editMode, .constant(.active))
        #else
        self
        #endif
    }

    @ViewBuilder
    func veyraTeamSearch(text: Binding<String>) -> some View {
        #if os(iOS)
        searchable(text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zoek een team")
        #else
        searchable(text: text, prompt: "Zoek een team")
        #endif
    }

    @ViewBuilder
    func veyraTrailerPresentation(isPresented: Binding<Bool>, youtubeKey: String?) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented) {
            if let youtubeKey { TrailerSheet(youtubeKey: youtubeKey) }
        }
        #elseif os(macOS)
        sheet(isPresented: isPresented) {
            if let youtubeKey { TrailerSheet(youtubeKey: youtubeKey) }
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func veyraPlayerPresentation(item: Binding<PlayableSource?>) -> some View {
        #if os(iOS)
        fullScreenCover(item: item) { source in PlayerView(source: source) }
        #elseif os(macOS)
        sheet(item: item) { source in PlayerView(source: source) }
        #else
        self
        #endif
    }
}
