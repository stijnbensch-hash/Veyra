import SwiftUI

/// Submenu "Home" in de instellingen: alles wat de startpagina bepaalt.
struct VeyraHomeSettingsView: View {
    var body: some View {
#if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    NavigationLink {
                        VeyraHomeLayoutSettingsView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "square.grid.2x2", title: "Indeling") {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()

                    NavigationLink {
                        VeyraNowSettingsView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "sparkle", title: "Veyra Now") {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()

                    NavigationLink {
                        VeyraHomeContinueWatchingSettingsView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "clock.arrow.circlepath", title: "Verder kijken & Binnenkort") {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()

                    NavigationLink {
                        VeyraStreamingSettingsView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "play.rectangle.on.rectangle", title: "Streamingdiensten") {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()

                    NavigationLink {
                        VeyraCollectionsSettingsView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "film.stack", title: "Filmcollecties") {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()

                    NavigationLink {
                        ShelvesSettingsView()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "rectangle.grid.1x2", title: "Planken") {
                            VeyraSettingsCardRowValue(value: nil)
                        }
                    }
                    .veyraCardRow()
                } footer: {
                    Text("Indeling: welke blokken Home toont en in welke volgorde. Streamingdiensten en filmcollecties: volgorde, logo's en banners. Planken: eigen rijen onderaan Home. Alles synct via VeyraHub.")
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Home")
#else
        Form {
            Section {
                NavigationLink {
                    VeyraHomeLayoutSettingsView()
                } label: {
                    Label("Indeling", systemImage: "square.grid.2x2")
                }
                NavigationLink {
                    VeyraNowSettingsView()
                } label: {
                    Label("Veyra Now", systemImage: "sparkle")
                }
                NavigationLink {
                    VeyraHeroSpotlightSettingsView()
                } label: {
                    Label("Hero", systemImage: "sparkles")
                }
                NavigationLink {
                    VeyraHomeContinueWatchingSettingsView()
                } label: {
                    Label("Verder kijken & Binnenkort", systemImage: "clock.arrow.circlepath")
                }
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
                Text("Indeling: welke blokken Home toont en in welke volgorde. Hero: de carrousel bovenaan Home. Streamingdiensten en filmcollecties: volgorde, logo's en banners. Planken: eigen rijen onderaan Home. Alles synct via VeyraHub.")
            }
        }
        .navigationTitle("Home")
#endif
    }
}
