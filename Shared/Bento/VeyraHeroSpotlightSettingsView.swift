// VeyraHeroSpotlightSettingsView.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Submenu "Hero" onder Instellingen → Home: stijl + primaire/secundaire bron
// voor de trending-carrousel bovenaan Home (zie VeyraHeroSpotlightSettings.swift).

import SwiftUI

struct VeyraHeroSpotlightSettingsView: View {
    @State private var settings = HeroSpotlightSettingsStore().load()
    private let store = HeroSpotlightSettingsStore()

    var body: some View {
        content
            .navigationTitle("Hero")
    }

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            List {
                Section {
                    Picker("Stijl", selection: styleBinding) {
                        ForEach(HeroSpotlightStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                    }

                    NavigationLink {
                        VeyraHeroSourcePickerView(title: "Primaire bron", source: primaryBinding)
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "rectangle.stack", title: "Primaire bron") {
                            VeyraSettingsCardRowValue(value: settings.primarySource.defaultTitle)
                        }
                    }
                    .veyraCardRow()

                    NavigationLink {
                        VeyraHeroSourcePickerView(title: "Secundaire bron", allowsNone: true, source: secondaryBinding)
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "rectangle.stack.badge.plus", title: "Secundaire bron") {
                            VeyraSettingsCardRowValue(value: settings.secondarySource?.defaultTitle ?? "Geen")
                        }
                    }
                    .veyraCardRow()
                } footer: {
                    Text(settings.style.helpText)
                }
            }
            .frame(maxWidth: 1000)
        }
        #else
        Form {
            Section {
                Picker("Stijl", selection: styleBinding) {
                    ForEach(HeroSpotlightStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                NavigationLink {
                    VeyraHeroSourcePickerView(title: "Primaire bron", source: primaryBinding)
                } label: {
                    HStack {
                        Text("Primaire bron")
                        Spacer()
                        Text(settings.primarySource.defaultTitle).foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    VeyraHeroSourcePickerView(title: "Secundaire bron", allowsNone: true, source: secondaryBinding)
                } label: {
                    HStack {
                        Text("Secundaire bron")
                        Spacer()
                        Text(settings.secondarySource?.defaultTitle ?? "Geen").foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(settings.style.helpText)
            }
        }
        #endif
    }

    private var styleBinding: Binding<HeroSpotlightStyle> {
        Binding(
            get: { settings.style },
            set: { settings.style = $0; store.save(settings) }
        )
    }

    private var primaryBinding: Binding<ShelfSource?> {
        Binding(
            get: { settings.primarySource },
            set: { newValue in
                settings.primarySource = newValue ?? settings.primarySource
                store.save(settings)
            }
        )
    }

    private var secondaryBinding: Binding<ShelfSource?> {
        Binding(
            get: { settings.secondarySource },
            set: { settings.secondarySource = $0; store.save(settings) }
        )
    }
}
