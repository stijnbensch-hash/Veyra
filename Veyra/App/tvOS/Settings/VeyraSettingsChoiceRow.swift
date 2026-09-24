import SwiftUI

/// Gemeenschappelijk protocol voor de kleine keuze-enums die de
/// "Instellingen"-schermen gebruiken (resolutie, taal, ondertitelopmaak,
/// enz.) — allemaal al `String`-backed, `CaseIterable` en `Identifiable`
/// met een `title`. Retroactief toegepast via lege `extension`s zodat
/// bestaande enums ongewijzigd blijven.
protocol VeyraSettingsOption: RawRepresentable, CaseIterable, Identifiable, Hashable
where RawValue == String, ID == String {
    var title: String { get }
}

/// Vervangt een systeem-`Picker` binnenin een tvOS-instellingenlijst — die
/// rendert daar standaard als een horizontale rij keuzeknoppen, wat niet
/// aansluit bij de rest van de "Veyra-stijl" (grote verticale, focusbare
/// rijen). Dit toont in plaats daarvan een gewone rij met de huidige waarde,
/// die doorlinkt naar een verticale lijst met een vinkje bij de actieve
/// keuze — net als de andere keuzeschermen in de app (bv. HeroSourcePickerView).
struct VeyraSettingsChoiceRow<Option: VeyraSettingsOption>: View {
    let icon: String
    let title: String
    let options: [Option]
    @Binding var selectionRaw: String

    init(
        icon: String,
        _ title: String,
        options: [Option] = Array(Option.allCases),
        selection: Binding<String>
    ) {
        self.icon = icon
        self.title = title
        self.options = options
        self._selectionRaw = selection
    }

    private var current: Option? {
        options.first { $0.rawValue == selectionRaw }
    }

    var body: some View {
        NavigationLink {
            VeyraSettingsChoiceListView(title: title, options: options, selectionRaw: $selectionRaw)
        } label: {
            VeyraSettingsCardRowLabel(icon: icon, title: title) {
                VeyraSettingsCardRowValue(value: current?.title)
            }
        }
        .veyraCardRow()
    }
}

private struct VeyraSettingsChoiceListView<Option: VeyraSettingsOption>: View {
    let title: String
    let options: [Option]
    @Binding var selectionRaw: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    ForEach(options) { option in
                        Button {
                            selectionRaw = option.rawValue
                            dismiss()
                        } label: {
                            VeyraSettingsCardRowLabel(
                                icon: option.rawValue == selectionRaw ? "checkmark.circle.fill" : "circle",
                                title: option.title
                            )
                        }
                        .veyraCardRow()
                    }
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle(title)
    }
}

// MARK: - Conformances

extension PlaybackResolutionOption: VeyraSettingsOption {}
extension PlaybackCellularResolutionOption: VeyraSettingsOption {}
extension PlaybackLanguageOption: VeyraSettingsOption {}
extension PlaybackAutoSelectSubtitlesOption: VeyraSettingsOption {}
extension PlaybackAnimeAudioOption: VeyraSettingsOption {}
extension PlaybackCountdownDuration: VeyraSettingsOption {}
extension PlaybackSelectedPlayer: VeyraSettingsOption {}
extension VeyraSubtitleSize: VeyraSettingsOption {}
extension VeyraSubtitlePosition: VeyraSettingsOption {}
extension VeyraSubtitleBackground: VeyraSettingsOption {}
extension PosterEnrichmentMode: VeyraSettingsOption {}
extension PosterRatingSource: VeyraSettingsOption {}
extension MetadataSourceOption: VeyraSettingsOption {}
extension IPTVGuideTheme: VeyraSettingsOption {}
extension IPTVPlayerEngineOption: VeyraSettingsOption {}
extension IPTVBufferDurationOption: VeyraSettingsOption {}
extension IPTVCatchUpOffsetMode: VeyraSettingsOption {}
extension IPTVCacheRefreshInterval: VeyraSettingsOption {}
extension ShelfMediaKind: VeyraSettingsOption {
    var id: String { rawValue }
    var title: String { label }
}
