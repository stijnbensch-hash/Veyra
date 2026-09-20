import SwiftUI

/// iOS-versie van de ondertitel-weergave-instellingen (grootte, plaatsing,
/// achtergrond, schaduw, tijdcorrectie). Deze waren voorheen enkel op tvOS
/// aan te passen (verstopt in het afspeelscherm); op iOS stonden ze
/// nergens. Nu staat het hier in Instellingen -> Ondertitelweergave, op
/// dezelfde opslag als tvOS en de speler al gebruikten. Zie
/// `SubtitleAppearanceSettings.swift` (Shared) voor de opgeslagen sleutels -
/// bestaande keuzes blijven gelden.
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
        List {
            Section {
                Picker("Tekstgrootte", selection: $subtitleSizeRaw) {
                    ForEach(VeyraSubtitleSize.allCases) { size in
                        Text(size.title).tag(size.rawValue)
                    }
                }
                Picker("Plaatsing", selection: $subtitlePositionRaw) {
                    ForEach(VeyraSubtitlePosition.allCases) { position in
                        Text(position.title).tag(position.rawValue)
                    }
                }
                Picker("Achtergrond", selection: $subtitleBackgroundRaw) {
                    ForEach(VeyraSubtitleBackground.allCases) { background in
                        Text(background.title).tag(background.rawValue)
                    }
                }
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
        .navigationTitle("Ondertitelweergave")
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
