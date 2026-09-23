import SwiftUI

/// tvOS-versie van de ondertitel-weergave-instellingen (grootte, plaatsing,
/// achtergrond, schaduw, tijdcorrectie). Dit zat eerder verstopt in het
/// afspeelscherm zelf ("Weergave"- en "Synchronisatie"-tabs naast de
/// bronkeuze); nu staat het hier in Instellingen, en toont het afspeelscherm
/// alleen nog de keuze van ondertitelbron. Zie
/// `SubtitleAppearanceSettings.swift` (Shared) voor de opgeslagen sleutels —
/// dezelfde die de speler al gebruikte, dus bestaande keuzes blijven gelden.
struct SubtitleAppearanceSettingsView: View {
    @AppStorage(SubtitleAppearanceDefaults.sizeKey)
    private var subtitleSizeRaw = VeyraSubtitleSize.normal.rawValue
    @AppStorage(SubtitleAppearanceDefaults.positionKey)
    private var subtitlePositionRaw = VeyraSubtitlePosition.low.rawValue
    @AppStorage(SubtitleAppearanceDefaults.backgroundKey)
    private var subtitleBackgroundRaw = VeyraSubtitleBackground.subtle.rawValue
    @AppStorage(SubtitleAppearanceDefaults.shadowKey)
    private var subtitleShadow = true
    @AppStorage(SubtitleAppearanceDefaults.offsetKey)
    private var subtitleOffset: Double = 0

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    VeyraSettingsChoiceRow<VeyraSubtitleSize>("Tekstgrootte", selection: $subtitleSizeRaw)
                    VeyraSettingsChoiceRow<VeyraSubtitlePosition>("Plaatsing", selection: $subtitlePositionRaw)
                    VeyraSettingsChoiceRow<VeyraSubtitleBackground>("Achtergrond", selection: $subtitleBackgroundRaw)
                    Toggle("Schaduw", isOn: $subtitleShadow)
                } header: {
                    Text("Weergave")
                } footer: {
                    Text("Geldt voor tekstondertitels die Veyra zelf tekent (inclusief OpenSubtitles). Beeldgebaseerde of native ondertitelsporen kunnen hun eigen positionering hebben.")
                }

                Section {
                    Button("10 sec vroeger") { adjustOffset(by: -10) }
                    Button("0,1 sec vroeger") { adjustOffset(by: -0.1) }
                    Button("0,1 sec later") { adjustOffset(by: 0.1) }
                    Button("10 sec later") { adjustOffset(by: 10) }
                    if subtitleOffset != 0 {
                        Button("Terugzetten naar 0,0s") { subtitleOffset = 0 }
                    }
                } header: {
                    Text("Synchronisatie")
                } footer: {
                    Text(currentOffsetDescription)
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Ondertitels")
    }

    private var currentOffsetDescription: String {
        if subtitleOffset == 0 {
            return "Ondertitels lopen gelijk met het geluid."
        }
        let sign = subtitleOffset > 0 ? "+" : ""
        return "Huidige verschuiving: \(sign)\(String(format: "%.1f", subtitleOffset))s. Schuift het moment waarop tekstondertitels verschijnen; werkt niet voor native ondertitelsporen."
    }

    private func adjustOffset(by delta: Double) {
        let clamped = min(60, max(-60, subtitleOffset + delta))
        subtitleOffset = (clamped * 10).rounded() / 10
    }
}

#Preview {
    NavigationStack { SubtitleAppearanceSettingsView() }
}
