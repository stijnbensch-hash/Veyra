// VeyraNowSettingsView.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Instellingen > Home > Veyra Now: welke brontypes meedoen in de tijdslijn-rail, of de
// prioriteit slim meeweegt, en de lijst weggetikte items (zie `VeyraNowSettings.swift`).

import SwiftUI

struct VeyraNowSettingsView: View {
    @State private var settings = VeyraNowSettingsStore.load()

    private var hiddenCount: Int {
        settings.dismissedIDs.count + settings.snoozedUntil.count
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
    #if os(tvOS)
            ZStack {
                VeyraBackground().ignoresSafeArea()

                VeyraList {
                    Section {
                        Toggle("Nieuw uitgebracht tonen", isOn: $settings.showReleases)
                        Toggle("Slimme prioriteit", isOn: $settings.smartPriority)
                    } footer: {
                        Text("Nieuw uitgebracht: de meest recente nieuwe film of serie kan in de rail verschijnen. Slimme prioriteit: een serie met nog maar 1-2 afleveringen te gaan komt hoger te staan dan iets waar je net aan begonnen bent. Geldt voor alle platformen en synct via VeyraHub.")
                    }

                    if hiddenCount > 0 {
                        Section {
                            Button(role: .destructive) {
                                VeyraNowSettingsStore.clearDismissedAndSnoozed()
                                settings = VeyraNowSettingsStore.load()
                            } label: {
                                // Dezelfde donkere kaart + cyaan gloed als de rest van deze schermen i.p.v.
                                // de felwitte systeemkaart die een kale Button op tvOS bij focus krijgt.
                                VeyraSettingsCardRowLabel(icon: "arrow.counterclockwise", title: "Weggetikte items terugzetten",
                                                           subtitle: "\(hiddenCount) item(s) weggetikt met \"Niet interessant\" of \"Vandaag niet tonen\".") {
                                    EmptyView()
                                }
                            }
                            .veyraCardRow()
                        }
                    }
                }
                .frame(maxWidth: 1000)
            }
            .navigationTitle("Veyra Now")
            .onChange(of: settings) { _, new in VeyraNowSettingsStore.save(new) }
    #else
            VeyraForm {
                Section {
                    Toggle("Nieuw uitgebracht tonen", isOn: $settings.showReleases)
                    Toggle("Slimme prioriteit", isOn: $settings.smartPriority)
                } footer: {
                    Text("Nieuw uitgebracht: de meest recente nieuwe film of serie kan in de rail verschijnen. Slimme prioriteit: een serie met nog maar 1-2 afleveringen te gaan komt hoger te staan dan iets waar je net aan begonnen bent. Geldt voor alle platformen en synct via VeyraHub.")
                }

                if hiddenCount > 0 {
                    Section {
                        Button(role: .destructive) {
                            VeyraNowSettingsStore.clearDismissedAndSnoozed()
                            settings = VeyraNowSettingsStore.load()
                        } label: {
                            Label("Weggetikte items terugzetten (\(hiddenCount))", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .navigationTitle("Veyra Now")
            .onChange(of: settings) { _, new in VeyraNowSettingsStore.save(new) }
    #endif

        }
    }
}
