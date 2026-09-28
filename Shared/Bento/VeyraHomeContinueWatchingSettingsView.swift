// VeyraHomeContinueWatchingSettingsView.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Submenu onder "Instellingen > Home": "Verder kijken" en "Binnenkort" op het startscherm.
// Verplaatst uit de vroeger iOS-only "Algemeen > Startscherm"-sectie, zodat deze instellingen nu
// ook op tvOS/macOS bestaan (net als de rest van "Home instellingen").

import SwiftUI

struct VeyraHomeContinueWatchingSettingsView: View {
    @AppStorage(GeneralSettingsDefaults.showContinueWatchingKey)
    private var showContinueWatching = true
    @AppStorage(GeneralSettingsDefaults.continueWatchingLimitKey)
    private var continueWatchingLimit = 10
    @AppStorage(GeneralSettingsDefaults.showUpcomingKey)
    private var showUpcoming = true
    @AppStorage(GeneralSettingsDefaults.pulseBadgesKey)
    private var showPulseBadges = true

    var body: some View {
#if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Toggle("Verder kijken tonen", isOn: $showContinueWatching)
                    // `Stepper` bestaat niet op tvOS — hier vervangen door een eigen +/- rij
                    // (zelfde patroon als IPTVPlaybackSettingsView.swift).
                    VeyraSettingsCardRowLabel(icon: "square.grid.3x3", title: "Aantal tegels: \(continueWatchingLimit)") {
                        HStack(spacing: 20) {
                            Button {
                                continueWatchingLimit = max(1, continueWatchingLimit - 1)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            Button {
                                continueWatchingLimit = min(30, continueWatchingLimit + 1)
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                    .disabled(!showContinueWatching)
                    .veyraCardRow()
                    Toggle("Binnenkort tonen", isOn: $showUpcoming)
                    Toggle("Veyra Pulse-badges tonen", isOn: $showPulseBadges)
                } footer: {
                    Text("Verder kijken toont titels die je begonnen bent; Aantal tegels begrenst hoeveel er verschijnen (meest recente behouden). Binnenkort toont de volgende aflevering — en de uitzenddatum — voor series waar je bij bent. \"Veyra Pulse\" toont de meta-informatie (nog te gaan, resterende tijd) als icoon + pil i.p.v. losse tekst — geldt voor alle platformen tegelijk.")
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Verder kijken & Binnenkort")
#else
        Form {
            Section {
                Toggle("Verder kijken tonen", isOn: $showContinueWatching)
                Stepper(
                    "Aantal tegels: \(continueWatchingLimit)",
                    value: $continueWatchingLimit,
                    in: 1...30
                )
                .disabled(!showContinueWatching)
                Toggle("Binnenkort tonen", isOn: $showUpcoming)
                Toggle("Veyra Pulse-badges tonen", isOn: $showPulseBadges)
            } footer: {
                Text("Verder kijken toont titels die je begonnen bent; Aantal tegels begrenst hoeveel er verschijnen (meest recente behouden). Binnenkort toont de volgende aflevering — en de uitzenddatum — voor series waar je bij bent. \"Veyra Pulse\" toont de meta-informatie (nog te gaan, resterende tijd) als icoon + pil i.p.v. losse tekst — geldt voor alle platformen tegelijk.")
            }
        }
        .navigationTitle("Verder kijken & Binnenkort")
#endif
    }
}
