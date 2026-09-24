import SwiftUI

/// Submenu "Home" in de instellingen: alles wat de startpagina bepaalt.
struct VeyraHomeSettingsView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    VeyraStreamingSettingsView()
                } label: {
                    Label("Streamingdiensten", systemImage: "play.rectangle.on.rectangle")
                }
                NavigationLink {
                    VeyraCollectionsSettingsView()
                } label: {
                    Label("Filmcollecties", systemImage: "film.stack")
                }
                NavigationLink {
                    ShelvesSettingsView()
                } label: {
                    Label("Planken", systemImage: "rectangle.grid.1x2")
                }
            } footer: {
                Text("Streamingdiensten en filmcollecties: volgorde, logo's en banners. Planken: eigen rijen onderaan Home. Alles synct via VeyraHub.")
            }
        }
        .navigationTitle("Home")
    }
}
