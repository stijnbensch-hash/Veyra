import SwiftUI

/// "Artwork aanpassen" (artwork-engine-spec §56/§57/§68/§69): per-titel handmatige keuze uit de
/// echte TMDB-candidates voor ClearLogo/Poster/Achtergrond. Candidates worden pas geladen
/// wanneer dit scherm opent (§68), nooit standaard vooraf. Simpeler dan het Collections-
/// equivalent (`VeyraCollectionClearLogoPickerView`): tikken past meteen toe, geen apart
/// "Toepassen" nodig — net als het mockup in §57 ("GEBRUIK AUTOMATISCH" als losse knop per
/// sectie, candidates ernaast).
struct VeyraArtworkPickerView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [ArtworkCandidate] = []
    @State private var loading = true
    @State private var currentOverrides: [VeyraArtworkType: VeyraArtworkOverride] = [:]
    // Op tvOS zet het systeem bij focus standaard een eigen (lichte/witte) "platter"-
    // achtergrond achter een Button met transparante inhoud (bv. een clearlogo-PNG) --
    // hetzelfde terugkerende euvel als elders in de app. Met `.focusEffectDisabled()`
    // uitgezet en hier zelf, via deze FocusState, een eigen cyaan focusrand/-schaal
    // getekend (zie `thumbnail(_:)`).
    @FocusState private var focusedCandidateID: String?
    // §66: als de override voor deze titel elders wijzigt (ander scherm, of een VeyraHub-sync
    // vanaf een ander apparaat, §64) terwijl deze picker al open staat, moet de selectiering
    // meeveranderen -- zonder de candidates (duur, TMDB-netwerk) opnieuw op te halen.
    @ObservedObject private var artworkRefresh = ArtworkRefreshSignal.shared

    private let store = VeyraArtworkOverrideStore()

    private var mediaKind: ShelfMediaKind { item.type == .series ? .series : .movie }

    private var canonicalKey: String? {
        guard let tmdbID = item.tmdbID else { return nil }
        return VeyraArtworkOverrideStore.canonicalKey(tmdbID: tmdbID, kind: mediaKind)
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
            content
                .navigationTitle("Artwork aanpassen")
                .task { await load() }
                .onChange(of: artworkRefresh.generation) { _, _ in refreshOverrides() }
        }
    }

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        ZStack {
            VeyraBackground().ignoresSafeArea()
            form
        }
        #else
        form
        #endif
    }

    private var form: some View {
        VeyraForm {
            if item.tmdbID == nil {
                Section {
                    Text("Geen TMDB-ID bekend voor deze titel — artwork aanpassen is hier niet mogelijk.")
                        .foregroundStyle(.secondary)
                }
            } else if loading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                ForEach(VeyraArtworkType.allCases) { type in
                    section(for: type)
                }
            }
        }
        .frame(maxWidth: 1000)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Sluiten") { dismiss() } }
        }
        #endif
    }

    @ViewBuilder
    private func section(for type: VeyraArtworkType) -> some View {
        let items = candidates.filter { $0.type == type }

        Section {
            Button("Gebruik automatisch") { clear(type) }
                .disabled(currentOverrides[type] == nil)

            if items.isEmpty {
                Text("Geen alternatieven gevonden.").foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { candidate in
                            thumbnail(candidate)
                        }
                    }
                    // Horizontale ruimte voor de focus-gloed/-schaal (`scaleEffect` in
                    // `thumbnail(_:)`) aan weerszijden -- anders snijdt de ScrollView de
                    // linkerrand van de eerste (gefocuste) kaart gewoon af.
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
                // Zonder dit krijgt deze rij op tvOS het standaard (lichte) Form-rijvlak
                // van het systeem erachter -- dat is het "wit" dat je tussen/achter de
                // poster- en achtergrond-thumbnails ziet, los van de afbeeldingen zelf.
                // Zelfde fix als elders in de app (bv. `SourceAppearanceView`).
                .listRowBackground(Color.clear)
            }
        } header: {
            Text(type.title)
        }
    }

    @ViewBuilder
    private func thumbnail(_ candidate: ArtworkCandidate) -> some View {
        let isSelected = currentOverrides[candidate.type]?.providerPath == candidate.providerPath

        // Groter dan voorheen (was 110-220 breed) zodat je de candidates écht kan
        // beoordelen, en per type zijn eigen, kloppende beeldverhouding i.p.v. voor poster
        // en clearlogo dezelfde landschap-doos als achtergrond: poster staand (2:3),
        // clearlogo en achtergrond breed (16:9-achtig).
        let size: CGSize = {
            switch candidate.type {
            case .backdrop: return CGSize(width: 320, height: 180)
            case .poster: return CGSize(width: 150, height: 225)
            case .clearLogo: return CGSize(width: 220, height: 130)
            }
        }()

        let isFocused = focusedCandidateID == candidate.id

        // Geen `Button` hier -- op tvOS blijft die, zelfs met `.buttonStyle(.plain)`, bij
        // focus zijn eigen systeem-"platter" (een lichte/witte achtergrond) achter de
        // inhoud tekenen; `.focusEffectDisabled()` onderdrukt dat niet betrouwbaar voor
        // een `Button`. Zelfde terugkerend euvel als elders in de app -- de bestaande,
        // bewezen oplossing is een gewone `View` met handmatige focus (zie bv.
        // `IPTVVODManagementView.swift`): `.focusable` + `.focused` + `.focusEffectDisabled`
        // + `.onTapGesture`, zonder dat Apple daar zelf nog een achtergrond achter zet.
        VeyraAsyncImage(url: candidate.url) { phase in
            // Geen enkele vulkleur meer achter de thumbnail -- op uitdrukkelijk verzoek
            // puur de afbeelding zelf, ook bij een (deels) transparante clearlogo-PNG.
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: candidate.type == .clearLogo ? .fit : .fill)
                    .padding(candidate.type == .clearLogo ? 14 : 0)
            } else {
                Color.clear
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? VeyraColors.cyan : (isFocused ? VeyraColors.cyan.opacity(0.7) : .clear),
                    lineWidth: 3
                )
        )
        .scaleEffect(isFocused ? 1.06 : 1)
        .animation(.easeOut(duration: 0.2), value: isFocused)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        #if os(tvOS)
        .focusable(true)
        .focused($focusedCandidateID, equals: candidate.id)
        .focusEffectDisabled()
        #endif
        .onTapGesture {
            select(candidate)
        }
        .accessibilityAddTraits(.isButton)
    }

    private func select(_ candidate: ArtworkCandidate) {
        guard let canonicalKey else { return }
        store.setOverride(candidate.override, canonicalKey: canonicalKey)
        currentOverrides[candidate.type] = candidate.override
    }

    private func clear(_ type: VeyraArtworkType) {
        guard let canonicalKey else { return }
        store.clearOverride(canonicalKey: canonicalKey, type: type)
        currentOverrides[type] = nil
    }

    // Enkel aangeroepen bij het openen van dit scherm, niet vooraf (§68).
    private func load() async {
        defer { loading = false }
        refreshOverrides()
        // Geen "witte rand"-filtercontrole meer op de TMDB-candidates: dat loste niets
        // echt op (het witte vlak kwam van de focusweergave van dit scherm zelf, zie
        // `thumbnail(_:)`, hetzelfde terugkerende euvel als bij knoppen elders in de app)
        // en kostte wel tijd -- elke candidate moest eerst gedownload/gedecodeerd worden
        // vóór er iets te zien was. Candidates nu meteen tonen zodra ze binnenkomen.
        candidates = await ArtworkCandidateService.candidates(for: item)
    }

    private func refreshOverrides() {
        guard let canonicalKey else { return }
        for type in VeyraArtworkType.allCases {
            currentOverrides[type] = store.override(canonicalKey: canonicalKey, type: type)
        }
    }
}
