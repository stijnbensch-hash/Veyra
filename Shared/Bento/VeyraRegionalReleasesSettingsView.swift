// VeyraRegionalReleasesSettingsView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Submenu "Nieuw van hier" onder Instellingen → Home: welke aanvullende bronnen naast VRT mogen
// meetellen (zie RegionalReleaseSettings.swift). De sectie zelf verbergen blijft via de
// bestaande tegel-zichtbaarheid (VeyraBentoLayout / veyraHomeTileMenu(.nieuwVanHier)) -- dit
// scherm regelt enkel wat BINNEN een zichtbare sectie meetelt.
import SwiftUI

struct VeyraRegionalReleasesSettingsView: View {
    @State private var settings = RegionalReleaseSettingsStore().load()
    private let store = RegionalReleaseSettingsStore()

    var body: some View {
        content
            .navigationTitle("Nieuw van hier")
    }

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            List {
                Section {
                    Toggle("IPTV VOD-releases", isOn: showIPTVVODBinding)
                } footer: {
                    Text("VRT MAX blijft altijd meetellen. IPTV VOD-releases komt uit je eigen IPTV/Xtream-account (als dat een passende VRT MAX-/VTM GO-/Streamz-/GoPlay-categorie heeft) en is minder zeker dan VRT's eigen \"Binnenkort\"-lijst, omdat het afgaat op wanneer je provider een aflevering toevoegde in plaats van de officiële premièredatum.")
                }
            }
            .frame(maxWidth: 1000)
        }
        #else
        Form {
            Section {
                Toggle("IPTV VOD-releases", isOn: showIPTVVODBinding)
            } footer: {
                Text("VRT MAX blijft altijd meetellen. IPTV VOD-releases komt uit je eigen IPTV/Xtream-account (als dat een passende VRT MAX-/VTM GO-/Streamz-/GoPlay-categorie heeft) en is minder zeker dan VRT's eigen \"Binnenkort\"-lijst, omdat het afgaat op wanneer je provider een aflevering toevoegde in plaats van de officiële premièredatum.")
            }
        }
        #endif
    }

    private var showIPTVVODBinding: Binding<Bool> {
        Binding(
            get: { settings.showIPTVVODReleases },
            set: { settings.showIPTVVODReleases = $0; store.save(settings) }
        )
    }
}
